public class ProjectProductSetupHandlerUtilities {
    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId(); 
    public static Set<String> getPicklistValuesForStages(String projectType) {
        Set<String> stageValues = new Set<String>();
        List<ProductProjectSettings__c> metadataRecords = [
            SELECT Stage__c
            FROM ProductProjectSettings__c
            WHERE ProjectType__c = :projectType
            ORDER BY Order__c ASC
        ];
        for (ProductProjectSettings__c record : metadataRecords) {
            if (record.Stage__c != null) {
                stageValues.add(record.Stage__c);
            }
        }
        return stageValues;
    }

    public static ProjectProductChild__c createProjectProductChild(String stage, String parentId, Date startDate, Date endDate , List<String> teamswithNofields, Integer nbOfFieldsGoal) {
        System.debug('### [DEBUG] Setting for stage ' + stage);
        List<String> cleanteamswithNofields= new List<String>();
        
        for(String team: teamswithNofields ){
            cleanteamswithNofields.add(team.replaceAll(' ', ''));
        }

        String teamsNofields= String.join( cleanteamswithNofields , ';');
        System.debug('test doha teams with no fields'+teamsNofields );

        String recordTypeId;
        String childType;

        if (stage == 'Design' || stage == 'Proposal') {
            recordTypeId = Schema.SObjectType.ProjectProductChild__c.getRecordTypeInfosByDeveloperName().get('DesignAndProposal').getRecordTypeId();
            childType = 'DesignAndProposal';
        } else {
            recordTypeId = Schema.SObjectType.ProjectProductChild__c.getRecordTypeInfosByDeveloperName().get(stage).getRecordTypeId();
            childType = stage;
        }

        ProjectProductChild__c ppc = new ProjectProductChild__c(
            Name = stage,
            Status__c = 'Not Started',
            ProjectProductParent__c = parentId,
            StartDate__c = startDate,
            EndDate__c = endDate,
            RecordTypeId = recordTypeId,
            TECH_Childtype__c = childType,
            TECH_TeamValidation__c= teamsNofields,
            fundNbOfFields__c = nbOfFieldsGoal
        );
        return ppc;
    }

    public static void getOwnersTeam(ProjectProduct__c projectproduct) {
         List<ProductProjectSettings__c> settings = [
            SELECT TeamOwner__c , Owner__c ,Team__c , OrderTeam__c
            FROM ProductProjectSettings__c
            WHERE ProjectType__c = 'Creation' AND Stage__c = 'Design'
            ORDER BY OrderTeam__c ASC
        ];
        
        if (projectproduct.VehicleType__c == 'Fund') {
            projectproduct.ProductStrategy__c = settings[0].TeamOwner__c;
            projectproduct.IS__c = null;
        } else {
            projectproduct.IS__c = settings[13].TeamOwner__c;
            projectproduct.ProductStrategy__c = null;
        }
        projectproduct.Legal__c=settings[1].TeamOwner__c;
        projectproduct.Tax__c=settings[2].TeamOwner__c;
        projectproduct.OPS__c=settings[3].TeamOwner__c;
        projectproduct.Risk__c=settings[4].TeamOwner__c;
        projectproduct.ESG__c=settings[5].TeamOwner__c;
        projectproduct.Compliance__c=settings[6].TeamOwner__c;
        projectproduct.DCO__c=settings[7].TeamOwner__c;
        projectproduct.DCR__c=settings[8].TeamOwner__c;
        projectproduct.InvestmentPerf__c=settings[9].TeamOwner__c;
        projectproduct.Finance__c=settings[10].TeamOwner__c;
        projectproduct.Communication__c=settings[11].TeamOwner__c;
        projectproduct.Technology__c=settings[12].TeamOwner__c;
    }
    
    public static void validateSteps(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        Set<Id> changedProjectIds = new Set<Id>();
        system.debug('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Start validateSteps');
        for (Id id : newProjectProduct.keySet()) {
            System.debug('validateSteps.TECH_FieldsToModify__c => ' + newProjectProduct.get(id).TECH_FieldsToModify__c);
            System.debug('validateSteps.TECH_FieldsToModify__c => ' + oldProjectProduct.get(id)?.TECH_FieldsToModify__c);

            if (newProjectProduct.get(id).TECH_FieldsToModify__c != oldProjectProduct.get(id)?.TECH_FieldsToModify__c) {
                changedProjectIds.add(id);
            }
        }
        System.debug('changedProjectIds => ' + changedProjectIds);

        if (changedProjectIds.isEmpty()) return;
    
        // Get mappings
        Map<String, String> teamFields = ProjectMatriceUtilities.getAllRequiredAndNonRequiredFieldsByTeamShareClass();
        teamFields.putAll(ProjectMatriceUtilities.getAllRequiredAndNonRequiredFieldsByTeamFund());
        Map<String, String> stageFields = ProjectMatriceUtilities.getAllRequiredAndNonRequiredFieldsByStepShareClass();
        stageFields.putAll(ProjectMatriceUtilities.getAllRequiredAndNonRequiredFieldsByStepFund());
    
        // Set<String> allTeams = new Set<String>(teamFields.values()); // complete list of teams
    
        Map<Id, ProjectProductChild__c> updates = new Map<Id, ProjectProductChild__c>();
        Set<String> fieldsToModify = new Set<String>();

        for (ProjectChildJunction__c junction : [
            SELECT ProjectProductChild__r.Id,
                    ProjectProductChild__r.VehicleType__c,
                   ProjectProductChild__r.ProjectProductParent__c,
                   ProjectProductChild__r.TECH_TeamValidation__c,
                   ProjectProductChild__r.TECH_Childtype__c,
                   ProjectProductChild__r.Name,
                   ProjectShareclass__r.TECH_FieldsToModify__c,
                   ProjectProductChild__r.ProjectProductParent__r.TECH_FieldsToModify__c
            FROM ProjectChildJunction__c
            WHERE ProjectProductChild__r.ProjectProductParent__c IN :changedProjectIds
              AND ProjectProductChild__r.Name != 'Design'
        ]) {
            ProjectProductChild__c child = junction.ProjectProductChild__r;
            child.TECH_TeamValidation__c = 'ProductStrategy;Risk;Legal;Tax;OPS;ESG;Compliance;DCO;DCR;InvestmentPerf;Finance;Communication;Technology;IS';
            List<String> allTeams = new List<String>(child.TECH_TeamValidation__c.split(';'));
            Id parentId = child.ProjectProductParent__c;
    
            if (String.isNotBlank(junction.ProjectShareclass__r.TECH_FieldsToModify__c)) {
                //fieldsToModify.addAll(junction.ProjectShareclass__r.TECH_FieldsToModify__c.split(';'));
            }
            String newVal = newProjectProduct.get(parentId)?.TECH_FieldsToModify__c;
            String oldVal = oldProjectProduct.get(parentId)?.TECH_FieldsToModify__c;
    
            Set<String> newSet = splitToSet(newVal);
            Set<String> oldSet = splitToSet(oldVal);

            // Champs ajoutés
            Set<String> added = new Set<String>(newSet);
            added.removeAll(oldSet);
            if (added.isEmpty()) return;
            if (String.isNotBlank(newProjectProduct.get(parentId)?.TECH_FieldsToModify__c)) {
                fieldsToModify.addAll(added);
            }
            Set<String> remainingTeams = new Set<String>(allTeams);
            System.debug('fieldsToModify=>' + fieldsToModify);

            Set<String> coveredTeams = new Set<String>();
            for (String field : fieldsToModify) {
                String stage = stageFields.get(field);
                System.debug('stage=>' + stage);

                if (stage == 'Design' || stage == 'Proposal') stage = 'DesignAndProposal';
                if (child.TECH_Childtype__c == stage) {
                    String team = teamFields.get(field);
                    if (team != null) {
                        //remainingTeams.remove(team.replaceAll(' ', ''));
                        
                        System.debug('field=>' + field + ' team=>' + team );
                        if(junction.ProjectProductChild__r.VehicleType__c == 'Funds' && team.trim().equalsIgnoreCase('IS')){
                            remainingTeams.remove('ProductStrategy');
                        }else{
                            remainingTeams.remove(team.replaceAll(' ', ''));
                        }
                        
                    }
                }
            }

            child.TECH_TeamValidation__c = String.join(remainingTeams, ';');
    
            System.debug('team=>' + child.TECH_Childtype__c+ ' child.TECH_TeamValidation__c => ' + child.TECH_TeamValidation__c);

            updates.put(child.Id, child);
        }
        if (!updates.isEmpty()) {
            update updates.values();
        }
        system.debug('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> END validateSteps');
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

    public static void emptyFields(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        Set<Id> changedProjectIds = new Set<Id>();
        for (ProjectProduct__c proj : newProjectProduct.values()) {
            if (proj.TECH_FieldsToModify__c != oldProjectProduct.get(proj.Id)?.TECH_FieldsToModify__c) {
                changedProjectIds.add(proj.Id);
            }
        }
    
        if (changedProjectIds.isEmpty()) return;
    
        Map<String, Schema.SObjectField> fieldMap = ProjectProductChild__c.SObjectType.getDescribe().fields.getMap();
        List<ProjectProductChild__c> toUpdate = new List<ProjectProductChild__c>();
    
        for (ProjectProductChild__c child : [
            SELECT Id, ProjectProductParent__c
            FROM ProjectProductChild__c
            WHERE ProjectProductParent__c IN :changedProjectIds
        ]) {
            Id parentId = child.ProjectProductParent__c;
            String newFieldsStr = newProjectProduct.get(parentId)?.TECH_FieldsToModify__c;
            String oldFieldsStr = oldProjectProduct.get(parentId)?.TECH_FieldsToModify__c;
    
            if (String.isBlank(newFieldsStr)) continue;
    
            Set<String> newFields = new Set<String>(newFieldsStr.split(';'));
            Set<String> oldFields = oldFieldsStr != null ? new Set<String>(oldFieldsStr.split(';')) : new Set<String>();
            System.debug('### [DEBUG] emptyFields - newFields: ' + newFields);
            System.debug('### [DEBUG] emptyFields - oldFields: ' + oldFields);

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
        System.debug('### [DEBUG] emptyFields - toUpdate size: ' + toUpdate.size());
        System.debug('### [DEBUG] emptyFields - toUpdate : ' + toUpdate);
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public static Integer countFilledFields(SObject record, List<String> fieldApiNames) {
        Integer filledCount = 0;
        Set<String> fields = new Set<String>();
        fields.addAll(fieldApiNames);
        for (String fieldName : fields) {

            // if (record.get(fieldName) != null) {
                Object value = record.get(fieldName);
                // Vérifie si le champ est non null et, s'il s'agit d'une string, non vide
                if (value != null && (!(value instanceof String) || String.valueOf(value).trim() != '')) {
                    System.debug('### [DEBUG] countFilledFields - fieldName: ' + fieldName);

                    filledCount++;
                }
            // }
        }
        
        System.debug('### [DEBUG] countFilledFields - filledCount: ' + filledCount);
        return filledCount;
    }

    public static void updateMilestoneGolive(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        List<Milestone__c> lMilestone = [SELECT Id, StartDate__c, Project_product__c
                                        FROM Milestone__c
                                        WHERE Project_product__c IN :newProjectProduct.keySet()
                                        AND Name = 'Launch Date'];

        if (lMilestone.isEmpty() || lMilestone == null) {
            return;
        }
    
        Map<Id, Milestone__c> mapMilestoneByProject = new Map<Id, Milestone__c>();
        for (Milestone__c milestone : lMilestone) {
            mapMilestoneByProject.put(milestone.Project_product__c, milestone);
        }
    
        List<Milestone__c> milestonesToUpdate = new List<Milestone__c>();

        for (ProjectProduct__c projectProduct : newProjectProduct.values()) {
            if (projectProduct.EndDate__c != oldProjectProduct.get(projectProduct.Id).EndDate__c) {
                Milestone__c relatedMilestone = mapMilestoneByProject.get(projectProduct.Id);
                if (relatedMilestone.StartDate__c != projectProduct.EndDate__c) {
                    relatedMilestone.StartDate__c = projectProduct.EndDate__c;
                    milestonesToUpdate.add(relatedMilestone); 
                }
            }
        }

        if (!milestonesToUpdate.isEmpty()) {
            update milestonesToUpdate;
        }
    }

    public static Map<Id, User> getLegalOwnerUsers(List<ProjectProduct__c> listProjectProductChild) {
        Map<Id, User> mapUserByUserId = new Map<Id, User>();
        Set<Id> setUserId = new Set<Id>();

        for (ProjectProduct__c projectProductChild : listProjectProductChild) {
            if (projectProductChild.Legal__c != null) {
                 setUserId.add(projectProductChild.Legal__c);
            }
        }

        if (!setUserId.isEmpty()) {
            for (User oUser : [SELECT Id, Name FROM User WHERE Id IN :setUserId]) {
                mapUserByUserId.put(oUser.Id, oUser);
            }
            if (!mapUserByUserId.isEmpty()) {
                return mapUserByUserId;
            }
        }
        else {
            System.debug('[DEBUG] getLegalOwnerUsers : setUser is empty');
        }
        return null;
    }

    public static User getUser(String name) {
        List<User> listUsers = [SELECT Id, Name FROM User WHERE Name = :name LIMIT 1];
        if (!listUsers.isEmpty()) {
            return listUsers[0];
        }
        System.debug('[DEBUG] getUser : No user found for name :' + name);
        return null;
     
    }
}