/**
* @author Abderrahmane TRIA
* @date Creation 14/04/2020
* @date Update 24/06/2020
* @group BATCH
* @description BATCH to update Legal Entities From GLEIF
*/
global with sharing class BATCH003_UpdateLegalEntities implements Database.Batchable<sObject>, Database.AllowsCallouts{ 
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        // collect the batches of records or objects to be passed to execute
        String query = 'SELECT Id, UME_ID__c, LEI__c FROM Legal_Entity__c WHERE LEI__c != null';
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext BC, List<Legal_Entity__c> lLegalEntity) {
        
        List<String> lLEIs = new List<String>();
        Map<String , Legal_Entity__c> mLeiLE = new Map<String , Legal_Entity__c>();
        List<Legal_Entity__c> lLegalEntitiesUpadte = new List<Legal_Entity__c>();
        
        // Map PickList Values
        Map<String,String> checkJ = ObjectUtil.getPickListMapValues('Legal_Entity__c', 'Jurisdiction__c');
        
        for(Legal_Entity__c le : lLegalEntity) {
            if (le.LEI__c != 'No LEI UME')
                lLEIs.add(le.LEI__c);
            mLeiLE.put(le.LEI__c, le);
        }
        
        String leis = string.join(lLEIs,',');
        List<List<String>> lstWrapper = new List<List<String>>();
        // Spilt lists in max. 50 elements each (we can change dynamically)
        for(Integer i = 0 ; i < (lLEIs.size() / 50)+1 ; i++){
            List<String> lstTemp = new List<String>();
            for(Integer j=(i*50);(j<(i*50)+50) && j<lLEIs.size() ; j++){
                lstTemp.add(lLEIs.get(j));
            }
            lstWrapper.add(lstTemp);
        }
        
        Map<String , JSONLegalEntity2Apex.data> mLeiGLEIF = new Map<String , JSONLegalEntity2Apex.data>();
        for (List<String> lstOfLei :lstWrapper){
            String lLei = string.join(lstOfLei,','); 
            // Get All Legal Entities from lei.info
            JSONLegalEntity2Apex allDatas = UTIL_LegalEntity.getLegalEntity(lLei);
            
            for(JSONLegalEntity2Apex.data data: allDatas.data) {
                if (data != null)
                    mLeiGLEIF.put(data.id,data);
            }
        }
        
        for (Legal_Entity__c le:lLegalEntity){
            JSONLegalEntity2Apex.data data = mLeiGLEIF.get(le.LEI__c);
            
            if (data != null){
                le.Business_Zip_Post_Code__c = data.attributes.entity.legalAddress.postalCode;
                le.Initial_Registration_Date__c = Date.valueOf(data.attributes.registration.initialRegistrationDate);
                if(checkJ.containsKey(data.attributes.entity.jurisdiction))
                    le.Jurisdiction__c = data.attributes.entity.jurisdiction;
                le.Last_Registration_Update__c = Date.valueOf(data.attributes.registration.lastUpdateDate);
                le.Legal_Entity_Address__c = string.join(data.attributes.entity.legalAddress.addressLines,'');
                le.Legal_Entity_City__c = data.attributes.entity.legalAddress.city;
                le.Legal_Form_ID__c = data.attributes.entity.legalForm.id;
                le.Legal_Form__c = data.attributes.entity.legalForm.other;
                le.LEI_Status__c = data.attributes.entity.status;
                le.Registration_Status__c = data.attributes.registration.status;
                
                le.Country__c = data.attributes.entity.legalAddress.country;

                Integer maxSize = 80;
                if(data.attributes.entity.legalName.name.length() > maxSize ){
                    le.Name = data.attributes.entity.legalName.name.substring(0, maxSize);
                    le.Full_Legal_Entity_Name__c = data.attributes.entity.legalName.name;
                }else {
                    le.Name = data.attributes.entity.legalName.name;
                    le.Full_Legal_Entity_Name__c = data.attributes.entity.legalName.name;
                }
                lLegalEntitiesUpadte.add(le);
            }
        }
        
        try {
            // Update the Legal Entity Record
            Database.update(lLegalEntitiesUpadte,false);
        } catch(Exception e) {
            System.debug(e);
        }
    }   
    
    global void finish(Database.BatchableContext BC) {
        // BATCH008
        Database.executeBatch(new BATCH008_UpdateDueDiligence(), 45); 
    }
}