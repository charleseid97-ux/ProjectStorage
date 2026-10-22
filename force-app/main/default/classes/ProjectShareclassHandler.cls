/** ──────────────────────────────────────
 * @description Trigger logic for ProjectShareclass__c: share class names, fields goal per stage, Project Shareclass
 *                  Child creation, step validation (TECH_TeamValidation__c) when TECH_FieldsToModify__c changes,
 *                  blanking of newly selected fields and Tax Transparency sync.
 *              Fields goal and step validation read the PMT matrix (PMTMatrix, FIX-20178); in validateSteps the matrix
 *                  is restricted to the project's Scope (PMTMatrix.forScope), so a field owned by Product Strategy and
 *                  IS goes to the Scope's team.
 *              US-20194: the matrix follows the conditions of the project (and of the share class for the goal).
 *              Previous change: US-19137 (Mira EID, 26-05-26) - updated setNameWithoutProduct.
 * @lastModifiedBy Charles EID   [22-10-26]
 * @testClass Test_ProjectShareclassTrigger
 * @coverage 99%   [22-10-26]
 ────────────────────────────────────── */
public class ProjectShareclassHandler {

    private static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();
    private static final String COUNTRY_ALL = 'ALL';
    private static final String SCENARIO_INTERNAL_TAX_TRANSPARENCY = 'InternalTaxTransparencyNotification';
    private static final List<String> SHARECLASS_CHILD_RECORD_TYPES = new List<String>{ 'DesignAndProposal', 'Engineering', 'Filing', 'SetUp' };
    private static final Set<String> BELGIUM_SELECTIONS = new Set<String>{ 'BE TIS', 'BE Asset Test', 'Belgium Simulator' };

    // Fields goal (NbOfFieldsGoal__c) of each Project Shareclass Child: the required Share Class fields of its stage; on a modification project, only the selected fields (TECH_FieldsToModify__c) of its stage.
    public static void nbOfFieldsGoal(Map<Id, ProjectShareclass__c> newChilds) {
        List<ProjectShareclassChild__c> projectShareclassChildren = [SELECT TECH_Childtype__c, ProjectShareclasses__c, ProjectShareclasses__r.ProjectProduct__c, ProjectShareclasses__r.TECH_FieldsToModify__c, ProjectShareclasses__r.Parent_Record_Type_Id__c
                                                                     FROM ProjectShareclassChild__c
                                                                     WHERE ProjectShareclasses__c IN :newChilds.keySet()];
        Set<Id> projectIds = new Set<Id>();
        for (ProjectShareclassChild__c child : projectShareclassChildren) projectIds.add(child.ProjectShareclasses__r.ProjectProduct__c);
        Map<Id, ProjectProduct__c> projectById = PMTMatrix.loadProjects(projectIds);

        for (ProjectShareclassChild__c child : projectShareclassChildren) {
            // FIX-20178 / US-20194: champs Share Class requis de l'étape, depuis la matrice PMT selon les conditions du projet et de la share class
            PMTMatrix matrix = PMTMatrix.forProject(projectById.get(child.ProjectShareclasses__r.ProjectProduct__c)).forShareClass(child.ProjectShareclasses__c); // US-20194 V1.2: goal with the project's Scope
            String stage = child.TECH_Childtype__c == 'DesignAndProposal' ? 'Proposal' : child.TECH_Childtype__c;
            Set<String> stageFields = new Set<String>(matrix.getRequiredFieldsByStage(false).get(stage) ?? new List<String>());

            if (child.ProjectShareclasses__r.Parent_Record_Type_Id__c == fundModificationRecordTypeId) {
                Set<String> selectedFields = ProjectProductSetupHandlerUtilities.splitMultiPicklist(child.ProjectShareclasses__r.TECH_FieldsToModify__c);
                selectedFields.retainAll(stageFields);
                child.NbOfFieldsGoal__c = selectedFields.size();
            }
            else {
                child.NbOfFieldsGoal__c = stageFields.size();
            }
        }
        if (!projectShareclassChildren.isEmpty()) update projectShareclassChildren;
    }

    // One Project Shareclass Child per stage record type (Design and Proposal share one child)
    public static void createProjectShareclassChild(List<ProjectShareclass__c> newProjectShareclass) {
        List<ProjectShareclassChild__c> shareclassChildren = new List<ProjectShareclassChild__c>();
        for (ProjectShareclass__c parent : newProjectShareclass) {
            for (String recordTypeName : SHARECLASS_CHILD_RECORD_TYPES) {
                shareclassChildren.add(new ProjectShareclassChild__c(
                    RecordTypeId = Schema.SObjectType.ProjectShareclassChild__c.getRecordTypeInfosByDeveloperName().get(recordTypeName).getRecordTypeId(),
                    ProjectShareclasses__c = parent.Id,
                    TECH_Childtype__c = recordTypeName,
                    Name = recordTypeName == 'DesignAndProposal' ? 'Design & Proposal' : recordTypeName,
                    Type__c = parent.Type__c,
                    CurrencyIsoCode = parent.CurrencyIsoCode,
                    DividendPolicy__c = parent.DividendPolicy__c,
                    DividendFrequency__c = parent.DividendFrequency__c,
                    CurrencyHedging__c = parent.CurrencyHedging__c
                ));
            }
        }
        if (!shareclassChildren.isEmpty()) insert shareclassChildren;
    }

    // Phases of the share classes with newly added fields: the teams owning a field to modify at the phase's stage are left to validate (getTeamsAfterModification).
    // FIX-20270: one entry per phase (before: a share class with only removed fields stopped the whole method before the update, and a phase linked to two modified share classes was added twice to the update list - "Duplicate id in list").
    // US-20194: the fields of a phase are the project's fields + the fields of all its share classes, as in ProjectProductSetupHandlerUtilities.validateSteps. Before, only the fields just added on the saved share class counted, so a team that still had a project field to validate (e.g. Legal for LegalForm__c) was marked as validated.
    public static void validateSteps(Map<Id, ProjectShareclass__c> newMap, Map<Id, ProjectShareclass__c> oldMap) {
        Set<Id> modifiedShareClassIds = new Set<Id>();
        for (Id id : newMap.keySet()) {
            if (newMap.get(id).TECH_FieldsToModify__c != oldMap.get(id)?.TECH_FieldsToModify__c) modifiedShareClassIds.add(id);
        }

        if (modifiedShareClassIds.isEmpty()) return;

        Set<Id> phaseIds = new Set<Id>();
        for (ProjectChildJunction__c junction : [SELECT ProjectShareclass__c, ProjectProductChild__c
                                                 FROM ProjectChildJunction__c
                                                 WHERE ProjectShareclass__c IN :modifiedShareClassIds AND ProjectProductChild__r.Name != 'Design']) {
            // Champs ajoutés sur la share class (une share class dont des champs ont seulement été retirés ne change rien)
            Set<String> added = ProjectProductSetupHandlerUtilities.splitMultiPicklist(newMap.get(junction.ProjectShareclass__c)?.TECH_FieldsToModify__c);
            added.removeAll(ProjectProductSetupHandlerUtilities.splitMultiPicklist(oldMap.get(junction.ProjectShareclass__c)?.TECH_FieldsToModify__c));
            if (!added.isEmpty()) phaseIds.add(junction.ProjectProductChild__c);
        }

        if (phaseIds.isEmpty()) return;

        Map<Id, ProjectProductChild__c> phaseById = new Map<Id, ProjectProductChild__c>();
        Map<Id, Set<String>> fieldsByPhaseId = new Map<Id, Set<String>>();
        for (ProjectChildJunction__c junction : [SELECT ProjectProductChild__r.Id, ProjectProductChild__r.TECH_Childtype__c, ProjectProductChild__r.ProjectProductParent__c, ProjectProductChild__r.ProjectProductParent__r.TECH_FieldsToModify__c, ProjectShareclass__r.TECH_FieldsToModify__c
                                                 FROM ProjectChildJunction__c
                                                 WHERE ProjectProductChild__c IN :phaseIds]) {
            ProjectProductChild__c child = junction.ProjectProductChild__r;
            if (!phaseById.containsKey(child.Id)) {
                phaseById.put(child.Id, child);
                fieldsByPhaseId.put(child.Id, ProjectProductSetupHandlerUtilities.splitMultiPicklist(child.ProjectProductParent__r.TECH_FieldsToModify__c));
            }
            fieldsByPhaseId.get(child.Id).addAll(ProjectProductSetupHandlerUtilities.splitMultiPicklist(junction.ProjectShareclass__r.TECH_FieldsToModify__c));
        }

        // US-20194: matrix of each project (Scope and conditions)
        Set<Id> projectIds = new Set<Id>();
        for (ProjectProductChild__c child : phaseById.values()) projectIds.add(child.ProjectProductParent__c);
        Map<Id, ProjectProduct__c> projectById = PMTMatrix.loadProjects(projectIds);

        for (ProjectProductChild__c child : phaseById.values()) {
            child.TECH_TeamValidation__c = ProjectProductSetupHandlerUtilities.getTeamsAfterModification(child, fieldsByPhaseId.get(child.Id), PMTMatrix.forProject(projectById.get(child.ProjectProductParent__c)));
        }
        update phaseById.values();
    }

    // Blanks, on the Project Shareclass Children, the fields newly added to TECH_FieldsToModify__c (checkboxes excepted).
    public static void emptyFields(Map<Id, ProjectShareclass__c> newMap, Map<Id, ProjectShareclass__c> oldMap) {
        Set<Id> changedIds = new Set<Id>();
        for (Id id : newMap.keySet()) {
            if (newMap.get(id).TECH_FieldsToModify__c != oldMap.get(id)?.TECH_FieldsToModify__c) changedIds.add(id);
        }

        if (changedIds.isEmpty()) return;

        Map<String, Schema.SObjectField> fieldMap = ProjectShareclassChild__c.SObjectType.getDescribe().fields.getMap();
        List<ProjectShareclassChild__c> toUpdate = new List<ProjectShareclassChild__c>();
        for (ProjectShareclassChild__c child : [SELECT Id, ProjectShareclasses__c
                                                FROM ProjectShareclassChild__c
                                                WHERE ProjectShareclasses__c IN :changedIds]) {
            String newFieldsStr = newMap.get(child.ProjectShareclasses__c)?.TECH_FieldsToModify__c;
            if (String.isBlank(newFieldsStr)) continue;

            Set<String> oldFields = ProjectProductSetupHandlerUtilities.splitMultiPicklist(oldMap.get(child.ProjectShareclasses__c)?.TECH_FieldsToModify__c);
            for (String field : ProjectProductSetupHandlerUtilities.splitMultiPicklist(newFieldsStr)) {
                if (!oldFields.contains(field) && fieldMap.containsKey(field) && fieldMap.get(field).getDescribe().getType() != Schema.DisplayType.Boolean) child.put(field, null);
            }
            toUpdate.add(child);
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    // TaxTransparency__c selections: an added value creates a Requested TaxData__c (and notifies the Tax team), a removed value cancels the matching PMT TaxData__c.
    public static void syncTaxDataFromTaxTransparency(Map<Id, ProjectShareclass__c> newMap, Map<Id, ProjectShareclass__c> oldMap) {
        if (newMap == null || newMap.isEmpty() || oldMap == null || oldMap.isEmpty()) return;

        Map<Id, Set<String>> addedByScId = new Map<Id, Set<String>>();
        Map<Id, Set<String>> removedByScId = new Map<Id, Set<String>>();
        Set<Id> scIdsToProcess = new Set<Id>();
        for (Id scId : newMap.keySet()) {
            Set<String> newValues = ProjectProductSetupHandlerUtilities.splitMultiPicklist(newMap.get(scId).TaxTransparency__c);
            Set<String> oldValues = ProjectProductSetupHandlerUtilities.splitMultiPicklist(oldMap.get(scId).TaxTransparency__c);

            Set<String> added = new Set<String>(newValues);
            added.removeAll(oldValues);
            Set<String> removed = new Set<String>(oldValues);
            removed.removeAll(newValues);

            if (!added.isEmpty()) {
                addedByScId.put(scId, added);
                scIdsToProcess.add(scId);
            }
            if (!removed.isEmpty()) {
                removedByScId.put(scId, removed);
                scIdsToProcess.add(scId);
            }
        }

        if (scIdsToProcess.isEmpty()) return;

        Map<Id, ProjectShareclass__c> scMap = new Map<Id, ProjectShareclass__c>([SELECT Id, Name, Name__c, ProjectProduct__c, ProjectProduct__r.Name
                                                                                 FROM ProjectShareclass__c
                                                                                 WHERE Id IN :scIdsToProcess]);

        // Create
        List<TaxData__c> toInsert = new List<TaxData__c>();
        for (Id scId : addedByScId.keySet()) {
            ProjectShareclass__c sc = scMap.get(scId);
            if (sc == null || sc.ProjectProduct__c == null) continue;

            for (String label : addedByScId.get(scId)) {
                Map<String, String> countryType = mapSelectionToCountryType(label);
                if (String.isBlank(countryType.get('Country')) || String.isBlank(countryType.get('Type'))) continue;

                toInsert.add(new TaxData__c(
                    Type__c = countryType.get('Type'),
                    Country__c = countryType.get('Country'),
                    Status__c = 'Requested',
                    Source__c = 'PMT',
                    ProjectProduct__c = sc.ProjectProduct__c,
                    ProjectShareclass__c = sc.Id
                ));
            }
        }

        // Cancel: keys of the removed selections
        Set<String> deleteKeys = new Set<String>();
        for (Id scId : removedByScId.keySet()) {
            ProjectShareclass__c sc = scMap.get(scId);
            if (sc == null || sc.ProjectProduct__c == null) continue;

            for (String label : removedByScId.get(scId)) {
                Map<String, String> countryType = mapSelectionToCountryType(label);
                if (String.isBlank(countryType.get('Country')) || String.isBlank(countryType.get('Type'))) continue;

                deleteKeys.add(sc.Id + '|' + sc.ProjectProduct__c + '|' + countryType.get('Country') + '|' + countryType.get('Type'));
            }
        }

        List<TaxData__c> toCancel = new List<TaxData__c>();
        if (!deleteKeys.isEmpty()) {
            for (TaxData__c td : [SELECT Id, ProjectShareclass__c, ProjectProduct__c, Country__c, Type__c
                                  FROM TaxData__c
                                  WHERE ProjectShareclass__c IN :scIdsToProcess AND Source__c = 'PMT']) {
                if (!deleteKeys.contains(td.ProjectShareclass__c + '|' + td.ProjectProduct__c + '|' + td.Country__c + '|' + td.Type__c)) continue;

                td.Status__c = 'Canceled';
                toCancel.add(td);
            }
        }

        if (!toInsert.isEmpty()) insert toInsert;
        if (!toCancel.isEmpty()) update toCancel;

        sendTaxTransparencyNotification(scMap, addedByScId);
    }

    private static void sendTaxTransparencyNotification(Map<Id, ProjectShareclass__c> scMap, Map<Id, Set<String>> addedByScId) {
        if (addedByScId == null || addedByScId.isEmpty()) return;

        TaxEmailConfiguration__mdt config = getEmailConfiguration(COUNTRY_ALL, SCENARIO_INTERNAL_TAX_TRANSPARENCY);
        if (config == null || !config.IsActive__c) return;

        List<String> taxRecipients = splitEmails(config.ToAddresses__c);
        List<String> ccRecipients = splitEmails(config.CcAddresses__c);
        if (taxRecipients.isEmpty()) return;

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Id scId : addedByScId.keySet()) {
            ProjectShareclass__c sc = scMap.get(scId);
            if (sc == null) continue;

            String projectLink = sc.ProjectProduct__c != null ? baseUrl + '/' + sc.ProjectProduct__c : null;
            String body = '<p>Hello Tax Team,</p>'
                        + '<p>New Tax Transparency request(s) have been submitted.</p>'
                        + '<ul>'
                        + '<li><b>Share Class:</b> ' + htmlEscape(sc.Name__c) + '</li>'
                        + '<li><b>Requests:</b> ' + htmlEscape(String.join(new List<String>(addedByScId.get(scId)), ', ')) + '</li>'
                        + (projectLink != null ? '<li><b>Salesforce link (Project):</b> <a href="' + projectLink + '">Open Project</a></li>' : '')
                        + '</ul>'
                        + '<p>Merci,</p>';

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(taxRecipients);
            if (!ccRecipients.isEmpty()) msg.setCcAddresses(ccRecipients);
            msg.setSubject('Tax Transparency request(s) - ' + (sc.ProjectProduct__r != null ? sc.ProjectProduct__r.Name : ''));
            msg.setHtmlBody(body);
            emails.add(msg);
        }
        if (!emails.isEmpty()) Messaging.sendEmail(emails);
    }

    private static TaxEmailConfiguration__mdt getEmailConfiguration(String country, String scenario) {
        List<TaxEmailConfiguration__mdt> configs = [SELECT Country__c, Scenario__c, ToAddresses__c, CcAddresses__c, IsActive__c
                                                    FROM TaxEmailConfiguration__mdt
                                                    WHERE Country__c = :country AND Scenario__c = :scenario LIMIT 1];
        return configs.isEmpty() ? null : configs[0];
    }

    // Email addresses separated by ';' or ','
    private static List<String> splitEmails(String rawEmails) {
        List<String> results = new List<String>();
        if (String.isBlank(rawEmails)) return results;

        for (String email : rawEmails.replace(',', ';').split(';')) {
            if (String.isNotBlank(email)) results.add(email.trim());
        }
        return results;
    }

    private static String htmlEscape(String input) {
        if (input == null) return '';

        return input.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;');
    }

    // { 'Country' => ..., 'Type' => ... } of a Tax Transparency selection: a Belgian selection ('BE TIS', 'BE Asset Test', 'Belgium Simulator') gives Country = 'BE' and Type = the selection, any other gives Country = the selection and Type = 'Transparency'.
    private static Map<String, String> mapSelectionToCountryType(String selection) {
        Map<String, String> result = new Map<String, String>{ 'Country' => null, 'Type' => null };
        if (String.isBlank(selection)) return result;

        String sel = selection.trim();
        if (BELGIUM_SELECTIONS.contains(sel)) {
            result.put('Country', 'BE');
            result.put('Type', sel);
        }
        else {
            result.put('Country', sel);
            result.put('Type', 'Transparency');
        }
        return result;
    }

    // Name__c rebuilt from the share class characteristics, on insert and when one of them changes (US-19137)
    public static void setNameWithoutProduct(List<ProjectShareclass__c> newList, Map<Id, ProjectShareclass__c> oldMap) {
        for (ProjectShareclass__c sc : newList) {
            if (oldMap != null && !hasRelevantFieldChanged(sc, oldMap.get(sc.Id))) continue;

            sc.Name__c = buildName(sc);
        }
    }

    private static Boolean hasRelevantFieldChanged(ProjectShareclass__c newSc, ProjectShareclass__c oldSc) {
        return newSc.LegalForm__c != oldSc.LegalForm__c || newSc.DividendPolicy__c != oldSc.DividendPolicy__c || newSc.Type__c != oldSc.Type__c || newSc.Currency__c != oldSc.Currency__c || newSc.CurrencyHedging__c != oldSc.CurrencyHedging__c || newSc.DividendFrequency__c != oldSc.DividendFrequency__c;
    }

    private static String buildName(ProjectShareclass__c sc) {
        List<String> parts = new List<String>{ sc.Type__c };
        if (sc.Type__c == 'MyInvestor') return String.join(parts, ' ');

        if (String.isNotBlank(sc.Currency__c)) parts.add(sc.Currency__c);

        Boolean hedged = String.valueOf(sc.CurrencyHedging__c) == 'True';
        if (sc.LegalForm__c == 'OEIC') {
            if (sc.DividendPolicy__c == 'Accumulating') {
                parts.add(hedged ? 'Acc Hdg' : 'Acc');
            }
            else if (sc.DividendPolicy__c == 'Income') {
                parts.add(hedged ? 'Inc Hdg' : 'Inc');
            }
            else {
                return null;
            }
            return String.join(parts, ' ');
        }

        if (sc.DividendPolicy__c == 'Accumulating') {
            parts.add('Acc');
        }
        else if (sc.DividendPolicy__c == 'Distributing') {
            parts.add(getDistributionCode(sc.DividendFrequency__c, 'dis'));
        }
        else if (sc.DividendPolicy__c == 'Income') {
            parts.add(getDistributionCode(sc.DividendFrequency__c, 'inc'));
        }
        if (hedged) parts.add('Hdg');

        return String.join(removeBlank(parts), ' ');
    }

    private static String getDistributionCode(String frequency, String suffix) {
        Map<String, String> prefixByFrequency = new Map<String, String>{
            'Monthly' => 'M',
            'Quarterly' => 'Q',
            'Semi-Annually' => 'S',
            'Annually' => 'Y',
            'Weekly' => 'W',
            'Daily' => 'D'
        };
        if (prefixByFrequency.containsKey(frequency)) return prefixByFrequency.get(frequency) + suffix;

        return suffix == 'inc' ? 'inc' : '';
    }

    private static List<String> removeBlank(List<String> values) {
        List<String> result = new List<String>();
        for (String value : values) {
            if (String.isNotBlank(value)) result.add(value);
        }
        return result;
    }
}