public class ProjectShareclassHandler {
    
    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();  
    private static final String COUNTRY_ALL = 'ALL';
    private static final String SCENARIO_INTERNAL_TAX_TRANSPARENCY = 'InternalTaxTransparencyNotification';

    public static void nbOfFieldsGoal(Map<id, ProjectShareclass__c> newChilds) {
        System.debug('ProjectShareclassHandler.nbOfFieldsGoal - newChilds: ' + newChilds);
        Map<String, Set<String>> fieldListByStage = new Map<String, Set<String>>();
        for (ProductProjectSettings__c setting : [SELECT Stage__c, Team__c, RequiredFieldsShareClass__c 
                                                    FROM ProductProjectSettings__c 
                                                    WHERE ProjectType__c = 'Creation' ]) {
            
            if (setting.RequiredFieldsShareClass__c != null) {
                if (!fieldListByStage.containsKey(setting.Stage__c)) {
                    fieldListByStage.put(setting.Stage__c, new Set<String>());
                }
                
                fieldListByStage.get(setting.Stage__c).addAll(setting.RequiredFieldsShareClass__c.split(';'));                
            }
        }

        Decimal nbOfFields = 0;

        List<ProjectShareclassChild__c> projectShareclassChildren = new List<ProjectShareclassChild__c>() ;

        for (ProjectShareclassChild__c proj : [SELECT ProjectShareclasses__r.TECH_FieldsToModify__c,Tech_Childtype__c,
                                                      ProjectShareclasses__r.Parent_Record_Type_Id__c 
                                                FROM ProjectShareclassChild__c 
                                                WHERE ProjectShareclasses__c in : newChilds.keySet() ]) {
            
            Set<String> fieldListFundModif = new Set<String>();
            String tmp = proj.TECH_Childtype__c;

            if(proj.TECH_Childtype__c == 'DesignAndProposal'){
                tmp = 'Proposal';
            }
            System.debug('ProjectShareclassHandler.nbOfFieldsGoal - proj.TECH_Childtype__c: ' + tmp);
            System.debug('ProjectShareclassHandler.nbOfFieldsGoal - fieldListByStage.get(proj.TECH_Childtype__c): ' + fieldListByStage.get(tmp));
            System.debug('ProjectShareclassHandler.nbOfFieldsGoal - fieldListByStage.get(proj.TECH_Childtype__c): ' + fieldListByStage.get(tmp)?.size() );

            proj.NbOfFieldsGoal__c = fieldListByStage.get(tmp) != null ? 
            fieldListByStage.get(tmp).size() : 0;
            nbOfFields = proj.NbOfFieldsGoal__c;
            if(proj.ProjectShareclasses__r.Parent_Record_Type_Id__c == fundModificationRecordTypeId){
                nbOfFields = 0;
                if(proj.ProjectShareclasses__r.TECH_FieldsToModify__c != null){    
                    for(String str : proj.ProjectShareclasses__r.TECH_FieldsToModify__c?.split(';')){
                        
                        if(fieldListByStage.get(tmp) != null && 
                           fieldListByStage.get(tmp).contains(str)){
                            fieldListFundModif.add(str);
                        }
                    }
                    nbOfFields = fieldListFundModif.size();
                }
            }
            System.debug('ProjectShareclassHandler.nbOfFieldsGoal - NbOfFieldsGoal__c : ' + nbOfFields);

            proj.NbOfFieldsGoal__c = nbOfFields;
            projectShareclassChildren.add(proj);

        }
        System.debug('ProjectShareclassHandler.nbOfFieldsGoal - projectShareclassChildren: ' + projectShareclassChildren);
        update projectShareclassChildren;
    }

    public static void createProjectShareclassChild(List<ProjectShareclass__c> newProjectShareclass){
        List<ProjectShareclassChild__c> shareclassChildren = new List<ProjectShareclassChild__c>();
        Map<String, String> recordTypes = new Map<String, String>{
            'DesignAndProposal' => 'DesignAndProposal',
            'Engineering' => 'Engineering',
            'Filing' => 'Filing',
            'SetUp' => 'SetUp'
        };
        for (ProjectShareclass__c parent : newProjectShareclass) {
            for (String recordTypeName : recordTypes.keySet()) {
                Id recordTypeId = Schema.SObjectType.ProjectShareclassChild__c.getRecordTypeInfosByDeveloperName().get(recordTypeName).getRecordTypeId();
    
                String shareclassChildName = '';
                if (recordTypeName == 'DesignAndProposal') {
                    shareclassChildName = 'Design & Proposal';
                } else {
                    shareclassChildName = recordTypeName;
                }
    
                shareclassChildren.add(new ProjectShareclassChild__c(
                    RecordTypeId = recordTypeId,
                    ProjectShareclasses__c = parent.Id,
                    TECH_Childtype__c = recordTypeName,
                    Name = shareclassChildName,
                    Type__c = parent.Type__c,
                    CurrencyIsoCode = parent.CurrencyIsoCode,
                    DividendPolicy__c = parent.DividendPolicy__c,
                    CurrencyHedging__c = parent.CurrencyHedging__c
                ));
            }
        }
        
        if (!shareclassChildren.isEmpty()) {
            insert shareclassChildren;
        }
    }

    public static void validateSteps(Map<Id, ProjectShareclass__c> newMap, Map<Id, ProjectShareclass__c> oldMap) {

        Set<Id> modifiedShareClassIds = new Set<Id>();
        for (Id id : newMap.keySet()) {
            if (newMap.get(id).TECH_FieldsToModify__c != oldMap.get(id)?.TECH_FieldsToModify__c) {
                modifiedShareClassIds.add(id);
            }
        }
    
        if (modifiedShareClassIds.isEmpty()) return;
    
        // Load all field mappings
        Map<String, String> stageFields = ProjectMatriceUtilities.getAllRequiredAndNonRequiredFieldsByStepShareClass();
        stageFields.putAll(ProjectMatriceUtilities.getAllRequiredAndNonRequiredFieldsByStepFund());
    
        Map<String, String> teamFields = ProjectMatriceUtilities.getAllRequiredAndNonRequiredFieldsByTeamShareClass();
        teamFields.putAll(ProjectMatriceUtilities.getAllRequiredAndNonRequiredFieldsByTeamFund());
    
    
        List<ProjectProductChild__c> toUpdate = new List<ProjectProductChild__c>();
    
        for (ProjectChildJunction__c junction : [
            SELECT ProjectShareclass__c,
                   ProjectShareclass__r.TECH_FieldsToModify__c,
                   ProjectProductChild__r.Id,
                   ProjectProductChild__r.ProjectProductParent__r.TECH_FieldsToModify__c,
                   ProjectProductChild__r.TECH_TeamValidation__c,
                   ProjectProductChild__r.TECH_Childtype__c,
                   ProjectProductChild__r.VehicleType__c,
                   ProjectProductChild__r.Name
            FROM ProjectChildJunction__c
            WHERE ProjectShareclass__c IN :modifiedShareClassIds
              AND ProjectProductChild__r.Name != 'Design'
        ]) {
            ProjectProductChild__c child = junction.ProjectProductChild__r;
            child.TECH_TeamValidation__c = 'ProductStrategy;Risk;Legal;Tax;OPS;ESG;Compliance;DCO;DCR;InvestmentPerf;Finance;Communication;Technology;IS';
            List<String> allTeams = new List<String>(child.TECH_TeamValidation__c.split(';'));

            Set<String> fields = new Set<String>();
            //String shareClassFields = newMap.get(junction.ProjectShareclass__c)?.TECH_FieldsToModify__c;
            //String fundFields = junction.ProjectProductChild__r.ProjectProductParent__r?.TECH_FieldsToModify__c;
    
            String newVal = newMap.get(junction.ProjectShareclass__c)?.TECH_FieldsToModify__c;
            String oldVal = oldMap.get(junction.ProjectShareclass__c)?.TECH_FieldsToModify__c;
    
            Set<String> newSet = splitToSet(newVal);
            Set<String> oldSet = splitToSet(oldVal);

            // Champs ajoutés
            Set<String> added = new Set<String>(newSet);
            added.removeAll(oldSet);
            if (added.isEmpty()) return;

            fields.addAll(added);
            //if (String.isNotBlank(fundFields)) fields.addAll(fundFields.split(';'));
    
            Set<String> remainingTeams = new Set<String>(allTeams);
    
            for (String field : fields) {
                String stage = stageFields.get(field);
                if (stage == 'Design' || stage == 'Proposal') stage = 'DesignAndProposal';
    
                if (child.TECH_Childtype__c == stage) {
                    String team = teamFields.get(field);
                    if (team != null) {
                        remainingTeams.remove(team.replaceAll(' ', ''));
                        if(junction.ProjectProductChild__r.VehicleType__c == 'Funds' && team.trim().equalsIgnoreCase('IS')){
                            remainingTeams.remove('ProductStrategy');
                        }else{
                            remainingTeams.remove(team.replaceAll(' ', ''));
                        }
                    }
                }
            }
    
            child.TECH_TeamValidation__c = String.join(remainingTeams, ';');
            toUpdate.add(child);
        }
    
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    private static Set<String> splitToSet(String s) {
        Set<String> out = new Set<String>();
        if (String.isBlank(s)) return out;

        for (String token : s.split(';')) {
            token = token != null ? token.trim() : null;
            if (String.isNotBlank(token)) out.add(token);
        }
        return out;
    }

    public static void emptyFields(Map<Id, ProjectShareclass__c> newMap, Map<Id, ProjectShareclass__c> oldMap) {
        Set<Id> changedIds = new Set<Id>();
        for (Id id : newMap.keySet()) {
            if (newMap.get(id).TECH_FieldsToModify__c != oldMap.get(id)?.TECH_FieldsToModify__c) {
                changedIds.add(id);
            }
        }
    
        if (changedIds.isEmpty()) return;
    
        Map<String, Schema.SObjectField> fieldMap = ProjectShareclassChild__c.SObjectType.getDescribe().fields.getMap();
        List<ProjectShareclassChild__c> toUpdate = new List<ProjectShareclassChild__c>();
    
        for (ProjectShareclassChild__c child : [
            SELECT Id, ProjectShareclasses__c
            FROM ProjectShareclassChild__c
            WHERE ProjectShareclasses__c IN :changedIds
        ]) {
            Id parentId = child.ProjectShareclasses__c;
            String newFieldsStr = newMap.get(parentId)?.TECH_FieldsToModify__c;
            String oldFieldsStr = oldMap.get(parentId)?.TECH_FieldsToModify__c;
    
            if (String.isBlank(newFieldsStr)) continue;
    
            Set<String> newFields = new Set<String>(newFieldsStr.split(';'));
            Set<String> oldFields = oldFieldsStr != null ? new Set<String>(oldFieldsStr.split(';')) : new Set<String>();
    
            for (String field : newFields) {
                if (!oldFields.contains(field) && fieldMap.containsKey(field)) {
                    Schema.DisplayType type = fieldMap.get(field).getDescribe().getType();
                    if (type != Schema.DisplayType.Boolean) {
                        child.put(field, null);
                    }
                }
            }
    
            toUpdate.add(child);
        }
    
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

    }

    public static void syncTaxDataFromTaxTransparency(Map<Id, ProjectShareclass__c> newMap, Map<Id, ProjectShareclass__c> oldMap) {
        if (newMap == null || newMap.isEmpty() || oldMap == null || oldMap.isEmpty()) {
            return;
        }

        Map<Id, Set<String>> addedByScId = new Map<Id, Set<String>>();
        Map<Id, Set<String>> removedByScId = new Map<Id, Set<String>>();
        Set<Id> scIdsToProcess = new Set<Id>();

        for (Id scId : newMap.keySet()) {
            ProjectShareclass__c newSc = newMap.get(scId);
            ProjectShareclass__c oldSc = oldMap.get(scId);

            Set<String> newValues = new Set<String>(splitMultiPicklist(newSc.TaxTransparency__c));
            Set<String> oldValues = new Set<String>(splitMultiPicklist(oldSc.TaxTransparency__c));

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

        if (scIdsToProcess.isEmpty()) {
            return;
        }

        Map<Id, ProjectShareclass__c> scMap = new Map<Id, ProjectShareclass__c>([
            SELECT Id,
                Name,
            Name__c,
                ProjectProduct__c,
                ProjectProduct__r.Name
            FROM ProjectShareclass__c
            WHERE Id IN :scIdsToProcess
        ]);

        List<TaxData__c> toInsert = new List<TaxData__c>();
        Set<String> deleteKeys = new Set<String>();

        // CREATE
        for (Id scId : addedByScId.keySet()) {
            ProjectShareclass__c sc = scMap.get(scId);
            if (sc == null || sc.ProjectProduct__c == null) {
                continue;
            }

            for (String label : addedByScId.get(scId)) {
                Map<String, String> ct = mapSelectionToCountryType(label);
                String country = ct.get('Country');
                String typeVal = ct.get('Type');

                if (isBlank(country) || isBlank(typeVal)) {
                    continue;
                }

                TaxData__c td = new TaxData__c();
                td.Type__c = typeVal;
                td.Country__c = country;
                td.Status__c = 'Requested';
                td.Source__c = 'PMT';
                td.ProjectProduct__c = sc.ProjectProduct__c;
                td.ProjectShareclass__c = sc.Id;

                toInsert.add(td);
            }
        }

        // DELETE keys
        for (Id scId : removedByScId.keySet()) {
            ProjectShareclass__c sc = scMap.get(scId);
            if (sc == null || sc.ProjectProduct__c == null) {
                continue;
            }

            for (String label : removedByScId.get(scId)) {
                Map<String, String> ct = mapSelectionToCountryType(label);
                String country = ct.get('Country');
                String typeVal = ct.get('Type');

                if (isBlank(country) || isBlank(typeVal)) {
                    continue;
                }

                String key = sc.Id + '|' + sc.ProjectProduct__c + '|' + country + '|' + typeVal;
                deleteKeys.add(key);
            }
        }

        List<TaxData__c> toCancel = new List<TaxData__c>();
        if (!deleteKeys.isEmpty()) {
            for (TaxData__c td : [
                SELECT Id, ProjectShareclass__c, ProjectProduct__c, Country__c, Type__c
                FROM TaxData__c
                WHERE ProjectShareclass__c IN :scIdsToProcess
                AND Source__c = 'PMT'
            ]) {
                String key = td.ProjectShareclass__c + '|' + td.ProjectProduct__c + '|' + td.Country__c + '|' + td.Type__c;
                if (deleteKeys.contains(key)) {
                    td.Status__c = 'Canceled';
                    toCancel.add(td);
                }
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        if (!toCancel.isEmpty()) {
            update toCancel;
        }

        sendTaxTransparencyNotification(scMap, addedByScId);
    }

    private static void sendTaxTransparencyNotification(Map<Id, ProjectShareclass__c> scMap, Map<Id, Set<String>> addedByScId) {
        if (addedByScId == null || addedByScId.isEmpty()) {
            return;
        }

        TaxEmailConfiguration__mdt config = getEmailConfiguration(
            COUNTRY_ALL,
            SCENARIO_INTERNAL_TAX_TRANSPARENCY
        );

        if (config == null || !config.IsActive__c) {
            return;
        }

        List<String> taxRecipients = splitEmails(config.ToAddresses__c);
        List<String> ccRecipients = splitEmails(config.CcAddresses__c);

        if (taxRecipients.isEmpty()) {
            return;
        }

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Id scId : addedByScId.keySet()) {
            ProjectShareclass__c sc = scMap.get(scId);
            if (sc == null) {
                continue;
            }

            Set<String> labels = addedByScId.get(scId);
            String scLink = baseUrl + '/' + scId;
            String projectLink = sc.ProjectProduct__c != null ? baseUrl + '/' + sc.ProjectProduct__c : null;

            String subject = 'Tax Transparency request(s) - ' +
                (sc.ProjectProduct__r != null ? sc.ProjectProduct__r.Name : '');

            String body = ''
                + '<p>Hello Tax Team,</p>'
                + '<p>New Tax Transparency request(s) have been submitted.</p>'
                + '<ul>'
                + '<li><b>Share Class:</b> ' + htmlEscape(sc.Name__c) + '</li>'
                + '<li><b>Requests:</b> ' + htmlEscape(String.join(new List<String>(labels), ', ')) + '</li>'
                
                + (projectLink != null
                    ? '<li><b>Salesforce link (Project):</b> <a href="' + projectLink + '">Open Project</a></li>'
                    : '')
                + '</ul>'
                + '<p>Merci,</p>';

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(taxRecipients);

            if (!ccRecipients.isEmpty()) {
                msg.setCcAddresses(ccRecipients);
            }

            msg.setSubject(subject);
            msg.setHtmlBody(body);
            emails.add(msg);
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

    private static TaxEmailConfiguration__mdt getEmailConfiguration(String country, String scenario) {
        List<TaxEmailConfiguration__mdt> configs = [
            SELECT Country__c,
                Scenario__c,
                ToAddresses__c,
                CcAddresses__c,
                IsActive__c
            FROM TaxEmailConfiguration__mdt
            WHERE Country__c = :country
            AND Scenario__c = :scenario
            LIMIT 1
        ];

        return configs.isEmpty() ? null : configs[0];
    }

    private static List<String> splitEmails(String rawEmails) {
        List<String> results = new List<String>();

        if (String.isBlank(rawEmails)) {
            return results;
        }

        String normalized = rawEmails.replace(',', ';');
        for (String email : normalized.split(';')) {
            String trimmedEmail = email != null ? email.trim() : null;
            if (!String.isBlank(trimmedEmail)) {
                results.add(trimmedEmail);
            }
        }

        return results;
    }

    private static String htmlEscape(String input) {
        if (input == null) {
            return '';
        }

        String result = input;
        result = result.replace('&', '&amp;');
        result = result.replace('<', '&lt;');
        result = result.replace('>', '&gt;');
        result = result.replace('"', '&quot;');

        return result;
    }

    // ------------------------
    // Helpers
    // ------------------------
    private static Boolean isBlank(String s) {
        return s == null || s.trim() == '';
    }

    // split multi-select picklist values (separator ';' in Salesforce)
    private static List<String> splitMultiPicklist(String value) {
        if (isBlank(value)) return new List<String>();
        List<String> parts = value.split(';');
        List<String> out = new List<String>();
        for (String p : parts) {
            if (!isBlank(p)) out.add(p.trim());
        }
        return out;
    }

     /**
     * Retourne un map { 'Country' => ..., 'Type' => ... } pour une sélection donnée.
     * - Si sélection BE (ex: 'BE TIS', 'BE Asset Test', 'Belgium Simulator') =>
     *     Country = 'BE', Type = le type correspondant (ex 'TIS', 'BE Asset Test', 'Belgium Simulator')
     * - Sinon => Country = sélection, Type = 'Transparency'
     */
    private static Map<String, String> mapSelectionToCountryType(String selection) {
        Map<String, String> result = new Map<String, String>{ 'Country' => null, 'Type' => null };
        if (isBlank(selection)) return result;
        String sel = selection.trim();

        // mapping exact (adapter si besoin)
        Map<String, String> beSelectionToType = new Map<String, String>{
            'BE TIS'            => 'BE TIS',
            'BE Asset Test'     => 'BE Asset Test',
            'Belgium Simulator' => 'Belgium Simulator'
        };

        if (beSelectionToType.containsKey(sel)) {
            result.put('Country', 'BE');
            result.put('Type', beSelectionToType.get(sel));
            return result;
        }

        // cas standard -> Country = valeur sélectionnée, Type = Transparency
        result.put('Country', sel);
        result.put('Type', 'Transparency');
        return result;
    }
}