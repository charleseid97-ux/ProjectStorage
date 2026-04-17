public without sharing class ShareclassNavigatorController {

    @AuraEnabled(cacheable=true)
    public static List<Share_Class__c> getFilteredReferentialShareclasses(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            return new List<Share_Class__c>();
        }

        String searchLike = '%' + searchTerm + '%';

        return [
            SELECT Id, Name
            FROM Share_Class__c
            WHERE Name LIKE :searchLike
            ORDER BY Name
            LIMIT 20
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<ProjectShareclass__c> getFilteredProjectShareclasses(Id projectChildId, String searchTerm) {
        if (String.isBlank(searchTerm) || projectChildId == null) {
            return new List<ProjectShareclass__c>();
        }

        String searchLike = '%' + searchTerm + '%';

        List<ProjectChildJunction__c> junctions = [
            SELECT ProjectShareclass__c
            FROM ProjectChildJunction__c
            WHERE ProjectProductChild__c = :projectChildId
        ];

        Set<Id> shareclassIds = new Set<Id>();
        for (ProjectChildJunction__c junc : junctions) {
            shareclassIds.add(junc.ProjectShareclass__c);
        }

        List<ProjectShareclass__c> l_projectShareclass = [SELECT Id, Share_class_name__c
            FROM ProjectShareclass__c
            WHERE Id IN :shareclassIds
            AND Share_class_name__c LIKE :searchLike
            ORDER BY Share_class_name__c
            LIMIT 20];

        return l_projectShareclass;
    }


    @AuraEnabled(cacheable=true)
    public static String getProjectProductRecordType(Id projectProductChildId) {
        ProjectProductChild__c child = [
            SELECT ProjectProductParent__c 
            FROM ProjectProductChild__c 
            WHERE Id = :projectProductChildId
            LIMIT 1
        ];
 
        if (child.ProjectProductParent__c == null) {
            return null;
        }
 
        ProjectProduct__c parent = [
            SELECT RecordType.DeveloperName 
            FROM ProjectProduct__c 
            WHERE Id = :child.ProjectProductParent__c
            LIMIT 1
        ];
 
        return parent.RecordType.DeveloperName;
    }

    @AuraEnabled
    public static void deleteProjectShareclass(Id shareclassId, Id projectProductChildId) {
        if (shareclassId == null) {
            throw new IllegalArgumentException('Invalid Shareclass ID');
        }
    
        // Récupérer les enfants ProjectShareclassChild__c
        List<ProjectShareclassChild__c> children = [
            SELECT Id FROM ProjectShareclassChild__c WHERE ProjectShareclasses__c = :shareclassId
        ];
    
        // Supprimer les enfants en premier
        if (!children.isEmpty()) {
            delete children;
        }
    
        // Supprimer la Shareclass (les enregistrements ProjectChildJunction__c seront supprimés automatiquement grâce au Master-Detail)
        ProjectShareclass__c shareclassToDelete = [
            SELECT Id FROM ProjectShareclass__c WHERE Id = :shareclassId
        ];
        
        delete shareclassToDelete;

        ProjectProductChild__c recalculationChild = [SELECT Id FROM ProjectProductChild__c WHERE Id = :projectProductChildId LIMIT 1];   
        update recalculationChild;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean canUserCreateShareclass(String currentRecordId) {
        // Récupération du profil utilisateur actuel
        String profileId = UserInfo.getProfileId();
        String profileName = [SELECT Name FROM Profile WHERE Id = :profileId].Name;
    
        // Vérification des profils autorisés
        List<String> allowedProfiles = new List<String>{
            'Carmignac - System Administrator',
            'System Administrator'
        };
    
        Boolean hasPermissionProductStrategy = FeatureManagement.checkPermission('PRPProductStrategy');
        Boolean hasPermissionIS = FeatureManagement.checkPermission('PRPIS');
    
        // Retourne vrai si l'utilisateur a un des profils autorisés OU la custom permission
        return allowedProfiles.contains(profileName) || hasPermissionProductStrategy || hasPermissionIS;
    }


    @AuraEnabled
    public static void createAndLinkShareclass(Id projectChildId, String type, String ocurrency, String dividendPolicy, String dividendFrequency, String currencyHedging) {
        if (String.isBlank(projectChildId)) {
            throw new IllegalArgumentException('Le ProjectProductChild et le nom du Shareclass ne peuvent pas être vides.');
        }
        ProjectProductChild__c projectParent = [SELECT ProjectProductParent__c  FROM ProjectProductChild__c WHERE Id = :projectChildId LIMIT 1];

        ProjectShareclass__c newShareclass = new ProjectShareclass__c(
            Type__c = type,
            ProjectProduct__c = projectParent.ProjectProductParent__c,
            Currency__c = ocurrency, // ✅ Modification ici
            DividendPolicy__c = dividendPolicy,
            DividendFrequency__c = dividendFrequency,
            CurrencyHedging__c = currencyHedging
        );

        insert newShareclass;
     
        ShareclassCloner.createObjectJunctions(projectChildId, newShareclass.Id);
    }
    
    
    @AuraEnabled
    public static Id cloneApexShareclass(Id projectChildId, Id shareClassId, String objectAPIName) {

        ProjectProductChild__c projectParent = [
            SELECT ProjectProductParent__c  
            FROM ProjectProductChild__c 
            WHERE Id = :projectChildId 
            LIMIT 1
        ];

        if (String.isBlank(projectChildId) || String.isBlank(shareClassId)) {
            throw new IllegalArgumentException('Invalid parameters');
        }

        Id newShareclassId;

        if (objectAPIName == 'Share_Class__c') {
            newShareclassId = ShareclassCloner.cloneShareClass(shareClassId, projectParent.ProjectProductParent__c);
        } 
        else if (objectAPIName == 'ProjectShareclass__c') {
            newShareclassId = ShareclassCloner.cloneProjectShareClass(shareClassId, projectParent.ProjectProductParent__c);

            ProjectShareclass__c clonedRecord = new ProjectShareclass__c(
                Id = newShareclassId,
                ClonedByProjectShareclass__c = shareClassId,
                ClonedByReferential__c = null
            );
            update clonedRecord;
        }

        ShareclassCloner.createObjectJunctions(projectChildId, newShareclassId);
        return newShareclassId;
    }

    /****************************/
    /******** UTILITIES *********/
    /****************************/

    @AuraEnabled(cacheable=true)
        public static String getShareClassName(Id shareClassId) {
        if (shareClassId == null) {
            return null;
        }
    
        Share_Class__c shareClass = [
            SELECT Name FROM Share_Class__c WHERE Id = :shareClassId LIMIT 1
        ];
    
        return shareClass != null ? shareClass.Name : null;
    }

    @AuraEnabled(cacheable=true)
        public static Id getRecordId(Id currentRecordId) {
            if (currentRecordId == null) {
                return null;
            }
            String objName = currentRecordId.getSObjectType().getDescribe().getName();
            if (objName == 'ProjectProductChild__c') {
                return currentRecordId;
            } else if (objName == 'ProjectProduct__c') {
                ProjectProductChild__c currentRecord = [
                    SELECT Id
                    FROM ProjectProductChild__c
                    WHERE ProjectProductParent__c = :currentRecordId AND TECH_Childtype__c = 'DesignAndProposal'
                    LIMIT 1];
                return currentRecord.Id;
            }
            return null;
  
            
    }

    @AuraEnabled(cacheable=true)
    public static List<Id> getProjectShareclasses(Id projectChildId) {
        if (projectChildId == null) {
            return new List<Id>(); // Retourne une liste vide si aucun ID n'est fourni
        }
    
        List<ProjectChildJunction__c> junctions = [
            SELECT ProjectShareclass__c 
            FROM ProjectChildJunction__c 
            WHERE ProjectProductChild__c = :projectChildId
        ];
    
        List<Id> shareclassIds = new List<Id>();
        for (ProjectChildJunction__c junction : junctions) {
            if (junction.ProjectShareclass__c != null) {
                shareclassIds.add(junction.ProjectShareclass__c);
            }
        }
    
        return shareclassIds;
    }



    @AuraEnabled(cacheable=true)
public static List<ProjectShareclassWrapper> getLinkedShareclasses(Id projectChildId) {
    List<ProjectChildJunction__c> junctions = [
        SELECT ProjectShareclass__r.Id, 
            ProjectShareclass__r.Name, 
            ProjectShareclass__r.Type__c,
            ProjectShareclass__r.Share_Class_Name__c,
            ProjectShareclass__r.Currency__c, 
            ProjectShareclass__r.DividendPolicy__c, 
            ProjectShareclass__r.DividendFrequency__c,
            ProjectShareclass__r.CurrencyHedging__c, 
            ProjectShareclass__r.TECH_DoNotProcess__c,
            ProjectShareclass__r.ClonedByProjectShareclass__c, 
            ProjectShareclass__r.ClonedByProjectShareclass__r.Name,
            ProjectShareclass__r.ClonedByProjectShareclass__r.Share_Class_Name__c,
            ProjectShareclass__r.ClonedByReferential__c, 
            ProjectShareclass__r.ClonedByReferential__r.Name,
            ProjectShareclass__r.TECH_FieldsToModify__c
        FROM ProjectChildJunction__c
        WHERE ProjectProductChild__c = :projectChildId
    ];

    List<ProjectShareclassWrapper> result = new List<ProjectShareclassWrapper>();
    for (ProjectChildJunction__c junction : junctions) {
        if (junction.ProjectShareclass__r != null) {
            ProjectShareclassWrapper wrapper = new ProjectShareclassWrapper();
            wrapper.shareclass = junction.ProjectShareclass__r;
            wrapper.doNotProcess = junction.ProjectShareclass__r.TECH_DoNotProcess__c;
            result.add(wrapper);
        }
    }
    return result;
}
    
    
    @AuraEnabled
    public static Id getProjectShareclassChild(Id projectChildId, Id shareclassId) {
        List<ProjectProductChild__c> l_projectProductChild = [SELECT TECH_Childtype__c
                                                                FROM ProjectProductChild__c
                                                                WHERE Id = :projectChildId
                                                                LIMIT 1];
        ProjectProductChild__c projectChild = l_projectProductChild[0];
        
        // Récupérer le ProjectShareclassChild correspondant
        List<ProjectShareclassChild__c> shareclassChild = [SELECT Id
                                                        FROM ProjectShareclassChild__c
                                                        WHERE ProjectShareclasses__c = :shareclassId
                                                        AND TECH_Childtype__c = :projectChild.TECH_Childtype__c
                                                        LIMIT 1];
        return shareclassChild.size() > 0 ? shareclassChild[0].Id : null;
    }
 
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPicklistValues() {
        Map<String, List<String>> picklistMap = new Map<String, List<String>>();
     
        Schema.DescribeFieldResult typeField = ProjectShareclassChild__c.Type__c.getDescribe();
        Schema.DescribeFieldResult currencyField = ProjectShareclassChild__c.Currency__c.getDescribe();
        Schema.DescribeFieldResult dividendField = ProjectShareclassChild__c.DividendPolicy__c.getDescribe();
        Schema.DescribeFieldResult dividendFrequencyField = ProjectShareclassChild__c.DividendFrequency__c.getDescribe();
        Schema.DescribeFieldResult currencyHedging = ProjectShareclassChild__c.CurrencyHedging__c.getDescribe();
          
        picklistMap.put('Type__c', new List<String>());
        for (Schema.PicklistEntry entry : typeField.getPicklistValues()) {
            picklistMap.get('Type__c').add(entry.getLabel());
        }
     
        picklistMap.put('Currency__c', new List<String>());
        for (Schema.PicklistEntry entry : currencyField.getPicklistValues()) {
            picklistMap.get('Currency__c').add(entry.getValue());
        }
     
        picklistMap.put('DividendPolicy__c', new List<String>());
        for (Schema.PicklistEntry entry : dividendField.getPicklistValues()) {
            picklistMap.get('DividendPolicy__c').add(entry.getLabel());
        }

        picklistMap.put('DividendFrequency__c', new List<String>());
        for (Schema.PicklistEntry entry : dividendFrequencyField.getPicklistValues()) {
            picklistMap.get('DividendFrequency__c').add(entry.getLabel());
        }

        picklistMap.put('CurrencyHedging__c', new List<String>());
        for (Schema.PicklistEntry entry : currencyHedging.getPicklistValues()) {
            picklistMap.get('CurrencyHedging__c').add(entry.getLabel());
        }
     
        return picklistMap;
    }

    public class ProjectShareclassWrapper {
        @AuraEnabled public ProjectShareclass__c shareclass;
        @AuraEnabled public Boolean doNotProcess;
        @AuraEnabled public Boolean haveSelectedFields;
    }
}