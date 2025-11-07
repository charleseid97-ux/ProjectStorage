/**

**/
public without sharing class FieldModificationController {
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getFieldsToModify(String recordId, String objectApiName) {
        List<Map<String, String>> fieldList = new List<Map<String, String>>();
        Map<String, String> teamOwners = new Map<String, String>();
        Map<String, String> phases = new Map<String, String>();
        String fieldString ='';
        Map<String, ProjectChildJunction__c> shareClassToFields = new Map<String, ProjectChildJunction__c>();
        Map<String, List<ProjectChildJunction__c>> shareClassToJunctions = new Map<String, List<ProjectChildJunction__c>>();
        String outputString;
        Product__c productFromRef;
        Map<Id,Share_Class__c> shareClassesFromRef = new Map<Id,Share_Class__c>();
        Map<String, String> shareClassIds = new Map<String, String>();

        String parent ='ProjectProductParent__c';
        if(objectApiName == 'Product__c'){
            ProjectProduct__c pp = [SELECT TECH_FieldsToModify__c,Product__c FROM ProjectProduct__c WHERE id =:recordId LIMIT 1];
            fieldString = pp.TECH_FieldsToModify__c;
            outputString = String.join(fieldString.split(';'), ',');
            String query = 'SELECT Id, ' + outputString + ' FROM Product__c WHERE Id =\''+pp.Product__c+'\'' ;
            productFromRef = Database.query(query);
        }else {
            Set<String> shIds = new Set<String>();        
            for(ProjectChildJunction__c junc : [SELECT Id, ProjectShareclass__c, 
                                                    ProjectShareclass__r.name, 
                                                    ProjectShareclass__r.Share_Class_Name__c, 
                                                    ProjectShareclass__r.TECH_FieldsToModify__c,
                                                    ProjectShareclass__r.Tech_ShareClass__c,
                                                    ProjectProductChild__r.TECH_TeamValidation__c,
                                                    ProjectProductChild__r.Name
                                                    FROM ProjectChildJunction__c 
                                                    WHERE ProjectProductChild__r.ProjectProductParent__c =:recordId]){
                fieldString +=  junc.ProjectShareclass__r.TECH_FieldsToModify__c + ';' ;
                shIds.add(junc.ProjectShareclass__r.Tech_ShareClass__c );
                shareClassIds.put(junc.ProjectShareclass__c,junc.ProjectShareclass__r.Tech_ShareClass__c );
                shareClassToFields.put(junc.ProjectShareclass__c, junc);
                if(shareClassToJunctions.containsKey(junc.ProjectShareclass__c) )
                {
                    shareClassToJunctions.get(junc.ProjectShareclass__c).add(junc);
                }else{
                    shareClassToJunctions.put(junc.ProjectShareclass__c, new List<ProjectChildJunction__c>{junc});
                }
                
            }
            List<String> filteredFields = new List<String>();
            for(String f : fieldString.split(';')){
                if(f != null && f != 'null' && !filteredFields.contains(f)){
                    filteredFields.add(f);
                }
            }
            fieldString = String.join(filteredFields, ';');
            outputString = String.join(filteredFields, ',');
            String query = null;
            if (outputString.contains('ISIN__c')) {
                   query = 'SELECT Id, ' + outputString + ' FROM Share_Class__c WHERE Id IN :shIds';
            } else {
                   query = 'SELECT Id, ISIN__c, ' + outputString + ' FROM Share_Class__c WHERE Id IN :shIds';
            }
         
            for(Share_Class__c sc :  Database.query(query)){
                shareClassesFromRef.put(sc.Id, sc);
            }
        }

        String childObjectName = 'ProjectProductChild__c ';
        List<ProductProjectSettings__c> matriceRecords = [SELECT Id ,Name,  ProjectType__c,Stage__c, Order__c , Team__c  ,OrderTeam__c , RequiredFields__c , RequiredFieldsShareClass__c , NonRequiredFieldsFund__c , NonRequiredFieldsShareClass__c  FROM ProductProjectSettings__c ORDER BY Order__c,OrderTeam__c   ASC];
        for (ProductProjectSettings__c matrixElt : matriceRecords) {
            system.debug(matrixElt.Team__c);
            if(matrixElt.RequiredFields__c != null){
                
                for(String field : matrixElt.RequiredFields__c?.split(';')) {
                    teamOwners.put(field, matrixElt.Team__c);
                    phases.put(field, matrixElt.Stage__c);
                }
            }
            if(matrixElt.NonRequiredFieldsFund__c != null){
                for(String field : matrixElt.NonRequiredFieldsFund__c?.split(';')) {
                    teamOwners.put(field, matrixElt.Team__c);
                    phases.put(field, matrixElt.Stage__c);
                }
            }
            if(matrixElt.RequiredFieldsShareClass__c != null){
                for(String field : matrixElt.RequiredFieldsShareClass__c?.split(';')) {
                    teamOwners.put(field, matrixElt.Team__c);
                    phases.put(field, matrixElt.Stage__c);
                }     
            }       
            if(matrixElt.NonRequiredFieldsShareClass__c != null){
                for(String field : matrixElt.NonRequiredFieldsShareClass__c?.split(';')) {
                    teamOwners.put(field, matrixElt.Team__c);
                    phases.put(field, matrixElt.Stage__c);
                }
            }
        }
        
        String query = 'SELECT Id,TECH_Childtype__c,TECH_TeamValidation__c, ' + outputString + ' FROM  '+childObjectName+'  WHERE '+parent+' =\''+recordId+'\'' ;
        Map<String, String> stageToChildRecord = new Map<String, String>();
        Map<String, String> stageStatus = new Map<String, String>();
        Map<String, Map<String,String>> childtoStageRecord = new Map<String, Map<String,String>>();
        Map<String, Map<String,String>>  fieldNewValue = new Map<String, Map<String,String>>() ;
        Map<String, Map<String,String>>  fieldOldValue = new Map<String, Map<String,String>>() ;

        if(objectApiName == 'Share_Class__c'){
            parent = 'ProjectShareclasses__c' ;
            childObjectName = 'ProjectShareclassChild__c' ;
            query = 'SELECT Id,ProjectShareclasses__c,TECH_Childtype__c, ' + outputString +' From ProjectShareclassChild__c where ProjectShareclasses__c  in (SELECT ProjectShareclass__c FROM  ProjectChildJunction__c where ProjectProductChild__r.ProjectProductParent__c =\''+recordId+'\')';
        }

        List<ProjectChildJunction__c> projChildJunctions = [SELECT ProjectProductChild__c,ProjectProductChild__r.TECH_TeamValidation__c,ProjectProductChild__r.TECH_Childtype__c,
                                                    ProjectShareclass__c,ProjectProductChild__r.name 
                                            FROM ProjectChildJunction__c
                                            WHERE ProjectProductChild__r.ProjectProductParent__c =: recordId];
   
        for(Sobject child : Database.query(query)) {

            if(child.get('TECH_Childtype__c') != null){
                Map<String,String> fieldValueO = new Map<String,String>();
                Map<String,String> fieldValueN = new Map<String,String>();
                for (String field : fieldString.split(';')) {
                    Object newValue = child.get(field);
                    if(objectApiName != 'Share_Class__c'){
                        stageStatus.put((String)child.get('Id'), (String)child.get('TECH_TeamValidation__c'));
                        Object oldValue = productFromRef.get(field);
                        fieldValueO.put(field, String.valueOf(oldValue));
                    }else{
                        
                        Object oldValue = shareClassesFromRef.get(shareClassIds.get((String)child.get('ProjectShareclasses__c'))).get(field);
                        fieldValueO.put(field, String.valueOf(oldValue));
                    }
                    fieldValueN.put(field, String.valueOf(newValue));
                }
                fieldNewValue.put((String)child.get('Id'), fieldValueN);
                fieldOldValue.put((String)child.get('Id'), fieldValueO);
                
                
                

                if((String)child.get('TECH_Childtype__c') =='DesignAndProposal'){
                    
                    stageToChildRecord.put('Proposal', (String)child.get('Id'));
                    if(objectApiName == 'Share_Class__c'){
                        List<ProjectChildJunction__c> junctions = shareClassToJunctions.get((String)child.get('ProjectShareclasses__c')); 
                        for(ProjectChildJunction__c junction : junctions ){
                            if(junction.ProjectProductChild__r.Name == 'Proposal'){
                                stageStatus.put((String)child.get('Id'), junction.ProjectProductChild__r.TECH_TeamValidation__c);
                                break;
                            } 
                        }
                        childtoStageRecord.put((String)child.get('ProjectShareclasses__c'),childtoStageRecord.get((String)child.get('ProjectShareclasses__c')) != null ? childtoStageRecord.get((String)child.get('ProjectShareclasses__c')) : new Map<String,String>());
                        childtoStageRecord.get((String)child.get('ProjectShareclasses__c')).put('Proposal', (String)child.get('Id'));
                    }
                } else{
                    stageToChildRecord.put((String)child.get('TECH_Childtype__c'), (String)child.get('Id'));
                    if(objectApiName == 'Share_Class__c'){
                        List<ProjectChildJunction__c> junctions = shareClassToJunctions.get((String)child.get('ProjectShareclasses__c')); 
                        for(ProjectChildJunction__c junction : junctions ){
                            if(junction.ProjectProductChild__r.Name == (String)child.get('TECH_Childtype__c')){
                                stageStatus.put((String)child.get('Id'), junction.ProjectProductChild__r.TECH_TeamValidation__c);
                                break;
                            } 
                        }
                        childtoStageRecord.put((String)child.get('ProjectShareclasses__c'),childtoStageRecord.get((String)child.get('ProjectShareclasses__c')) != null ? childtoStageRecord.get((String)child.get('ProjectShareclasses__c')) : new Map<String,String>());
                        childtoStageRecord.get((String)child.get('ProjectShareclasses__c')).put((String)child.get('TECH_Childtype__c'), (String)child.get('Id'));
                    }
                }
            }
        }
        if(objectApiName == 'Share_Class__c'){
            for(Id shareClass : shareClassToFields.keySet()){
                ProjectChildJunction__c record = shareClassToFields.get(shareClass);
                if(String.isNotBlank(record.ProjectShareclass__r.TECH_FieldsToModify__c)){
                    for (String field : record.ProjectShareclass__r.TECH_FieldsToModify__c.split(';')) {
                        system.debug('>>>>>>>>>>>>>>>>>>>>>>>>>>field : '+field);
                        Map<String, String> fieldData = new Map<String, String>();
                        fieldData.put('shareclass', record.ProjectShareclass__r.Share_Class_Name__c);
                        String shareClassId = shareClassIds.get(record.ProjectShareclass__c);
                        if (shareClassesFromRef.containsKey(shareClassId)) {
                            fieldData.put('isin', shareClassesFromRef.get(shareClassId).ISIN__c);
                        }
                        fieldData.put('fieldName', field);
                        fieldData.put('teamOwner', teamOwners.get(field) != null ? teamOwners.get(field) : 'Unknown');
                        fieldData.put('phase', phases.get(field) != null ? phases.get(field) : 'Unknown');
                        fieldData.put('childRecordId', childtoStageRecord.get(record.ProjectShareclass__c).get(phases.get(field)) != null ? childtoStageRecord.get(record.ProjectShareclass__c).get(phases.get(field)) : '');
                        fieldData.put('newValue', fieldNewValue.get(childtoStageRecord.get(record.ProjectShareclass__c).get(phases.get(field))).get(field) != null ? fieldNewValue.get(childtoStageRecord.get(record.ProjectShareclass__c).get(phases.get(field))).get(field) : '');
                        fieldData.put('previousValue', fieldOldValue.get(childtoStageRecord.get(record.ProjectShareclass__c).get(phases.get(field))).get(field) != null ? fieldOldValue.get(childtoStageRecord.get(record.ProjectShareclass__c).get(phases.get(field))).get(field) : '');
                        fieldData.put('statusValue', stageStatus.get(childtoStageRecord.get(record.ProjectShareclass__c).get(phases.get(field))) !=null && stageStatus.get(childtoStageRecord.get(record.ProjectShareclass__c).get(phases.get(field))).contains(teamOwners.get(field)?.replaceAll(' ', '')) ? 'Valid' : 'Invalid' );
                        fieldList.add(fieldData);

                    }
                }
            }
        } else {
            
            List<String> fieldNames = fieldString.split(';');
            for (String field : fieldNames) {
                system.debug('>>>>>>>>>>>>>>>>>>>>>>>>>>teamOwners.get(field) : '+teamOwners.get(field));
                system.debug('>>>>>>>>>>>>>>>>>>>>>>>>>>stageStatus.get(stageToChildRecord.get(phases.get(field))) : '+stageStatus.get(stageToChildRecord.get(phases.get(field))));
                Map<String, String> fieldData = new Map<String, String>();
                fieldData.put('fieldName', field);
                fieldData.put('teamOwner', teamOwners.get(field) != null ? teamOwners.get(field) : 'Unknown');
                fieldData.put('phase', phases.get(field) != null ? phases.get(field) : 'Unknown');
                fieldData.put('childRecordId', stageToChildRecord.get(phases.get(field)) != null ? stageToChildRecord.get(phases.get(field)) : '');
                fieldData.put('newValue', fieldNewValue.get(stageToChildRecord.get(phases.get(field))).get(field) != null ? fieldNewValue.get(stageToChildRecord.get(phases.get(field))).get(field) : '');
                fieldData.put('previousValue', fieldOldValue.get(stageToChildRecord.get(phases.get(field))).get(field) != null ? fieldOldValue.get(stageToChildRecord.get(phases.get(field))).get(field) : '');
                fieldData.put('statusValue', stageStatus.get(stageToChildRecord.get(phases.get(field))) !=null && stageStatus.get(stageToChildRecord.get(phases.get(field))).contains(teamOwners.get(field)?.replaceAll(' ', '')) ? 'Valid' : 'Invalid' );
                fieldList.add(fieldData);
            }
        }
        system.debug('>>>>>>>>>>>>>>>>>>>>>>>>>>fieldList: '+fieldList);

        return fieldList;
    }


    @AuraEnabled
    public static void updateFieldValue(String sObjectName, String recordId, String fieldApiName, Object fieldValue) {
        SObject record = (SObject) Type.forName('Schema.' + sObjectName).newInstance();
        record.put('Id', recordId);
        record.put(fieldApiName, fieldValue);

        update record;
    }


    /*@AuraEnabled
    public static void updateFieldValue(String objectApiName, Id recordId, String fieldApiName, String newValue) {
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) {
            throw new AuraHandledException('Missing object or field API name.');
        }

        // Construire la requête SOQL dynamique
        String query = 'SELECT Id, ' + fieldApiName + ' FROM ' + objectApiName + ' WHERE Id = :recordId LIMIT 1';
        SObject recordToUpdate = Database.query(query);

        // Modifier la valeur du champ
        recordToUpdate.put(fieldApiName, newValue);

        // Mettre à jour l’enregistrement
        update recordToUpdate;
    }*/

@AuraEnabled
    public static void updateFieldVal(String objectApiName, Id recordId, String fieldApiName, String newValue) {
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) {
        throw new AuraHandledException('Missing object or field API name.');
    }

    // Obtenir le type du champ
    Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
    if (sObjType == null) throw new AuraHandledException('Invalid object API name.');

    Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();
    if (!fieldMap.containsKey(fieldApiName)) throw new AuraHandledException('Invalid field API name.');

    Schema.DisplayType fieldType = fieldMap.get(fieldApiName).getDescribe().getType();

    // Convertir newValue selon le type
    Object parsedValue;
    switch on fieldType {
        when BOOLEAN {
            parsedValue = (newValue == 'true');
        }
        when DOUBLE {
            parsedValue = Double.valueOf(newValue);
        }
        when INTEGER {
            parsedValue = Integer.valueOf(newValue);
        }
        when CURRENCY {
            parsedValue = Decimal.valueOf(newValue);
        }
        when DATE {
            parsedValue = Date.valueOf(newValue);
        }
        when DATETIME {
            parsedValue = Datetime.valueOf(newValue);
        }
        when PERCENT {
            parsedValue = Double.valueOf(newValue);
        }
        when else {
            parsedValue = newValue;
        }
    }

    // Requête et mise à jour
    String query = 'SELECT Id, ' + fieldApiName + ' FROM ' + objectApiName + ' WHERE Id = :recordId LIMIT 1';
    SObject recordToUpdate = Database.query(query);
    recordToUpdate.put(fieldApiName, parsedValue);
    update recordToUpdate;
}

    public class FieldUpdate {
        public String recordId;
        public String objectApiName;
        public String fieldApiName;
        public String newValue;
    }
    
    @AuraEnabled
public static void updateMultipleFields(List<FieldUpdate> updates) {
    Map<String, Map<Id, SObject>> groupedByObject = new Map<String, Map<Id, SObject>>();
    system.debug('here 1');
    system.debug('updates : '+ JSON.serialize(updates));
    for (FieldUpdate fieldUpdate : updates) {
        if (String.isBlank(fieldUpdate.recordId) ||
            String.isBlank(fieldUpdate.objectApiName) ||
            String.isBlank(fieldUpdate.fieldApiName)) {
                system.debug('here empty'+fieldUpdate.recordId);
                system.debug('here empty'+fieldUpdate.objectApiName);
                system.debug('here empty'+fieldUpdate.fieldApiName);
                system.debug('here empty');
            continue;
        }
        system.debug('here 2');
        if (!groupedByObject.containsKey(fieldUpdate.objectApiName)) {
            groupedByObject.put(fieldUpdate.objectApiName, new Map<Id, SObject>());
        }

        Map<Id, SObject> recordMap = groupedByObject.get(fieldUpdate.objectApiName);

        if (!recordMap.containsKey(fieldUpdate.recordId)) {
            SObject newRecord = (SObject) Type.forName('Schema.' + fieldUpdate.objectApiName).newInstance();
            newRecord.put('Id', fieldUpdate.recordId);
            recordMap.put(fieldUpdate.recordId, newRecord);
        }

        recordMap.get(fieldUpdate.recordId).put(fieldUpdate.fieldApiName, fieldUpdate.newValue);
    }

    List<SObject> allToUpdate = new List<SObject>();
    for (Map<Id, SObject> recordMap : groupedByObject.values()) {
        allToUpdate.addAll(recordMap.values());
    }

    if (!allToUpdate.isEmpty()) {
        system.debug('here 3');
        update allToUpdate;
    }
}

}