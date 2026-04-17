public without sharing class FieldHistoryLogger {
    public static void log(List<SObject> newList, Map<Id, SObject> oldMap, String objectApiName) {
        if (newList == null || newList.isEmpty()) return;
        
        // Récupération des champs à tracker depuis le Custom Metadata
        Field_History_Config__mdt config = [
            SELECT Tracked_Fields__c 
            FROM Field_History_Config__mdt 
            WHERE Object_API_Name__c = :objectApiName
            LIMIT 1
        ];
        String source=  UserInfo.getUserName().contains('infrastructure.technology@carmignac.com') ? 'PMT' : 'Product Catalog';
        if (config == null || String.isBlank(config.Tracked_Fields__c)) return;
        
        Set<String> trackedFields = new Set<String>(config.Tracked_Fields__c.split(';'));
        List<Fund_Field_ApplicabilityHistory__c> logsToInsert = new List<Fund_Field_ApplicabilityHistory__c>();
        List<Fund_Field_ApplicabilityHistory__c> logsToUpdate = new List<Fund_Field_ApplicabilityHistory__c>();
        Map<String, Schema.SObjectField> fieldMap = newList[0].getSObjectType().getDescribe().fields.getMap();

        Set<Id> recordIds = new Set<Id>();
        for (SObject newObj : newList) {
            recordIds.add(newObj.Id);
        }
        system.debug('recordIds '+recordIds);
        String lookupField = getLookupFieldName(objectApiName);
        
        String query = 'SELECT Id, FieldAPIName__c, End_Date__c, ' + lookupField +
        ' FROM Fund_Field_ApplicabilityHistory__c ' +
        'WHERE Applicability__c = true ' +
        'AND End_Date__c = NULL ' +
        'AND ' + lookupField + ' IN :recordIds';
        system.debug('query : '+query);
        List<Fund_Field_ApplicabilityHistory__c> existingLogs = Database.query(query);
        system.debug('existingLogs : '+existingLogs);
        Map<String, Fund_Field_ApplicabilityHistory__c> activeLogsMap = new Map<String, Fund_Field_ApplicabilityHistory__c>();
        for (Fund_Field_ApplicabilityHistory__c log : existingLogs) {
            Id refId;
            if (objectApiName == 'Product__c') refId = log.Product_Reference__c;
            if (objectApiName == 'Share_Class__c') refId = log.Share_Class_Reference__c;
            // Ajoute les autres cas 
            String key = refId + ':' + log.FieldAPIName__c;
            activeLogsMap.put(key, log);
        }
        system.debug('activeLogsMap : '+activeLogsMap);
        for (SObject newObj : newList) {
            Id recordId = newObj.Id;
            SObject oldObj = oldMap != null ? oldMap.get(recordId) : null;
            
            for (String field : trackedFields) {
                if (!fieldMap.containsKey(field)) continue;
                system.debug('field : '+field);
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(field).getDescribe();
                String fieldLabel = fieldDescribe.getLabel();                
                Object oldVal = oldObj != null ? oldObj.get(field) : null;
                Object newVal = newObj.get(field);
                
                Boolean changed;
                if (oldObj == null) {
                    // Cas d'un nouvel enregistrement : log de tous les champs non vides
                    changed = (newVal != null);
                } else {
                    // Cas d'un update
                    changed = (oldVal != newVal && (oldVal == null || !oldVal.equals(newVal)));
                }
				system.debug('changed : '+changed);                
                if (changed) {
                    
                    // Fermer l'ancien log actif
                    //Fund_Field_ApplicabilityHistory__c oldLog = findActiveLog(recordId, objectApiName, field);
                    String logKey = recordId + ':' + field;
                    Fund_Field_ApplicabilityHistory__c oldLog = activeLogsMap.get(logKey);
                    if (oldLog != null) {
                        oldLog.End_Date__c = System.Today().addDays(-1);
                        logsToUpdate.add(oldLog);
                    }
                    
                    // Nouveau log
                    Fund_Field_ApplicabilityHistory__c newLog = new Fund_Field_ApplicabilityHistory__c();
                    if(objectApiName == 'Product__c'){
                        newLog.Product_Reference__c= String.valueOf(RecordId);  
                    }
                    if(objectApiName == 'Share_Class__c'){
                        newLog.Share_Class_Reference__c= String.valueOf(RecordId);  
                    }
                    /* if(objectApiName == 'ProjectProduct__c'){
newLog.Project_Reference__c= String.valueOf(RecordId);  
}

if(objectApiName == 'FundManager__c'){
newLog.FundManager_Reference__c= String.valueOf(RecordId);  
}
if(objectApiName == 'Benchmark__c'){
newLog.Benchmark_Reference__c= String.valueOf(RecordId);  
}*/
                    
                    
                    newLog.Old_Value__c = String.valueOf(oldVal);
                    newLog.New_Value__c = String.valueOf(newVal);
                    newLog.Field_Name__c = fieldLabel;
                    newLog.FieldAPIName__c = field;
                    newLog.Start_Date__c = System.Today();
                    newLog.Applicability__c= true;
                    newLog.Source__c = source;  
                    newLog.User__c = UserInfo.getUserId();
                    logsToInsert.add(newLog);
                }
            }
        }
        
        if (!logsToUpdate.isEmpty()) update logsToUpdate;
        if (!logsToInsert.isEmpty()) insert logsToInsert;
    }
    
    public static void logAllFields(List<SObject> newList, Map<Id, SObject> oldMap, String objectApiName) {
        /*Set<String> systemFields = new Set<String>{
        'CreatedDate', 'CreatedById', 'lastmodifieddate', 'LastModifiedById', 'systemmodstamp'
        };*/
        Field_History_Config__mdt config = [
            SELECT Tracked_Fields__c, ExcludedFields__c  
            FROM Field_History_Config__mdt 
            WHERE Object_API_Name__c = :objectApiName
            LIMIT 1
        ];
        String source=  UserInfo.getUserName().contains('infrastructure.technology@carmignac.com') ? 'PMT' : 'Product Catalog';
        if (config == null || String.isBlank(config.Tracked_Fields__c)) return;
        
        Set<String> systemFields = config.Tracked_Fields__c != null ? new Set<String>(config.Tracked_Fields__c.split(';')) : Null;
        Set<String> excludedFieldsMDT = config.ExcludedFields__c != null ? new Set<String>(config.ExcludedFields__c.split(';')): Null;
        Set<String> systemFields2 = new Set<String>{
            'CreatedDate', 'CreatedById', 'lastmodifieddate', 'LastModifiedById', 'systemmodstamp'
                };
        
                if(excludedFieldsMDT != null){
                    systemFields.addAll(excludedFieldsMDT);
                }
                systemFields.addAll(systemFields2);
                
        Set<String> excludedFields = new Set<String>();
        for(String f : systemFields){
            if(!String.isBlank(f)){
                excludedFields.add(f.trim().toLowerCase());
            }
        }
        if (newList == null || newList.isEmpty()) return;
        Map<String, Schema.SObjectField> allFields = newList[0].getSObjectType().getDescribe().fields.getMap();
        
        Set<String> trackedFields = new Set<String>();
        Map<String,String> trackedFieldsMap = new Map<String,String>();
        for (String fieldName : allFields.keySet()) {
            if ( !excludedFields.contains(fieldName) &&  !fieldName.endsWith('__r') && fieldName != 'Id') {
                Schema.SObjectField field = allFields.get(fieldName);
                Schema.DescribeFieldResult F = field.getDescribe();
               
                trackedFields.add(fieldName);
                trackedFieldsMap.put(fieldName,F.getLabel());
            }
        }
        
        List<Fund_Field_ApplicabilityHistory__c> logsToInsert = new List<Fund_Field_ApplicabilityHistory__c>();
        //List<Fund_Field_ApplicabilityHistory__c> logsToUpdate = new List<Fund_Field_ApplicabilityHistory__c>();
        
        for (SObject newObj : newList) {
            Id recordId = newObj.Id;
            SObject oldObj = oldMap.get(recordId);
            
            for (String field : trackedFields) {
                Object oldVal = oldObj != null ? oldObj.get(field) : null;
                Object newVal = newObj.get(field);

                if (oldVal != newVal && (oldVal == null || !oldVal.equals(newVal))) {
                   
                    /* Fund_Field_ApplicabilityHistory__c existing = findActiveLog(recordId, objectApiName, field);
                    if (existing != null) {
                    existing.End_Date__c = System.Today();
                    logsToUpdate.add(existing);
                    }*/
                    
                    
                    Fund_Field_ApplicabilityHistory__c log = new Fund_Field_ApplicabilityHistory__c();
                    if(objectApiName == 'Product__c'){
                        log.Product_Reference__c= String.valueOf(RecordId);  
                    }
                    if(objectApiName == 'Share_Class__c'){
                        log.Share_Class_Reference__c= String.valueOf(RecordId);  
                    }   
                    /* if(objectApiName == 'ProjectProduct__c'){
                    log.Project_Reference__c= String.valueOf(RecordId);  
                    }
                    if(objectApiName == 'Share_Class__c '){
                    log.Share_Class_Reference__c= String.valueOf(RecordId);  
                    }
                    if(objectApiName == 'FundManager__c'){
                    log.FundManager_Reference__c= String.valueOf(RecordId);  
                    }
                    if(objectApiName == 'Benchmark__c'){
                    log.Benchmark_Reference__c= String.valueOf(RecordId);  
                    }*/
                    log.Field_Name__c = trackedFieldsMap.get(field);
                    log.FieldAPIName__c = field;
                    log.Old_Value__c = String.valueOf(oldVal);
                    log.New_Value__c = String.valueOf(newVal);
                    log.Date__c = DateTime.now();
                    log.User__c = UserInfo.getUserId();
                    log.Source__c = source;
                    logsToInsert.add(log);
                }
            }
        }
        
        
        if (!logsToInsert.isEmpty()) insert logsToInsert;
    }
    
    
    // Méthode pour récupérer le dernier log actif
    /* private static Fund_Field_ApplicabilityHistory__c findActiveLog(Id recordId, String objectApiName, String field) {
    List<Fund_Field_ApplicabilityHistory__c> existing = [
    SELECT Id, End_Date__c
    FROM Fund_Field_ApplicabilityHistory__c
    WHERE Project_Reference__c = :recordId
    AND Field_Name__c = :field
    AND End_Date__c = NULL
    LIMIT 1
    ];
    return existing.isEmpty() ? null : existing[0];
    }*/


    private static String getLookupFieldName(String objectApiName) {
        if (objectApiName == 'Product__c') return 'Product_Reference__c';
         //if (objectApiName == 'ProjectProduct__c') return 'Project_Reference__c';
        if (objectApiName == 'Share_Class__c') return 'Share_Class_Reference__c';
        /*if (objectApiName == 'FundManager__c') return 'FundManager_Reference__c';
        if (objectApiName == 'Benchmark__c ') return 'Benchmark_Reference__c';*/
        // Ajoute les autres objets ici
        return null;
    }

    public static void logPhaseValidation(List<ProjectProductChild__c> newList, Map<Id, ProjectProductChild__c> oldMap) {
        List<Fund_Field_ApplicabilityHistory__c> logsToInsert = new List<Fund_Field_ApplicabilityHistory__c>();
    
        for (ProjectProductChild__c newRecord : newList) {
            ProjectProductChild__c oldRecord = oldMap.get(newRecord.Id);
    
            Set<String> oldTeams = getSplitValues(oldRecord.TECH_TeamValidation__c);
            Set<String> newTeams = getSplitValues(newRecord.TECH_TeamValidation__c);
    
            newTeams.removeAll(oldTeams); // Keep only newly added teams
    
            if (!newTeams.isEmpty()) {
                Fund_Field_ApplicabilityHistory__c newLogs = new Fund_Field_ApplicabilityHistory__c(
                                                                    Project_Reference__c = String.valueOf(newRecord.ProjectProductParent__c),
                                                                    Field_Name__c = 'Phase validation - ' + newRecord.Name,
                                                                    FieldAPIName__c = 'TECH_TeamValidation__c',
                                                                    Comment__c = 'Validated team: ' + String.join(newTeams, ', '),
                                                                    Date__c = DateTime.now(),
                                                                    User__c = UserInfo.getUserId(),
                                                                    Source__c = 'Product Catalog'
                );
                logsToInsert.add(newLogs);
            }
        }
    
        if (!logsToInsert.isEmpty()) {
            insert logsToInsert;
        }
    }
 
    private static Set<String> getSplitValues(String semiColonList) {
        Set<String> result = new Set<String>();
        if (String.isNotBlank(semiColonList)) {
            result.addAll(semiColonList.split(';'));
        }
        return result;
    }
}