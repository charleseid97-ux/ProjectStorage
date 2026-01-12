public class ProjectShareclassHandler {
    
    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();  
    
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
}