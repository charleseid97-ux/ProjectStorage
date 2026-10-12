/** ──────────────────────────────────────
 * @description Apex controller for the fieldsModificationList LWC (FundShareclassModification projects).
 *              Lists the fields selected for modification (TECH_FieldsToModify__c) on the Product or its Share Classes,
 *                  with their owning team and stage from the PMT matrix, the current referential value and the new
 *                  value, and updates field values.
 *              The matrix is restricted to the project's Scope (PMTMatrix.forScope, FIX-20178, blank = PS).
 * @lastModifiedBy Charles EID   [09-10-26]
 * @testClass Test_FieldModificationController
 * @coverage 100%   [09-10-26]
 ────────────────────────────────────── */
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
            ProjectProduct__c pp = [SELECT TECH_FieldsToModify__c, Product__c FROM ProjectProduct__c WHERE Id = :recordId LIMIT 1];

            fieldString = pp.TECH_FieldsToModify__c;
            outputString = String.join(fieldString.split(';'), ',');
            String query = 'SELECT Id, ' + outputString + ' FROM Product__c WHERE Id =\''+pp.Product__c+'\'' ;
            productFromRef = Database.query(query);
        }
        else {
            Set<String> shIds = new Set<String>();        
            for(ProjectChildJunction__c junc : [SELECT Id, ProjectShareclass__c, ProjectShareclass__r.name, ProjectShareclass__r.Share_Class_Name__c, ProjectShareclass__r.TECH_FieldsToModify__c, ProjectShareclass__r.Tech_ShareClass__c, 
                                                    ProjectProductChild__r.TECH_TeamValidation__c, ProjectProductChild__r.Name
                                                FROM ProjectChildJunction__c 
                                                WHERE ProjectProductChild__r.ProjectProductParent__c = :recordId]){
                fieldString +=  junc.ProjectShareclass__r.TECH_FieldsToModify__c + ';' ;
                shIds.add(junc.ProjectShareclass__r.Tech_ShareClass__c );
                shareClassIds.put(junc.ProjectShareclass__c,junc.ProjectShareclass__r.Tech_ShareClass__c );
                shareClassToFields.put(junc.ProjectShareclass__c, junc);
                if(shareClassToJunctions.containsKey(junc.ProjectShareclass__c) ) {
                    shareClassToJunctions.get(junc.ProjectShareclass__c).add(junc);
                }
                else {
                    shareClassToJunctions.put(junc.ProjectShareclass__c, new List<ProjectChildJunction__c>{junc});
                }
            }
            List<String> filteredFields = new List<String>();
            for(String f : fieldString.split(';')){
                if(f != null && f != 'null' && !filteredFields.contains(f)) filteredFields.add(f);
            }
            fieldString = String.join(filteredFields, ';');
            outputString = String.join(filteredFields, ',');
            String query = (outputString.contains('ISIN__c'))? 'SELECT Id, ' + outputString + ' FROM Share_Class__c WHERE Id IN :shIds' : 'SELECT Id, ISIN__c, ' + outputString + ' FROM Share_Class__c WHERE Id IN :shIds';
         
            for(Share_Class__c sc :  Database.query(query)){
                shareClassesFromRef.put(sc.Id, sc);
            }
        }

        String childObjectName = 'ProjectProductChild__c ';
        // FIX-20178: PMT matrix restricted to the project's Scope (PMTTeam__mdt.Scope__c): only the "Product Strategy" or "IS" team applies, otherwise the last rule read (IS) would win for the fields both teams own
        String projectScope = ProjectProductSetupHandlerUtilities.getProjectScope(recordId);
        PMTMatrix matrix = PMTMatrix.get().forScope(projectScope);
        for (PMTMatrix.FieldRule rule : matrix.rules) {
            for (String field : rule.getAllFields()) {
                teamOwners.put(field, rule.team);
                phases.put(field, rule.stage);
            }
        }
        String query = 'SELECT Id, TECH_Childtype__c, TECH_TeamValidation__c, ' + outputString + ' FROM  '+childObjectName+'  WHERE '+parent+' =\''+recordId+'\'' ;
        Map<String, String> stageToChildRecord = new Map<String, String>();
        Map<String, String> stageStatus = new Map<String, String>();
        Map<String, Map<String,String>> childtoStageRecord = new Map<String, Map<String,String>>();
        Map<String, Map<String,String>>  fieldNewValue = new Map<String, Map<String,String>>() ;
        Map<String, Map<String,String>>  fieldOldValue = new Map<String, Map<String,String>>() ;

        if(objectApiName == 'Share_Class__c'){
            parent = 'ProjectShareclasses__c' ;
            childObjectName = 'ProjectShareclassChild__c' ;
            query = 'SELECT Id, ProjectShareclasses__c, TECH_Childtype__c, ' + outputString +' FROM ProjectShareclassChild__c WHERE ProjectShareclasses__c IN (SELECT ProjectShareclass__c FROM  ProjectChildJunction__c WHERE ProjectProductChild__r.ProjectProductParent__c =\''+recordId+'\')';
        }

        List<ProjectChildJunction__c> projChildJunctions = [SELECT ProjectProductChild__c,ProjectProductChild__r.TECH_TeamValidation__c,ProjectProductChild__r.TECH_Childtype__c, ProjectShareclass__c,ProjectProductChild__r.Name 
                                                            FROM ProjectChildJunction__c
                                                            WHERE ProjectProductChild__r.ProjectProductParent__c =: recordId];
   
        for(Sobject child : Database.query(query)) {
            String childType = (String)child.get('TECH_Childtype__c');
            if(childType == null) continue;

            String childId = (String)child.get('Id');
            String projectShareclassId = objectApiName == 'Share_Class__c' ? (String)child.get('ProjectShareclasses__c') : null;

            // New value = stage record, previous value = referential record (Product, or the Share Class of the Project Shareclass)
            SObject reference = objectApiName == 'Share_Class__c' ? (SObject) shareClassesFromRef.get(shareClassIds.get(projectShareclassId)) : productFromRef;
            Map<String,String> fieldValueO = new Map<String,String>();
            Map<String,String> fieldValueN = new Map<String,String>();
            for (String field : fieldString.split(';')) {
                fieldValueO.put(field, String.valueOf(reference.get(field)));
                fieldValueN.put(field, String.valueOf(child.get(field)));
            }
            fieldNewValue.put(childId, fieldValueN);
            fieldOldValue.put(childId, fieldValueO);

            // The DesignAndProposal record is the Proposal stage
            String stage = childType == 'DesignAndProposal' ? 'Proposal' : childType;
            stageToChildRecord.put(stage, childId);
            if(objectApiName != 'Share_Class__c'){
                stageStatus.put(childId, (String)child.get('TECH_TeamValidation__c'));
                continue;
            }

            // Share Class: teams validated on the project stage of the same name
            for(ProjectChildJunction__c junction : shareClassToJunctions.get(projectShareclassId)){
                if(junction.ProjectProductChild__r.Name == stage){
                    stageStatus.put(childId, junction.ProjectProductChild__r.TECH_TeamValidation__c);
                    break;
                }
            }
            if(!childtoStageRecord.containsKey(projectShareclassId)) childtoStageRecord.put(projectShareclassId, new Map<String,String>());
            childtoStageRecord.get(projectShareclassId).put(stage, childId);
        }

        if(objectApiName == 'Share_Class__c'){
            for(Id shareClass : shareClassToFields.keySet()){
                ProjectChildJunction__c record = shareClassToFields.get(shareClass);
                if(String.isBlank(record.ProjectShareclass__r.TECH_FieldsToModify__c)) continue;

                Share_Class__c shareClassFromRef = shareClassesFromRef.get(shareClassIds.get(record.ProjectShareclass__c));
                for (String field : record.ProjectShareclass__r.TECH_FieldsToModify__c.split(';')) {
                    Map<String, String> fieldData = buildFieldRow(field, childtoStageRecord.get(record.ProjectShareclass__c), teamOwners, phases, fieldNewValue, fieldOldValue, stageStatus);
                    fieldData.put('shareclass', record.ProjectShareclass__r.Share_Class_Name__c);
                    if (shareClassFromRef != null) fieldData.put('isin', shareClassFromRef.ISIN__c);
                    fieldList.add(fieldData);
                }
            }
        }
        else {
            for (String field : fieldString.split(';')) {
                fieldList.add(buildFieldRow(field, stageToChildRecord, teamOwners, phases, fieldNewValue, fieldOldValue, stageStatus));
            }
        }

        return fieldList;
    }

    // One row of the LWC for a modified field: owning team and stage (PMT matrix), stage record, new and previous values, and whether the owning team has validated the stage
    private static Map<String, String> buildFieldRow(String field, Map<String, String> childIdByStage, Map<String, String> teamOwners, Map<String, String> phases, Map<String, Map<String, String>> fieldNewValue, Map<String, Map<String, String>> fieldOldValue, Map<String, String> stageStatus) {
        String team = teamOwners.get(field);
        String phase = phases.get(field);
        String childId = childIdByStage.get(phase);
        String validatedTeams = stageStatus.get(childId);

        return new Map<String, String>{
            'fieldName' => field,
            'teamOwner' => team ?? 'Unknown',
            'phase' => phase ?? 'Unknown',
            'childRecordId' => childId ?? '',
            'newValue' => fieldNewValue.get(childId).get(field) ?? '',
            'previousValue' => fieldOldValue.get(childId).get(field) ?? '',
            'statusValue' => validatedTeams != null && validatedTeams.contains(team?.replaceAll(' ', '')) ? 'Valid' : 'Invalid'
        };
    }


    @AuraEnabled
    public static void updateFieldValue(String sObjectName, String recordId, String fieldApiName, Object fieldValue) {
        SObject record = (SObject) Type.forName('Schema.' + sObjectName).newInstance();
        record.put('Id', recordId);
        record.put(fieldApiName, fieldValue);

        update record;
    }

    @AuraEnabled
    public static void updateFieldVal(String objectApiName, Id recordId, String fieldApiName, String newValue) {
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) throw new AuraHandledException('Missing object or field API name.');

        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName); // Obtenir le type du champ
        if (sObjType == null) throw new AuraHandledException('Invalid object API name.');

        Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldApiName)) throw new AuraHandledException('Invalid field API name.');

        Schema.DisplayType fieldType = fieldMap.get(fieldApiName).getDescribe().getType();

        // Convertir newValue selon le type
        Object parsedValue;
        switch on fieldType {
            when BOOLEAN         {  parsedValue = (newValue == 'true');          }
            when DOUBLE, PERCENT {  parsedValue = Double.valueOf(newValue);      }
            when INTEGER         {  parsedValue = Integer.valueOf(newValue);     }
            when CURRENCY        {  parsedValue = Decimal.valueOf(newValue);     }
            when DATE            {  parsedValue = Date.valueOf(newValue);        }
            when DATETIME        {  parsedValue = Datetime.valueOf(newValue);    }
            when else            {  parsedValue = newValue;                      }
        }

        // Requête et mise à jour
        String query = 'SELECT Id, ' + fieldApiName + ' FROM ' + objectApiName + ' WHERE Id = :recordId LIMIT 1';
        SObject recordToUpdate = Database.query(query);
        recordToUpdate.put(fieldApiName, parsedValue);
        update recordToUpdate;
    }

    @AuraEnabled
    public static void updateMultipleFields(List<FieldUpdate> updates) {
        Map<String, Map<Id, SObject>> groupedByObject = new Map<String, Map<Id, SObject>>();
        for (FieldUpdate fieldUpdate : updates) {
            if (String.isBlank(fieldUpdate.recordId) || String.isBlank(fieldUpdate.objectApiName) || String.isBlank(fieldUpdate.fieldApiName)) continue;
            if (!groupedByObject.containsKey(fieldUpdate.objectApiName)) groupedByObject.put(fieldUpdate.objectApiName, new Map<Id, SObject>());

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
            update allToUpdate;
        }
    }

    // ------------------------------------- WRAPPERS -------------------------------------
    public class FieldUpdate {
        public String recordId;
        public String objectApiName;
        public String fieldApiName;
        public String newValue;
    }
}