public with sharing class ProjectProductChildHandlerUtilities {
 
    public static Milestone__c createMilestone(String name, String projectProductId, String projectProductChildId, Date startDate) {
        return new Milestone__c(
            Name = name,
            Status__c = 'Not Started',
            Project_Product__c = projectProductId,
            Project_Product_Child__c = projectProductChildId,
            StartDate__c = startDate
        );
    }

    public static void updateDesignStatusPhase(Set<Id> setProjectProductParentId) {
        List<ProjectProductChild__c> phaseDesignToUpdate = new List<ProjectProductChild__c>();
        for (ProjectProductChild__c projectProductChild : [SELECT Id, Status__c FROM ProjectProductChild__c 
                                                                    WHERE ProjectProductParent__c IN :setProjectProductParentId
                                                                    AND Name = 'Design' AND Status__c != 'Completed']) {
            projectProductChild.Status__c = 'Completed';
            phaseDesignToUpdate.add(projectProductChild);                   
        }
        if (!phaseDesignToUpdate.isEmpty()) {
            update phaseDesignToUpdate;
        }
    }

    /*
    public static Map<Id, ProjectProduct__c> getParentProjects(Set<Id> parentIds) {
        if (parentIds.isEmpty()) return new Map<Id, ProjectProduct__c>();

        return new Map<Id, ProjectProduct__c>(
        [SELECT Id, EndDate__c FROM ProjectProduct__c WHERE Id IN :parentIds]
        );
    } 
    */

    /*
    public static Boolean checkFieldFilled(SObject record, String fieldName) {
        return Schema.getGlobalDescribe().get(record.getSObjectType().getDescribe().getName())
                    .getDescribe().fields.getMap().containsKey(fieldName)
                    && record.get(fieldName) != null;
    } */
 
    /*
    public static List<SObject> getRecordWithFields(String sObjectTypeName, Set<Id> recordIds, List<String> fieldNames) {
        if (String.isEmpty(sObjectTypeName) || recordIds == null || recordIds.isEmpty()) {
            throw new IllegalArgumentException('Invalid parameters provided.');
        }
 
        String fields = 'Id, RecordType.DeveloperName, Name, ProjectProductParent__c, CompletionRateStep__c';
        if (!fieldNames.isEmpty()) {
            fields += ', ' + String.join(fieldNames, ',');
        }
 
        return Database.query('SELECT ' + fields + ' FROM ' + sObjectTypeName + ' WHERE Id IN :recordIds');
    } */

    /*
    public static Map<Id, List<ProjectShareclassChild__c>> getProjectShareclassChildren(Map<Id, Set<Id>> projectChildWithShareClassesMap) {
        Set<Id> shareClassIds = new Set<Id>();
        for (Set<Id> shareClasses : projectChildWithShareClassesMap.values()) {
            shareClassIds.addAll(shareClasses);
        }

        Map<Id, List<ProjectShareclassChild__c>> pChildWithShareclasseChildsMap = new Map<Id, List<ProjectShareclassChild__c>>();

        if (!shareClassIds.isEmpty()) {
            List<SObject> shareClassChilds = ProjectChildTeamValidationController.getRecordWithFields(
                'ProjectShareclassChild__c',
                shareClassIds,
                new List<String>()
            );

            System.debug('shareClassChilds: ' + shareClassChilds);

            for (SObject shareclasseChild : shareClassChilds) {
                ProjectShareclassChild__c shareclasseChildConverted = (ProjectShareclassChild__c) shareclasseChild;
                Id projectChildId = shareclasseChildConverted.ProjectShareclasses__c;

                if (!pChildWithShareclasseChildsMap.containsKey(projectChildId)) {
                    pChildWithShareclasseChildsMap.put(projectChildId, new List<ProjectShareclassChild__c>());
                }
                pChildWithShareclasseChildsMap.get(projectChildId).add(shareclasseChildConverted);
            }
        }
        return pChildWithShareclasseChildsMap;
    } */

    /*
    public static Decimal calculateCompletionRate(
        ProjectProductChild__c projectProductChild,
        Map<String, List<String>> requiredFieldsFundByStage,
        Map<String, List<String>> requiredFieldsShCByStage,
        Map<Id, Set<Id>> projectChildWithShareClassesMap,
        Map<Id, List<ProjectShareclassChild__c>> pChildWithShareclasseChildsMap,
        Map<Id, String> projectProductChildIdsWithRTNameMap
    ) {
        System.debug('[START] ------------------calculateCompletionRate on PRODUCT-------------------------------');
     
    Set<Id> shareClasses = projectChildWithShareClassesMap.containsKey(projectProductChild.Id)
    ? projectChildWithShareClassesMap.get(projectProductChild.Id)
            : new Set<Id>();
     
    System.debug('projectProductChild.Name: ' + projectProductChild.Name);
     
    List<String> uniqueAllRequiredFieldsFund = requiredFieldsFundByStage.get(projectProductChild.Name);
    List<String> uniqueAllRequiredFieldsShC = requiredFieldsShCByStage.get(projectProductChild.Name);
     
        System.debug('uniqueAllRequiredFieldsFund: ' + uniqueAllRequiredFieldsFund);
        System.debug('uniqueAllRequiredFieldsShC: ' + uniqueAllRequiredFieldsShC);
     
        Integer completedFields = 0;
        Integer totalFields = uniqueAllRequiredFieldsFund.size();
     
        // Vérification des champs Fund
        if (totalFields > 0) {
            for (String field : uniqueAllRequiredFieldsFund) {
                if (projectProductChild.get(field) != null) {
                    completedFields++;
                }
            }
        }
     
        // Vérification des ShareClassChild
        if (!shareClasses.isEmpty()) {
            totalFields += uniqueAllRequiredFieldsShC.size() * shareClasses.size();
     
            List<ProjectShareclassChild__c> shareClassChildren = new List<ProjectShareclassChild__c>();
            for (Id shareClassId : shareClasses) {
                if (pChildWithShareclasseChildsMap.containsKey(shareClassId)) {
                    shareClassChildren.addAll(pChildWithShareclasseChildsMap.get(shareClassId));
                }
            }
     
            for (ProjectShareclassChild__c shareClasse : shareClassChildren) {
                if (shareClasse.RecordType != null &&
    shareClasse.RecordType.DeveloperName == projectProductChildIdsWithRTNameMap.get(projectProductChild.Id)) {
     
                    for (String field : uniqueAllRequiredFieldsShC) {
                        if (shareClasse.get(field) != null) {
                            completedFields++;
                        }
                    }
                }
            }
        }
     
        Decimal returnValue = (totalFields > 0)
            ? ((Decimal.valueOf(completedFields) / totalFields) * 100).setScale(2)
            : 0;
     
        System.debug('returnValue: ' + returnValue);
        return returnValue;
    } */
    
}