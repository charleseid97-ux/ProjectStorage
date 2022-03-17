/**
* @author Abderrahmane TRIA
* @date Creation 29/04/2020
* @group BATCH
* @description BATCH to Insert Profile From UME
*/
global class BATCH009_InsertProfileUME implements Database.Batchable<String>, Database.AllowsCallouts{ 
        
    global Iterable<String> start(Database.BatchableContext context) {
        List<String> guids = new List<String>();
        List<JSONLegalEntityUME2Apex> jApexUME = UTIL_LegalEntity.getDistributors('/api/v2/network/distributors/');
        for(JSONLegalEntityUME2Apex ja : jApexUME){
            if(ja != null){
                JSONLegalEntityUME2Apex.Company company = ja.Company;
                guids.add(company.guid);
            }
        }
        return guids;
    }
    
    global void execute(Database.BatchableContext BC, List<String> guids) {
 
        List<ProfileUME__c> ProfileUMEToInsert = new List<ProfileUME__c>();    
        List<JSONLegalEntityUME2Apex> jApexUME = UTIL_LegalEntity.getDistributors('/api/v2/network/distributors/');
        
        // Profile UME Infos
        Map<String, ProfileUME__c> mapGuidP = new Map<String, ProfileUME__c>();   
        for(ProfileUME__c pUME : [SELECT Id, lei__c, guid__c, internalId__c FROM ProfileUME__c]) {            
            mapGuidP.put(pUME.guid__c, pUME);
        }
        
        // Populate Map from UME callout
        Map<String, JSONLegalEntityUME2Apex> mapGuidJaUME = new Map<String, JSONLegalEntityUME2Apex>();
        for(JSONLegalEntityUME2Apex ja : jApexUME){
            JSONLegalEntityUME2Apex.Company company = ja.Company;
            mapGuidJaUME.put(company.guid, ja);
        }
        
        for(String guid : guids){
            ProfileUME__c pume = new ProfileUME__c();
            
            if(!mapGuidP.containsKey(guid)){
                JSONLegalEntityUME2Apex ja = mapGuidJaUME.get(guid);
                if (ja != null) {
                    
                    JSONProfileUME2Apex jProfileApex = UTIL_LegalEntity.getProfile('/api/v2/brs/'+ja.brid+'/controlled/profile');
                    if( jProfileApex != null ){

                        pume.guid__c = jProfileApex.guid;
                        pume.companyName__c = jProfileApex.companyName;
                        pume.companyType__c = jProfileApex.companyType;
                        pume.country__c = jProfileApex.country.name;
                        pume.internalId__c = jProfileApex.internalId;
                        pume.lat__c = String.valueOf(jProfileApex.lat);
                        pume.lei__c = jProfileApex.lei;
                        pume.lon__c = String.valueOf(jProfileApex.lon);
                        pume.status__c = jProfileApex.status;
                        pume.streetAddress__c = jProfileApex.streetAddress;
                        
                        pume.brid__c = ja.brid;
                        
                        ProfileUMEToInsert.add(pume);
                    }
                }
            }
        }
        
        try {
            if(ProfileUMEToInsert.size()>0)
                Database.insert(ProfileUMEToInsert,false);
        } catch(Exception e) {
            System.debug('Insertion Profile UME - The following exception has occurred: ' + e);
        }
        
    }        
    global void finish(Database.BatchableContext BC) {
        // execute BATCH004
        Database.executeBatch(new BATCH004_InsertLegalEntitiesUME(), 45);        
    }
    
}