/**
* @author Abderrahmane TRIA
* @date Creation 18/04/2020
* @group BATCH
* @description BATCH to link Due Diligence to Legal Entity
*/
global class BATCH007_LinkDDToLegalEntities implements Database.Batchable<sObject> { 
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, Legal_Entity__c, TECH_brid__c FROM DueDiligence__c';        
        return Database.getQueryLocator(query);       
    }
    
    global void execute(Database.BatchableContext BC, List<DueDiligence__c> lstDueDiligence) {
        
        Map<String, ID> mapBirdID = new Map<String, ID>();
        List<DueDiligence__c> lstDueDiligenceToUpdate = new List<DueDiligence__c>();
        
        for(Legal_Entity__c le : [SELECT ID, TECH_brid__c FROM Legal_Entity__c]){
            mapBirdID.put(le.TECH_brid__c, le.ID);
        }
        
        for(DueDiligence__c dd : lstDueDiligence) {
            if( mapBirdID.containsKey(dd.TECH_brid__c) ){
                dd.Legal_Entity__c = mapBirdID.get(dd.TECH_brid__c);
                lstDueDiligenceToUpdate.add(dd);
            }
        }
        try {
            
            if(lstDueDiligenceToUpdate.size()>0)
                Database.update(lstDueDiligenceToUpdate,false);
        } catch(Exception e) {
            System.debug('Link DD to LE - The following exception has occurred: ' + e);
        }
    }
    
    global void finish(Database.BatchableContext BC){
        // BATCH003
        Database.executeBatch(new BATCH003_UpdateLegalEntities(), 200); 
    }
}