public class ShareclassCloner {
    /**
     * Clone une Share_Class__c vers ProjectShareclass__c
     */
    public static Id cloneShareClass(Id shareClassId, String projectProductId) {
        if (shareClassId == null) {
            throw new IllegalArgumentException('Param shareClassId mandatory error.');
        }

        // Query dynamique de tous les champs (hors exclusions)
        String fieldsToQuery = RecordCloneHelper.getAllFieldNames('Share_Class__c');
        String query = 'SELECT ' + fieldsToQuery + ' FROM Share_Class__c WHERE Id = :shareClassId LIMIT 1';
        Share_Class__c originalShareClass = Database.query(query);

        // Clonage via classe générique
        ProjectShareclass__c newProjectShareClass = (ProjectShareclass__c) RecordCloneHelper.cloneRecordFields(
            originalShareClass, 
            new ProjectShareclass__c()
        );

        // Particularités spécifiques à conserver
        newProjectShareClass.ClonedByReferential__c = shareClassId;
        newProjectShareClass.ProjectProduct__c = projectProductId;

        insert newProjectShareClass;

        return newProjectShareClass.Id;
    }

    /**
     * Clone une ProjectShareclass__c existante vers une nouvelle ProjectShareclass__c
     */
    public static Id cloneProjectShareClass(Id projectShareClassId, String projectProductId) {
        if (projectShareClassId == null) {
            throw new IllegalArgumentException('Param projectShareClassId obligatoire.');
        }

        // Query dynamique de tous les champs (hors exclusions)
        String fieldsToQuery = RecordCloneHelper.getAllFieldNames('ProjectShareclass__c');
        String query = 'SELECT ' + fieldsToQuery + ' FROM ProjectShareclass__c WHERE Id = :projectShareClassId LIMIT 1';
        ProjectShareclass__c originalProjectShareClass = Database.query(query);

        // Clonage via classe générique
        ProjectShareclass__c newProjectShareClass = (ProjectShareclass__c) RecordCloneHelper.cloneRecordFields(
            originalProjectShareClass, 
            new ProjectShareclass__c()
        );

        // Particularités spécifiques à conserver
        newProjectShareClass.ClonedByProjectShareclass__c = projectShareClassId;
        newProjectShareClass.ProjectProduct__c = projectProductId;

        insert newProjectShareClass;

        // Vérification et correction éventuelle du champ spécifique
        if (newProjectShareClass.ClonedByProjectShareclass__c == null) {
            newProjectShareClass.ClonedByProjectShareclass__c = projectShareClassId;
            update newProjectShareClass;
            System.debug('⚠️ Correction du champ ClonedByProjectShareclass__c effectué après insertion.');
        }

        return newProjectShareClass.Id;
    }
    
    public static void createObjectJunctions(Id projectChildId, Id newShareclassId) {

        ProjectProductChild__c currentChild = [
            SELECT ProjectProductParent__c
            FROM ProjectProductChild__c
            WHERE Id = :projectChildId
            LIMIT 1
        ];
 
        if (currentChild == null || currentChild.ProjectProductParent__c == null) {
            throw new IllegalArgumentException('Parent ProjectProduct not found.');
        }
 
        List<ProjectProductChild__c> siblingChildren = [
            SELECT Id FROM ProjectProductChild__c WHERE ProjectProductParent__c = :currentChild.ProjectProductParent__c
        ];
 
        List<ProjectChildJunction__c> junctions = new List<ProjectChildJunction__c>();
        for (ProjectProductChild__c sibling : siblingChildren) {
            junctions.add(new ProjectChildJunction__c(
                ProjectProductChild__c = sibling.Id,
                ProjectShareclass__c = newShareclassId
            ));
        }
 
        if (!junctions.isEmpty()) {
            insert junctions;
        }

        ProjectProductChild__c fakeObject = [SELECT Id FROM ProjectProductChild__c WHERE Id = :projectChildId];
        update fakeObject;
    }
 
    public static void createShareclassChildren(Id newShareclassId) {
        List<ProjectShareclassChild__c> shareclassChildren = new List<ProjectShareclassChild__c>();
 
        Map<String, String> recordTypes = new Map<String, String>{
            'DesignAndProposal' => 'DesignAndProposal',
            'Engineering' => 'Engineering',
            'Filing' => 'Filing',
            'SetUp' => 'SetUp'
        };
 
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
                ProjectShareclasses__c = newShareclassId,
                TECH_Childtype__c = recordTypeName,
                Name = shareclassChildName
            ));
        }
 
        if (!shareclassChildren.isEmpty()) {
            insert shareclassChildren;
        }
    }

    public static void createShareclassChildrenWithFields(Id newShareclassId, ProjectShareclass__c parentShareclass, String baseName) {
        List<ProjectShareclassChild__c> shareclassChildren = new List<ProjectShareclassChild__c>();
        Map<String, String> recordTypes = new Map<String, String>{
            'DesignAndProposal' => 'DesignAndProposal',
            'Engineering' => 'Engineering',
            'Filing' => 'Filing',
            'SetUp' => 'SetUp'
        };
     
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
                ProjectShareclasses__c = newShareclassId,
                TECH_Childtype__c = recordTypeName,
                Name = shareclassChildName,
                Type__c = parentShareclass.Type__c,
                CurrencyIsoCode = parentShareclass.CurrencyIsoCode,
                DividendPolicy__c = parentShareclass.DividendPolicy__c,
                CurrencyHedging__c = parentShareclass.CurrencyHedging__c
            ));
        }
        if (!shareclassChildren.isEmpty()) {
            insert shareclassChildren;
        }
    }
    
}