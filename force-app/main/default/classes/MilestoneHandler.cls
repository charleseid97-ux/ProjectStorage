public class MilestoneHandler {

    static final Id fundModificationRecordTypeId =
        Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName()
            .get('FundShareClassModification').getRecordTypeId();
    static final Id fundCreationRecordTypeId =
        Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName()
            .get('FundCreation').getRecordTypeId();

    // Constants (Sonar: avoid duplicated literals)
    private static final String MILESTONE_SPC_FINAL   = 'SPC Final';
    private static final String STATUS_COMPLETED      = 'Completed';
    private static final String MILESTONE_LAUNCH_DATE = 'Launch Date';

    public static void linkStepToMilestone(Milestone__c milestone) {
        List<ProjectProductChild__c> steps = [
            SELECT Id, Name, StartDate__c, EndDate__c, ProjectProductParent__c
            FROM ProjectProductChild__c
            WHERE ProjectProductParent__c = :milestone.Project_product__c
        ];
        for (ProjectProductChild__c step : steps) {
            if (step.StartDate__c <= milestone.StartDate__c && step.EndDate__c >= milestone.StartDate__c) {
                milestone.Project_Product_Child__c = step.Id;
            }
        }
    }

    public static void updateProjectLaunchDate(Map<Id, Milestone__c> newMilestone, Map<Id, Milestone__c> oldMilestone) {
        List<Milestone__c> listMilestoneToCheck = new List<Milestone__c>();
        List<ProjectProduct__c> listProjectProductToUpdate = new List<ProjectProduct__c>();
        Set<Id> setProjectProductId = new Set<Id>();

        for (Milestone__c milestone : newMilestone.values()) {
            if (milestone.Name == MILESTONE_LAUNCH_DATE
                && milestone.StartDate__c != oldMilestone.get(milestone.Id).StartDate__c
                && milestone.StartDate__c != null) {

                listMilestoneToCheck.add(milestone);
                setProjectProductId.add(milestone.Project_Product__c);
            }
        }

        if (!setProjectProductId.isEmpty()) {
            Map<Id, ProjectProduct__c> mapProjectProductById = new Map<Id, ProjectProduct__c>(
                [SELECT Id, EndDate__c FROM ProjectProduct__c WHERE Id IN :setProjectProductId]
            );

            // We recheck to avoid multiple trigger call (Because we double synchronise the dates
            // ProjectProduct EndDate and Milestone (GOLIVE) StartDate)
            for (Milestone__c milestone : listMilestoneToCheck) {
                if (mapProjectProductById.containsKey(milestone.Project_product__c)) {
                    if (milestone.StartDate__c != mapProjectProductById.get(milestone.Project_product__c).EndDate__c) {
                        mapProjectProductById.get(milestone.Project_product__c).EndDate__c = milestone.StartDate__c;
                        listProjectProductToUpdate.add(mapProjectProductById.get(milestone.Project_product__c));
                    }
                }
            }

            if (!listProjectProductToUpdate.isEmpty()) {
                update listProjectProductToUpdate;
            }
        }
    }

    public static void updateOwnerOnProjectProduct(Map<Id, Milestone__c> newMilestones, Map<Id, Milestone__c> oldMilestones) {
        Set<Id> setProjectProductId = getProjectProductIdsForSpcFinalCompleted(newMilestones, oldMilestones);
        if (setProjectProductId.isEmpty()) return;

        List<ProductProjectSettings__c> matriceRecords = [
            SELECT Id, TeamOwner__c, Team__c, RequiredFields__c, RequiredFieldsShareClass__c,
                   NonRequiredFieldsFund__c, NonRequiredFieldsShareClass__c
            FROM ProductProjectSettings__c
        ];

        List<ProjectProduct__c> pps = [
            SELECT Id, TECH_FieldsToModify__c,
                   (SELECT Id, TECH_FieldsToModify__c FROM ProjectShareclasses__r)
            FROM ProjectProduct__c
            WHERE Id IN :setProjectProductId
            AND RecordTypeId = :fundModificationRecordTypeId
        ];

        List<ProjectProduct__c> listProjectProductToUpdate = new List<ProjectProduct__c>();

        for (ProjectProduct__c projectProduct : pps) {
            Set<String> fieldsFund = splitFields(projectProduct.TECH_FieldsToModify__c);
            Set<String> fieldsSC   = collectShareClassFields(projectProduct.ProjectShareclasses__r);

            Map<String, Id> teamOwner = buildTeamOwnerMap(fieldsFund, fieldsSC, matriceRecords);

            applyOwners(projectProduct, teamOwner);
            listProjectProductToUpdate.add(projectProduct);
        }

        if (!listProjectProductToUpdate.isEmpty()) {
            update listProjectProductToUpdate;
        }
    }

    public static void validatePhasesESG(Map<Id, Milestone__c> newMilestones, Map<Id, Milestone__c> oldMilestones) {
        Set<Id> projectIds = new Set<Id>();
        for (Milestone__c milestone : newMilestones.values()) {
            if (milestone.Name == MILESTONE_SPC_FINAL
                && milestone.Status__c != oldMilestones.get(milestone.Id).Status__c
                && milestone.Status__c == STATUS_COMPLETED) {

                System.debug('milestone.Project_Product__c: ' + milestone.Project_Product__c);
                projectIds.add(milestone.Project_Product__c);
            }
        }

        List<ProjectProductChild__c> children = [
            SELECT Id, ProjectProductParent__c, TECH_TeamValidation__c
            FROM ProjectProductChild__c
            WHERE ProjectProductParent__c IN :projectIds
            AND ProjectProductParent__r.RecordTypeId = :fundCreationRecordTypeId
            AND ProjectProductParent__r.SFDRcategory__c = '0'
        ];

        for (ProjectProductChild__c child : children) {
            Set<String> currentTeams = new Set<String>();
            if (child.TECH_TeamValidation__c != null) {
                currentTeams.addAll(child.TECH_TeamValidation__c.split(';'));
            }
            currentTeams.add('ESG');
            child.TECH_TeamValidation__c = String.join(new List<String>(currentTeams), ';');
        }
        update children;
    }

    public static void createTaxData(Map<Id, Milestone__c> newMilestones, Map<Id, Milestone__c> oldMilestones) {
        Set<Id> projectIds = new Set<Id>();
        for (Milestone__c milestone : newMilestones.values()) {
            if (milestone.Name == MILESTONE_SPC_FINAL
                && milestone.Status__c != oldMilestones.get(milestone.Id).Status__c
                && milestone.Status__c == STATUS_COMPLETED) {

                System.debug('milestone.Project_Product__c: ' + milestone.Project_Product__c);
                projectIds.add(milestone.Project_Product__c);
            }
        }

        List<ProjectShareclass__c> scs = [
            SELECT Id, UKReportingStatus__c, CHKurliste__c, ITWhitelist__c, ATTransparency__c, BE__c,
                   ProjectProduct__c, ProjectProduct__r.Name, Name
            FROM ProjectShareclass__c
            WHERE ProjectProduct__c IN :projectIds
        ];

        // clé = ProjectId|SCId|Country|Transparency
        Map<String, TaxData__c> desiredByKey = new Map<String, TaxData__c>();
        Map<Id, Set<String>> scIdToCountries = new Map<Id, Set<String>>();

        for (ProjectShareclass__c sc : scs) {

            Id projectId = sc.ProjectProduct__c;
            if (projectId == null) continue;

            Set<String> countries = new Set<String>();
            if (sc.UKReportingStatus__c) countries.add('UK');
            if (sc.CHKurliste__c)       countries.add('CH');
            if (sc.ITWhitelist__c)      countries.add('IT');
            if (sc.ATTransparency__c)   countries.add('AT');
            if (sc.BE__c)               countries.add('BE');

            if (countries.isEmpty()) continue;
            scIdToCountries.put(sc.Id, countries);

            for (String c : countries) {
                String key = projectId + '|' + sc.Id + '|' + c + '|Transparency';
                TaxData__c td = new TaxData__c();
                td.Type__c = 'Transparency';
                td.Country__c = c;
                td.Status__c = 'Requested';
                td.Source__c = 'PMT';
                td.ProjectProduct__c = projectId;
                td.ProjectShareclass__c = sc.Id;
                desiredByKey.put(key, td);
            }
        }
        if (desiredByKey.isEmpty()) return;

        insert desiredByKey.values();

        // Email
        // TODO: remplacer par mailing list / custom metadata
        List<String> taxRecipients = new List<String>{ 'khadija.el-gdaouni.external@carmignac.com' };

        // lien SF : base URL
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();

        // Construire un map SCId -> SC (pour le nom)
        Map<Id, ProjectShareclass__c> scById = new Map<Id, ProjectShareclass__c>(scs);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Id scId : scIdToCountries.keySet()) {
            ProjectShareclass__c sc = scById.get(scId);
            Set<String> countries = scIdToCountries.get(scId);
            Id projectId = sc.ProjectProduct__c;

            String scLink = baseUrl + '/' + scId;
            String projectLink = (projectId != null) ? (baseUrl + '/' + projectId) : null;

            String subject = 'Tax Transparency request – ' + sc.ProjectProduct__r.Name;

            String body = ''
                + '<p>Bonjour,</p>'
                + '<p>Une demande de <b>Tax Transparency</b> a été créée suite à la validation du <b>SPC Final</b>.</p>'
                + '<ul>'
                + '<li><b>Share Class</b> : ' + (sc != null ? sc.Name : '') + '</li>'
                + '<li><b>Pays demandés</b> : ' + String.join(new List<String>(countries), ', ') + '</li>'
                + '</ul>'
                + '<p>'
                + 'Lien Share Class : <a href="' + scLink + '">' + scLink + '</a><br/>'
                + (projectLink != null ? ('Lien Projet : <a href="' + projectLink + '">' + projectLink + '</a>') : '')
                + '</p>'
                + '<p>Merci,</p>';

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(taxRecipients);
            msg.setSubject(subject);
            msg.setHtmlBody(body);

            emails.add(msg);
        }

        if (!emails.isEmpty()) {
            // Messaging.sendEmail(emails);
        }
    }

    // -------------------------
    // Helpers (reduce complexity)
    // -------------------------

    private static Set<Id> getProjectProductIdsForSpcFinalCompleted(Map<Id, Milestone__c> newMilestones, Map<Id, Milestone__c> oldMilestones) {
        Set<Id> ids = new Set<Id>();
        for (Milestone__c m : newMilestones.values()) {
            Milestone__c oldM = oldMilestones.get(m.Id);
            if (m.Name == MILESTONE_SPC_FINAL
                && oldM != null
                && m.Status__c != oldM.Status__c
                && m.Status__c == STATUS_COMPLETED
                && m.Project_Product__c != null) {

                ids.add(m.Project_Product__c);
            }
        }
        return ids;
    }

    private static Set<String> splitFields(String fieldsAsText) {
        Set<String> result = new Set<String>();
        if (String.isBlank(fieldsAsText)) return result;

        for (String f : fieldsAsText.split(';')) {
            if (!String.isBlank(f)) result.add(f.trim());
        }
        return result;
    }

    private static Set<String> collectShareClassFields(List<ProjectShareclass__c> shareclasses) {
        Set<String> result = new Set<String>();
        if (shareclasses == null) return result;

        for (ProjectShareclass__c sc : shareclasses) {
            result.addAll(splitFields(sc.TECH_FieldsToModify__c));
        }
        return result;
    }

    private static Map<String, Id> buildTeamOwnerMap(Set<String> fundFields, Set<String> scFields, List<ProductProjectSettings__c> settings) {
        Map<String, Id> teamOwnerByTeam = new Map<String, Id>();

        for (String field : fundFields) {
            addOwnerForField(teamOwnerByTeam, field, settings, true);
        }
        for (String field : scFields) {
            addOwnerForField(teamOwnerByTeam, field, settings, false);
        }
        return teamOwnerByTeam;
    }

    private static void addOwnerForField(Map<String, Id> teamOwnerByTeam, String field, List<ProductProjectSettings__c> settings, Boolean isFund) {
        for (ProductProjectSettings__c s : settings) {
            Boolean matches =
                isFund
                ? ((s.RequiredFields__c != null && s.RequiredFields__c.contains(field))
                   || (s.NonRequiredFieldsFund__c != null && s.NonRequiredFieldsFund__c.contains(field)))
                : ((s.RequiredFieldsShareClass__c != null && s.RequiredFieldsShareClass__c.contains(field))
                   || (s.NonRequiredFieldsShareClass__c != null && s.NonRequiredFieldsShareClass__c.contains(field)));

            if (matches) {
                if (!teamOwnerByTeam.containsKey(s.Team__c)) {
                    teamOwnerByTeam.put(s.Team__c, s.TeamOwner__c);
                }
                return; // first match wins
            }
        }
    }

    private static void applyOwners(ProjectProduct__c projectProduct, Map<String, Id> teamOwner) {
        // projectProduct.ProductStrategy__c = teamOwner.get('Product Strategy');

        projectProduct.Legal__c          = teamOwner.get('Legal');
        projectProduct.Tax__c            = teamOwner.get('Tax');
        projectProduct.OPS__c            = teamOwner.get('OPS');
        projectProduct.Risk__c           = teamOwner.get('Risk');
        projectProduct.ESG__c            = teamOwner.get('ESG');
        projectProduct.Compliance__c     = teamOwner.get('Compliance');
        projectProduct.DCO__c            = teamOwner.get('DCO');
        projectProduct.DCR__c            = teamOwner.get('DCR');
        projectProduct.InvestmentPerf__c = teamOwner.get('Investment Perf');
        projectProduct.Finance__c        = teamOwner.get('Finance');
        projectProduct.Communication__c  = teamOwner.get('Communication');

        // Fix probable typo from original code (was 'PTechnology')
        projectProduct.Technology__c     = teamOwner.get('Technology');

        projectProduct.DM__c                 = null;
        projectProduct.ProductSpecialists__c = null;
        projectProduct.FundMarketing__c      = null;
        projectProduct.DBS__c                = null;
        projectProduct.RFP__c                = null;
        projectProduct.DCP__c                = null;
    }
}
