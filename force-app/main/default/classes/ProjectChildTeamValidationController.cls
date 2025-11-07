public without sharing class ProjectChildTeamValidationController {
    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();  
    
    /**
     * Méthode qui renvoie les champs à exclure lors des validations selon le record type.
     * Ignore les exclusions si RecordType != ShareclassCreation
     */
    public static Set<String> getExcludedFieldsForValidation(String recordTypeDevName) {
        Set<String> fieldsToExclude = new Set<String>();

        // Ne pas appliquer d'exclusion si le recordType est ShareclassCreation
        if (recordTypeDevName != 'ShareclassCreation') {
            return fieldsToExclude; // Set vide
        }

        // Sinon, charger les champs à exclure depuis PMTExcludeFieldSCValidation__mdt
        PMTExcludeFieldSCValidation__mdt excludeSettings = PMTExcludeFieldSCValidation__mdt.getInstance('ProjectProduct');
        if (excludeSettings != null && excludeSettings.FieldsToExclude__c != null) {
            fieldsToExclude.addAll(excludeSettings.FieldsToExclude__c.split(';'));
        }

        return fieldsToExclude;
    }

    @AuraEnabled(cacheable=true)
    public static String getParentRecordTypeName(Id recordId) {
        Id parentId = [SELECT ProjectProductParent__c FROM ProjectProductChild__c WHERE Id = :recordId LIMIT 1].ProjectProductParent__c;
        return [SELECT RecordType.DeveloperName FROM ProjectProduct__c WHERE Id = :parentId LIMIT 1].RecordType.DeveloperName;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> checkPortfolioManager() {
            Id userId = UserInfo.getUserId();
            List<PermissionSetAssignment> permissions = [
        SELECT PermissionSet.Name FROM PermissionSetAssignment 
                WHERE AssigneeId = :userId
            ];
            List<String> permissionNames = new List<String>();
            for (PermissionSetAssignment perm : permissions) {
        permissionNames.add(perm.PermissionSet.Name);
            }
            return permissionNames;
    }
    @AuraEnabled(cacheable=true)
    public static List<String> getUserPermissions() {
            Id userId = UserInfo.getUserId();
            List<PermissionSetAssignment> permissions = [
        SELECT PermissionSet.Name FROM PermissionSetAssignment 
                WHERE AssigneeId = :userId
            ];
            List<String> permissionNames = new List<String>();
            for (PermissionSetAssignment perm : permissions) {
        permissionNames.add(perm.PermissionSet.Name);
            }
            return permissionNames;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMetadataFields(List<String> objectApiNames) {
        List<Map<String, String>> fieldsList = new List<Map<String, String>>();
     
        for (String objectApiName : objectApiNames) {
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
            if (sObjectType == null) continue;
     
            Map<String, Schema.SObjectField> fieldsMap = sObjectType.getDescribe().fields.getMap();
     
            for (String fieldName : fieldsMap.keySet()) {
                Map<String, String> fieldInfo = new Map<String, String>();
                fieldInfo.put('label', fieldsMap.get(fieldName).getDescribe().getLabel());
                fieldInfo.put('value', fieldName);
                fieldInfo.put('sourceObject', objectApiName); // optional for traceability
                fieldsList.add(fieldInfo);
            }
        }
        System.debug('fieldsList: ' + fieldsList);
        return fieldsList;
    }

    @AuraEnabled(cacheable=true)
    public static Id getRecordId(Id currentRecordId) {
        if (currentRecordId == null) {
            return null;
        }
        String objName = currentRecordId.getSObjectType().getDescribe().getName();
        if (objName == 'ProjectProductChild__c') {
            return currentRecordId;
        } else if (objName == 'ProjectShareclassChild__c') {
            ProjectShareclassChild__c scRecord = [
                SELECT TECH_Childtype__c,ProjectShareclasses__c FROM ProjectShareclassChild__c 
                WHERE Id = :currentRecordId
                LIMIT 1];
                String stage = scRecord.TECH_Childtype__c;
                if(scRecord.TECH_Childtype__c =='DesignAndProposal'){
                    stage = 'Proposal';
                }
                ProjectChildJunction__c currentRecord = [
                    SELECT ProjectProductChild__c,ProjectProductChild__r.TECH_Childtype__c,ProjectShareclass__c FROM ProjectChildJunction__c 
                    WHERE ProjectShareclass__c = :scRecord.ProjectShareclasses__c AND ProjectProductChild__r.Name = :stage
                LIMIT 1];
            return currentRecord.ProjectProductChild__c;
        }
        return null;    
    }

    @AuraEnabled(cacheable=true)
    public static ProjectProductChild__c getProjectChild(Id recordId) {
            return [
                SELECT Id, TECH_TeamValidation__c , RecordType.DeveloperName FROM ProjectProductChild__c 
                WHERE Id = :recordId
                LIMIT 1
            ];
    }

    @AuraEnabled
    public static void updateTeamValidation(Id recordId, String teamName) {
            ProjectProductChild__c projectChild = [
                SELECT Id, TECH_TeamValidation__c , RecordType.DeveloperName 
                FROM ProjectProductChild__c 
                WHERE Id = :recordId
                LIMIT 1 ];
                /*
            Set<Id> shareClassesId= getShareclassesId(recordId);
            List<ProjectShareclassChild__c> shareClassChilds= [
                SELECT  Id, TECH_TeamValidation__c , RecordType.DeveloperName 
                FROM  ProjectShareclassChild__c
                WHERE ProjectShareclasses__c 
                IN :shareClassesId];
            List<ProjectShareclassChild__c> shareClassChildsToUpdate = new List<ProjectShareclassChild__c> ();
            for(ProjectShareclassChild__c shareClasseChild: shareClassChilds){
                if(shareClasseChild.RecordType.DeveloperName == projectChild.RecordType.DeveloperName ){
                    String newValueShC = (shareClasseChild.TECH_TeamValidation__c == null) ? teamName : shareClasseChild.TECH_TeamValidation__c + ';' + teamName;
                    shareClasseChild.TECH_TeamValidation__c = newValueShC;
                    shareClassChildsToUpdate.add(shareClasseChild);
                }
            }
            String newValue = (projectChild.TECH_TeamValidation__c == null) ? teamName : projectChild.TECH_TeamValidation__c + ';' + teamName;
            projectChild.TECH_TeamValidation__c = newValue;
            update shareClassChildsToUpdate; */
            System.debug('TECH_TeamValidation__c:' + projectChild.TECH_TeamValidation__c);
             String newValue = (projectChild.TECH_TeamValidation__c == null) ? teamName : projectChild.TECH_TeamValidation__c + ';' + teamName;
             projectChild.TECH_TeamValidation__c = newValue;
         
                update projectChild;

    }

    public static List<SObject> getRecordWithFields(String sObjectTypeName, Set<Id> recordIds, List<String> fieldNames) {
        System.debug(' (start) getRecordWithFields');
        String query ;
        // Vérifier si les paramètres sont valides
        if (String.isEmpty(sObjectTypeName) || recordIds == null ) {
            throw new IllegalArgumentException('Invalid parameters provided.');
        }
        if (fieldNames == null ||  fieldNames.isEmpty()){
            if( sObjectTypeName == 'ProjectShareclassChild__c'){
                query = 'SELECT Id,ProjectShareclasses__r.Share_Class_Name__c ,RecordType.DeveloperName FROM ' + sObjectTypeName + ' WHERE ProjectShareclasses__c IN :recordIds';
            } else {
                query = 'SELECT Id, TECH_ProjectRecordType__c, RecordType.DeveloperName FROM ' + sObjectTypeName + ' WHERE Id IN :recordIds';
            }
        } else {
    
        // Construire la liste des champs sous forme de chaîne pour SOQL
        String fields = String.join(fieldNames, ',');
        
        // Construire la requête SOQL dynamique
        
        System.debug('fields:' + fields);
            if( sObjectTypeName == 'ProjectShareclassChild__c'){
            query = 'SELECT ' + fields + ', ProjectShareclasses__r.Share_Class_Name__c, RecordType.DeveloperName , Id FROM ' + sObjectTypeName + ' WHERE ProjectShareclasses__c IN :recordIds';
            } else {
            query = 'SELECT ' + fields + ' , TECH_ProjectRecordType__c , RecordType.DeveloperName , Id FROM ' + sObjectTypeName + ' WHERE Id IN :recordIds';
            }}
    
           
        // Exécuter la requête et retourner l'enregistrement
        System.debug('query:' + query);
        return Database.query(query);
    }


    public static Set<Id> getShareclassesId(Id recordId) {
        List<ProjectChildJunction__c> projectChildJunctions = [
                SELECT Id,ProjectProductChild__c  , ProjectShareclass__c 
                FROM ProjectChildJunction__c 
                WHERE ProjectProductChild__c = :recordId];
            Set<Id> shareclassIds= new Set<Id>();
            for(ProjectChildJunction__c projectChildJunction:projectChildJunctions){
                if(projectChildJunction.ProjectShareclass__c != null){
                    shareclassIds.add(projectChildJunction.ProjectShareclass__c);
                }
            }
            return shareclassIds;
    }

    @AuraEnabled
    public static Boolean hasProposalPortfolioManager(Id recordId) {
        List<FundManagerAssignment__c> fundManagerAssignement = [SELECT Id FROM FundManagerAssignment__c WHERE ProductChildLink__c = :recordId ];
        if (fundManagerAssignement.isEmpty()) {
            //Here you need to put false to verify
            //Just for test purpose please put "false" if you want to check the portfolio manager
            return false;
        }
        return true;
    }

    @AuraEnabled
    public static Map<String, List<Map<String, List<String>>>> checkRequiredFiledsIsEmpty(Id recordId, String teamName, String stepName) {
        Id parentProjectId = [SELECT ProjectProductParent__c FROM ProjectProductChild__c WHERE Id = :recordId LIMIT 1].ProjectProductParent__c;
        String recordTypeDevName = [SELECT RecordType.DeveloperName FROM ProjectProduct__c WHERE Id = :parentProjectId LIMIT 1].RecordType.DeveloperName;
     
        if (recordTypeDevName == 'FundShareClassModification') {
            System.debug('----------- start checkRequiredFieldsFundShareClassModification ----------');
            return checkRequiredFieldsFundShareClassModification(recordId, stepName, teamName);
        } else {
            System.debug('----------- start checkRequiredFieldsClassic ----------');
            return checkRequiredFieldsClassic(recordId, teamName, stepName);
        }
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getShareClassesMatrix(Id recordId, String teamName, String stepName) {
        
        String fieldsToQuery = '';
        List<String> fieldList = new List<String>();

        List<ProjectChildJunction__c> projectChildJunctions = [
            SELECT Id,ProjectProductChild__c  , ProjectShareclass__c 
            FROM ProjectChildJunction__c 
            WHERE ProjectProductChild__c = :recordId];
           
        ProductProjectSettings__c matrixFunds = [ SELECT Id, RequiredFieldsShareClass__c, NonRequiredFieldsShareClass__c 
                                                    FROM ProductProjectSettings__c 
                                                    WHERE Team__c =:teamName and Stage__c =:stepName
                                                    LIMIT 1 ];
                                                    
        if (matrixFunds.RequiredFieldsShareClass__c != null) {
            fieldList.addAll(matrixFunds.RequiredFieldsShareClass__c.split(';'));
        }

        if (matrixFunds.NonRequiredFieldsShareClass__c != null) {
            fieldList.addAll(matrixFunds.NonRequiredFieldsShareClass__c.split(';'));
        }

        fieldList.add('Id');
        fieldList.add('shareClassName__c');

        List<Id> shareclassIds= new List<Id>();
        
        for(ProjectChildJunction__c projectChildJunction : projectChildJunctions){
            if(projectChildJunction.ProjectShareclass__c != null){
                shareclassIds.add(projectChildJunction.ProjectShareclass__c);
            }
        }

        String query = 'SELECT ' + String.join(fieldList, ',') + ' FROM ProjectShareclassChild__c ' +
        'WHERE ProjectShareclasses__c IN :shareclassIds AND Tech_Childtype__c like \'%'+stepName+'%\'';

        List<SObject> record = Database.query(query);

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for(SObject rec : record) {
            Map<String, Object> recMap = new Map<String, Object>();
            for (String fieldName : fieldList) {
                if(rec.get(fieldName) == null) {
                    recMap.put(fieldName, '');
                } else {
                    recMap.put(fieldName, rec.get(fieldName));
                }
            }
            result.add(recMap);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getFundMatrix(Id recordId, String teamName, String stepName) {
        
        String fieldsToQuery = '';
        List<String> fieldList = new List<String>();

        ProductProjectSettings__c matrixFunds = [
            SELECT RequiredFields__c, NonRequiredFieldsFund__c 
            FROM ProductProjectSettings__c 
            WHERE Team__c = :teamName AND Stage__c = :stepName
            LIMIT 1
        ];

        if (matrixFunds.RequiredFields__c != null) {
            fieldList.addAll(matrixFunds.RequiredFields__c.split(';'));
        }
        if (matrixFunds.NonRequiredFieldsFund__c != null) {
            fieldList.addAll(matrixFunds.NonRequiredFieldsFund__c.split(';'));
        }

        // Always include Id
        fieldList.add('Id');

        String query = 'SELECT ' + String.join(fieldList, ',') + ' FROM ProjectProductChild__c WHERE Id = :recordId';
        System.debug('query: ' + query);

        SObject record = Database.query(query);

        // Build the map to return
        Map<String, Object> result = new Map<String, Object>();
        for (String fieldName : fieldList) {
            if(record.get(fieldName) == null) {
                result.put(fieldName, '');
            } else {
                result.put(fieldName, record.get(fieldName));
            }
        }
        System.debug('getFund result: ' + result);
        return result;

    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getFund(Id recordId, String teamName, String stepName) {
        String fieldsToQuery = '';
        List<String> fieldList = new List<String>();

        String objectPrefix = String.valueOf(recordId).substring(0, 3);
        String sObjectType;
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        // for (Schema.SObjectType type : globalDescribe.values()) {
        //     if (type.getDescribe().getKeyPrefix() == objectPrefix) {
        //         sObjectType = type.getDescribe().getName();
        //         break;
        //     }
        // }

        // Describe fields for the object
        Schema.SObjectType objType = globalDescribe.get('ProjectProductChild__c');
    
        Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();

        String soqlFields = String.join(new List<String>(fieldsMap.keySet()), ',');
        String query = 'SELECT ' + soqlFields + ' FROM ProjectProductChild__c WHERE Id = \''+recordId +'\'';
        System.debug('query: ' + query);

        SObject record = Database.query(query);

        // Build the map to return
        Map<String, Object> result = new Map<String, Object>();

        for (String fieldName : fieldsMap.keySet()) {
            System.debug('fieldsMap.get(fieldName).getDescribe().getName(): ' + fieldsMap.get(fieldName).getDescribe().getName());
            System.debug('VALUE : ' + record.get(fieldName));
if (record.get(fieldName) == null) {
                result.put(fieldsMap.get(fieldName).getDescribe().getName(), '');
            } else {
                result.put(fieldsMap.get(fieldName).getDescribe().getName(), record.get(fieldName));
            }
            // result.put(fieldsMap.get(fieldName).getDescribe().getName(), record.get(fieldName));
        }

        System.debug('getFund result: ' + result);
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getShareClasses(Id recordId, String teamName, String stepName) {
        
        String fieldsToQuery = '';
        List<String> fieldList = new List<String>();

        List<ProjectChildJunction__c> projectChildJunctions = [
            SELECT Id,ProjectProductChild__c  , ProjectShareclass__c 
            FROM ProjectChildJunction__c 
            WHERE ProjectProductChild__c = :recordId];            
        
        // String objectPrefix = String.valueOf(projectChildJunctions[0].ProjectShareclass__c).substring(0, 3);
        String sObjectType = 'ProjectShareclassChild__c';
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        // for (Schema.SObjectType type : globalDescribe.values()) {
        //     if (type.getDescribe().getKeyPrefix() == objectPrefix) {
        //         sObjectType = type.getDescribe().getName();
        //         break;
        //     }
        // }

        // Describe fields for the object
        Schema.SObjectType objType = globalDescribe.get(sObjectType);
    
        Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();
        System.debug('fieldsMap: ' + fieldsMap.values());

        String soqlFields = String.join(new List<String>(fieldsMap.keySet()), ',');
        List<Id> shareclassIds= new List<Id>();
        
        for(ProjectChildJunction__c projectChildJunction : projectChildJunctions){
            if(projectChildJunction.ProjectShareclass__c != null){
                shareclassIds.add(projectChildJunction.ProjectShareclass__c);
            }
        }

        System.debug('shareclassIds: ' + shareclassIds);

        String query = 'SELECT ' + soqlFields + ' FROM ProjectShareclassChild__c ' +
        'WHERE ProjectShareclasses__c IN :shareclassIds AND Tech_Childtype__c like \'%'+stepName+'%\'';
        
        System.debug('query: ' + query);

        List<SObject> record = Database.query(query);

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for(SObject rec : record) {
            Map<String, Object> recMap = new Map<String, Object>();
            for (String fieldName : fieldsMap.keySet()) {
                if(rec.get(fieldsMap.get(fieldName).getDescribe().getName()) == null) {
                    recMap.put(fieldsMap.get(fieldName).getDescribe().getName(), '');
                } else {
                    recMap.put(fieldsMap.get(fieldName).getDescribe().getName(), rec.get(fieldsMap.get(fieldName).getDescribe().getName()));
                }
                // System.debug('Field: ' + fieldsMap.get(fieldName).getDescribe().getName() + ' Value: ' + rec.get(fieldsMap.get(fieldName).getDescribe().getName()));
            }
            result.add(recMap);
        }
        System.debug('result: ' + result);

        return result;
    }

    public static Map<String, List<Map<String, List<String>>>> checkRequiredFieldsFundShareClassModification(Id recordId, String stepName, String teamName) {
        System.debug('----------- start checkRequiredFieldsFundShareClassModification ----------');
     
        Map<String, List<Map<String, List<String>>>> requiredFieldsEmpty = new Map<String, List<Map<String, List<String>>>>();
        List<String> emptyFundFields = new List<String>();
        Map<String, String> m_StepByField = ProjectMatriceUtilities.getMapStepByField(teamName);
     
        // Fund - ProjectProductChild
        ProjectProductChild__c fund = [
            SELECT Id, ProjectProductParent__c, RecordType.DeveloperName, ProjectProductParent__r.TECH_FieldsToModify__c
            FROM ProjectProductChild__c
            WHERE Id = :recordId
            LIMIT 1
        ];
     
        List<String> fundFieldsToCheck = (fund.ProjectProductParent__r.TECH_FieldsToModify__c != null)
            ? fund.ProjectProductParent__r.TECH_FieldsToModify__c.split(';')
            : new List<String>();
     
        if (!fundFieldsToCheck.isEmpty()) {
            String fundQuery = 'SELECT Id, ' + String.join(fundFieldsToCheck, ',') + ' FROM ProjectProductChild__c WHERE Id = :recordId';
            SObject fundRecord = Database.query(fundQuery);
            Map<String, Schema.SObjectField> fundFieldsMap = Schema.SObjectType.ProjectProductChild__c.fields.getMap();
     
            for (String field : fundFieldsToCheck) {
                if (fundRecord.get(field) == null || String.valueOf(fundRecord.get(field)).trim() == '') {
                    if (m_StepByField.get(field) == stepName) {
                        emptyFundFields.add(fundFieldsMap.get(field).getDescribe().getLabel());
                    }
                }
            }
     
            if (!emptyFundFields.isEmpty()) {
                Map<String, List<String>> fundMap = new Map<String, List<String>>();
                fundMap.put('Fund', emptyFundFields);
                requiredFieldsEmpty.put('Fund', new List<Map<String, List<String>>>{ fundMap });
            }
        }
     
        // Shareclass - uniquement ProjectShareclass__c
        Set<Id> shareclassIds = getShareclassesId(recordId);
        if (!shareclassIds.isEmpty()) {
            Map<Id, String> scToFieldsToCheck = new Map<Id, String>();
            Map<Id, String> scNames = new Map<Id, String>();
     
            for (ProjectShareclass__c sc : [
                SELECT Id, Name, TECH_FieldsToModify__c, Share_Class_Name__c
                FROM ProjectShareclass__c
                WHERE Id IN :shareclassIds
            ]) {
                scToFieldsToCheck.put(sc.Id, sc.TECH_FieldsToModify__c);
                scNames.put(sc.Id, sc.Share_Class_Name__c);
            }
     
            Map<String, List<String>> aggregatedSCFields = new Map<String, List<String>>();
     
            for (Id scId : scToFieldsToCheck.keySet()) {
                String fieldList = scToFieldsToCheck.get(scId);
                if (String.isEmpty(fieldList)) continue;
     
                List<String> fieldsToCheck = fieldList.split(';');
                if (fieldsToCheck.isEmpty()) continue;
     
                String query = 'SELECT Id, ' + String.join(fieldsToCheck, ',') + ' FROM ProjectShareclass__c WHERE Id = :scId';
                SObject scRecord = Database.query(query);
                Map<String, Schema.SObjectField> scFieldMap = Schema.SObjectType.ProjectShareclass__c.fields.getMap();
     
                List<String> emptyFields = new List<String>();
                for (String field : fieldsToCheck) {
                    if (scRecord.get(field) == null || String.valueOf(scRecord.get(field)).trim() == '') {
                        if (m_StepByField.get(field) == stepName) {
                            emptyFields.add(scFieldMap.get(field).getDescribe().getLabel());
                        }
                    }
                }
     
                if (!emptyFields.isEmpty()) {
                    String scName = scNames.get(scId);
                    aggregatedSCFields.put(scName, emptyFields);
                }
            }
     
            if (!aggregatedSCFields.isEmpty()) {
                List<Map<String, List<String>>> formattedList = new List<Map<String, List<String>>>();
                for (String name : aggregatedSCFields.keySet()) {
                    formattedList.add(new Map<String, List<String>>{ name => aggregatedSCFields.get(name) });
                }
                requiredFieldsEmpty.put('ShareClass', formattedList);
            }
        }
     
        return requiredFieldsEmpty;
    }
    

    public static Map<String, List<Map< String , List <String>>>> checkRequiredFieldsClassic(Id recordId , String teamName , String stepName) {
        List<String> requiredFieldsShareClass = new List<String>();
        List<String> requiredFieldsFund = new List<String>();
        List<String> requiredFieldsEmptyFund = new List<String>();
        
        Map<String, List<Map< String , List <String>>>> requiredFieldsEmpty = new Map<String, List<Map< String , List <String>>>>();
        Boolean allRequiredFielsnotEmpty= true;
        Map<String,Schema.SObjectField> mfieldsFund = Schema.ProjectProductChild__c.SObjectType.getDescribe().fields.getMap();
        Map<String,Schema.SObjectField> mfieldsSC = Schema.ProjectShareclassChild__c.SObjectType.getDescribe().fields.getMap();
        
        ProductProjectSettings__c  matriceRecord= ProjectMatriceUtilities.getmatriceByTeamStep(teamName , stepName);
        if(matriceRecord.RequiredFields__c != null){
            
            requiredFieldsFund= matriceRecord.RequiredFields__c.split(';'); 
        }
        if(matriceRecord.RequiredFieldsShareClass__c != null){
            
            requiredFieldsShareClass= matriceRecord.RequiredFieldsShareClass__c.split(';'); 
        }

        List<ProjectShareclassChild__c> shareclassChildsRT= new List<ProjectShareclassChild__c>();
        Set<Id> shareClassIds= getShareclassesId(recordId);
        List<SObject> shareclassChilds= getRecordWithFields('ProjectShareclassChild__c', shareClassIds, requiredFieldsShareClass);
        List<SObject> fundrecord= getRecordWithFields('ProjectProductChild__c', new Set<Id> {recordId}, requiredFieldsFund);
        ProjectProductChild__c fundRecordConverted= (ProjectProductChild__c) fundrecord[0];

        for(SObject shareclassChild: shareclassChilds){
            ProjectShareclassChild__c shareclassChildConverted = (ProjectShareclassChild__c) shareclassChild;
            if(shareclassChildConverted.RecordType.DeveloperName == fundRecordConverted.RecordType.DeveloperName){
                shareclassChildsRT.add(shareclassChildConverted);
            }
        }

        //Liste d'exclusion de certains champs dispo dans une custom metadata (Dans le cas de ShareclassCreation, cf la fonction)
        Set<String> excludedFields = getExcludedFieldsForValidation(fundRecordConverted.TECH_ProjectRecordType__c);
        for(String requiredfield : requiredFieldsFund) {
            if(excludedFields.contains(requiredfield)){
                //On passe directement au champ suivant (Dans le cas de ShareclassCreation car on ne veut pas que certains champs de ProjectProduct bloque)
                continue;
            }
            if(fundrecord[0].get(requiredfield) == null || fundrecord[0].get(requiredfield) == '' ){
                allRequiredFielsnotEmpty=false;
                Schema.DescribeFieldResult fieldResultF = mfieldsFund.get(requiredfield).getDescribe();
                String labelfieldFund= fieldResultF.getLabel();
                requiredFieldsEmptyFund.add(labelfieldFund);
            }
        }
        Map< String , List <String>> requiredFielsFundMap= new Map< String , List <String>>();
        requiredFielsFundMap.put('FundName', requiredFieldsEmptyFund);
        requiredFieldsEmpty.put('Fund' , new List<Map< String , List <String>>>{requiredFielsFundMap});

        if(requiredFieldsEmptyFund.size()>0) {
            requiredFielsFundMap= new Map< String , List <String>>();
            requiredFielsFundMap.put('FundName', requiredFieldsEmptyFund);
            requiredFieldsEmpty.put('Fund' , new List<Map< String , List <String>>> {requiredFielsFundMap});
        }

        List<Map< String , List <String>>>  requiredFEparSC= new List<Map< String , List <String>>>();
        for(ProjectShareclassChild__c shareclassChild: shareclassChildsRT){
            List<String> requiredFieldsEmptySC = new  List<String>();
            Map< String , List <String>> requiredFielsSCMap = new Map< String , List <String>>();
            for(String requiredfield : requiredFieldsShareClass) {
                if(shareclassChild.get(requiredfield)== null || shareclassChild.get(requiredfield)== '') {
                    Schema.DescribeFieldResult fieldResult = mfieldsSC.get(requiredfield).getDescribe();
                    String labelfieldSC= fieldResult.getLabel();
                    allRequiredFielsnotEmpty=false;
                    if(!requiredFieldsEmptySC.contains(labelfieldSC)){
                        requiredFieldsEmptySC.add(labelfieldSC);
                    }
                }
            }
            requiredFielsSCMap.put(shareclassChild.ProjectShareclasses__r.Share_Class_Name__c , requiredFieldsEmptySC );
            requiredFEparSC.add(requiredFielsSCMap);  
        }
        if(requiredFEparSC.size() > 0){
            requiredFieldsEmpty.put('ShareClass',requiredFEparSC);
        }
        return requiredFieldsEmpty;
    }

public static void lockRecordPPC(List<ProjectProductChild__c> newList, List<ProjectProductChild__c> oldList) {
    Map<Id, ProjectProductChild__c> oldMap = new Map<Id, ProjectProductChild__c>(oldList);
    List<String> PRPUserPermissionSet = getPRPUserPermissionSet();

    for (ProjectProductChild__c newRec : newList) {
        ProjectProductChild__c oldRec = oldMap.get(newRec.Id);
        if (oldRec == null) continue;

        // On vérifie que le champ TECH_TeamValidation__c contient déjà une valeur pour l'équipe en cours
        String validatedTeams = String.valueOf(newRec.get('TECH_TeamValidation__c'));
        if (String.isEmpty(validatedTeams)) continue;

        //On ajoute un bypass pour product strategy si ils modifient la start date / end date du project product child
        if (PRPUserPermissionSet.contains('ProductStrategy') && (newRec.StartDate__c != oldRec.StartDate__c || newRec.EndDate__c != oldRec.EndDate__c)) {
            continue;
        }
          
        for (String field : newRec.getPopulatedFieldsAsMap().keySet()) {
            if (!allowedFields.contains(field) && isChanged(oldRec, newRec, field) && isAlreadyValidated(validatedTeams, PRPUserPermissionSet, newRec)) {
              
                System.debug('[LAUNCHING ERROR]: You have validated this phase Fund triggered');
                newRec.addError(
                    'You have validated this phase. You can no longer edit or contribute to this phase.\n' +
                    'If you need to make changes, please contact the project owner to request a rollback to draft status.'
                );
                // On arrête dès qu’un champ interdit est modifié
                break; 
            }
        }
    }
}

private static Boolean isAlreadyValidated(String validatedTeams, List<String> PRPUserPermissionSet, ProjectProductChild__c projectProductchild) {
    System.debug('validatedTeams:' + validatedTeams);
    System.debug('PRPUserPermissionSet:' + PRPUserPermissionSet);
    if (PRPUserPermissionSet.isEmpty()) {
        return true;
    }
    if (PRPUserPermissionSet.contains('ProductStrategy') && projectProductchild.Parent_Record_Type_Id__c == fundModificationRecordTypeId) {
        return false;
    }
    List<String> l_validatedTeams = validatedTeams.split(';');
    if (l_validatedTeams.size() > 0) {
        for (String team : l_validatedTeams) {
            if (PRPUserPermissionSet.contains(team)) {
                return true;
            }
        }
    }
    return false;
}

private static final Set<String> allowedFields = new Set<String>{
    'TECH_TeamValidation__c',
    'Status__c',
    'CompletionRateStep__c',
    'NbofFilledFields__c',
    'fundNbOfFields__c',
    'RAG__c'
};

public static Boolean isChanged(SObject oldRecord, SObject newRecord, String fieldName) {
    return String.valueOf(oldRecord.get(fieldName)) != String.valueOf(newRecord.get(fieldName));
}

public static void lockRecordShareClassChild(ProjectShareclassChild__c newProjectShareclassChild , ProjectShareclassChild__c oldProjectShareclassChild){
    List<String> requiredFieldsFund   =new  List<String>();
    Map<String , String> permissionSetToTeamMap = new Map<String, String>{
        'PRPProductStrategy' => 'Product Strategy',
        'PRPLegal' => 'Legal',
        'PRPTax' => 'Tax',
        'PRPOPS' => 'OPS',
        'PRPRisk' => 'Risk',
        'PRPESG' => 'ESG',
        'PRPCompliance' => 'Compliance',
        'PRPDCO' => 'DCO',
        'PRPDCR' => 'DCR',
        'PRPInvestmentPerf' => 'Investment Perf',
        'PRPFinance' => 'Finance',
        'PRPCommunication' => 'Communication',
        'PRPTechnology' => 'Technology',
        'PRPIS' => 'IS'
    };
    List<PermissionSetAssignment> l_permissionSetAss= [SELECT PermissionSet.Name FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() and PermissionSet.Name like '%PRP%' ];
    String teamName;
    String psName;
 for(PermissionSetAssignment permissionSetAss:l_permissionSetAss ){
    if(permissionSetToTeamMap.containsKey(permissionSetAss.PermissionSet.Name)){
        teamName= permissionSetToTeamMap.get(permissionSetAss.PermissionSet.Name);
        psName= permissionSetAss.PermissionSet.Name.substring(3);
    }}
 List<ProjectChildJunction__c> projectChildJunctions =
        [SELECT Id,ProjectProductChild__c  , ProjectShareclass__c  , ProjectProductChild__r.RecordType.DeveloperName ,ProjectProductChild__r.TECH_ProjectRecordType__c
            ,ProjectProductChild__r.TECH_TeamValidation__c FROM ProjectChildJunction__c 
            WHERE ProjectShareclass__c = :oldProjectShareclassChild.ProjectShareclasses__c];
    String  recordtypeSCChild= [SELECT Id, DeveloperName from RecordType WHERE Id= :newProjectShareclassChild.RecordTypeId ].DeveloperName;
    for (ProjectChildJunction__c projectChildJunction:projectChildJunctions){
            if(projectChildJunction.ProjectProductChild__r.RecordType.DeveloperName == recordtypeSCChild){
                if(psName =='ProductStrategy' && projectChildJunction.ProjectProductChild__r.TECH_ProjectRecordType__c == 'FundShareClassModification'){
                    continue;
                }
                String teamValidation =(String) projectChildJunction.ProjectProductChild__r.TECH_TeamValidation__c;
                if(teamValidation!= null && teamValidation.contains(psName)){
                    System.debug(teamValidation);
                    if(newProjectShareclassChild!= oldProjectShareclassChild){
                        System.debug('[LAUNCHING ERROR]: You have validated this phase Shareclass triggered');
                        newProjectShareclassChild.addError('You have validated this phase. You can no longer edit or contribute to this phase. If you need to make changes, please contact the project owner to request a rollback to draft status.');
                    }  
                }}}
 }


    public static Map<String, String> getPermissionSetToTeamMap(){
        Map<String, String> permissionSetToTeamMap = new Map<String, String>{
        'PRPProductStrategy' => 'ProductStrategy',
        'PRPLegal' => 'Legal',
        'PRPTax' => 'Tax',
        'PRPOPS' => 'OPS',
        'PRPRisk' => 'Risk',
        'PRPESG' => 'ESG',
        'PRPCompliance' => 'Compliance',
        'PRPDCO' => 'DCO',
        'PRPDCR' => 'DCR',
        'PRPInvestmentPerf' => 'InvestmentPerf',
        'PRPFinance' => 'Finance',
        'PRPCommunication' => 'Communication',
        'PRPTechnology' => 'Technology',
        'PRPIS' => 'IS'
        };
        return permissionSetToTeamMap;
    }

    public static List<String> getPRPUserPermissionSet(){
        Map<String, String> m_permissionSetToTeamMap = getPermissionSetToTeamMap();
        List<String> permissionSetUserListTransformed = new List<String>();
        List<PermissionSetAssignment> l_psa = [SELECT PermissionSet.Name FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSet.Name LIKE 'PRP%' ];
        for (PermissionSetAssignment psa : l_psa) {
            if (m_permissionSetToTeamMap.containsKey(psa.PermissionSet.Name)) {
                permissionSetUserListTransformed.add(m_permissionSetToTeamMap.get(psa.PermissionSet.Name));
            }
        }

        if (!permissionSetUserListTransformed.isEmpty()) {
            System.debug('permissionSetUserListTransformed: ' + permissionSetUserListTransformed);
            return permissionSetUserListTransformed;
        }
        return null;
    }
}