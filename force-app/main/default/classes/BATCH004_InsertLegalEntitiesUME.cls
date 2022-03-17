/**
* @author Abderrahmane TRIA
* @date Creation 23/04/2020
* @date Update 24/06/2020
* @group BATCH
* @description BATCH to Insert Legal Entities From UME
*/
global class BATCH004_InsertLegalEntitiesUME implements Database.Batchable<String>, Database.AllowsCallouts{ 
    
    global Iterable<String> start(Database.BatchableContext context) {
        List<String> guids = new List<String>();
        List<JSONLegalEntityUME2Apex> jApexUME = UTIL_LegalEntity.getDistributors('/api/v2/network/distributors/');
        for(JSONLegalEntityUME2Apex ja : jApexUME){
            if(ja != null){
                JSONLegalEntityUME2Apex.Company company = ja.Company;
                if ( company.guid != null )
                    guids.add(company.guid);
            }
        }
        return guids;
    }
    
    global void execute(Database.BatchableContext BC, List<String> guids) {
        
        Integer maxSize = 80;
        
        List<DueDiligence__c> lstDueDiligenceToInsert = new List<DueDiligence__c>();
        List<Legal_Entity__c> LegalEntityToInsert = new List<Legal_Entity__c>();
        
        //Deserialize the JSON string into collections of primitive data types.        
        List<JSONLegalEntityUME2Apex> jApexUME = UTIL_LegalEntity.getDistributors('/api/v2/network/distributors/');
        // Map PickList Values
        Map<String,String> checkJ = ObjectUtil.getPickListMapValues('Legal_Entity__c', 'Country__c');
        
        // Legal Entity Infos
        Map<String, Legal_Entity__c> mapGuidLei = new Map<String, Legal_Entity__c>();
        for(Legal_Entity__c legalE : [SELECT Id,LEI__c,UME_ID__c,TECH_brid__c FROM Legal_Entity__c]) {
            mapGuidLei.put(legalE.UME_ID__c, legalE);
        }
        // Populate Map from UME callout
        Map<String, JSONLegalEntityUME2Apex> mapGuidJaUME = new Map<String, JSONLegalEntityUME2Apex>();
        //Map<String, JSONLegalEntityUME2Apex> mapBirdJa = new Map<String, JSONLegalEntityUME2Apex>();
        for(JSONLegalEntityUME2Apex ja : jApexUME){
            JSONLegalEntityUME2Apex.Company company = ja.Company;
            if ( company.guid != null )
                mapGuidJaUME.put(company.guid, ja);
            //mapBirdJa.put(ja.brid, ja);
        }
        // Agreement Infos 
        List<String> lstAgreementCode = new List<String>();
        Map<String, String> mapGuidinternalId = new Map<String, String>();
        Map<String, ProfileUME__c> mapBridProfile = new Map<String, ProfileUME__c>();
        // Get Profile UME
        for(ProfileUME__c pume : [SELECT brid__c,companyName__c,companyType__c,country__c,guid__c,internalId__c,LastAMLReview__c,lat__c,lei__c,
                                  lon__c,NextReviewDate__c,OverallQualification__c,StatusAssessment__c,StatusOfCompletion__c,status__c,
                                  streetAddress__c,SubjectiveScoringFactor__c,Summary__c 
                                  FROM ProfileUME__c]) {
            if ( pume.internalId__c != null){
                lstAgreementCode.add(pume.internalId__c);
                mapGuidinternalId.put(pume.guid__c, pume.internalId__c);
            }
                                      mapBridProfile.put(pume.brid__c, pume);
        } 
        
        Map<String, String> mapACCompany = new Map<String, String>();
        for(Convention__c agr : [SELECT ID, Name, Company__c FROM Convention__c WHERE Name IN: lstAgreementCode]) {
            mapACCompany.put(agr.Name, agr.Company__c);
        }
        
        for(String guid : guids){    
            DueDiligence__c dd = new DueDiligence__c();
            Legal_Entity__c le = new Legal_Entity__c();
            //Legal_Entity__c LegalEntity = mapGuidLei.get(v);
            if(!mapGuidLei.containsKey(guid)){
                JSONLegalEntityUME2Apex ja = mapGuidJaUME.get(guid);
                if (ja != null) {
                    ProfileUME__c pume = mapBridProfile.get(ja.brid);
                    JSONLegalEntityUME2Apex.Company company = ja.Company;
                    JSONLegalEntityUME2Apex.Scoring scoring = ja.Scoring;
                                        
                    if( company.companyName.length() > maxSize ) {                   
                        le.Name = company.companyName.substring(0, maxSize);
                        le.Full_Legal_Entity_Name__c = company.companyName;
                    }else{
                        le.Name = company.companyName;
                        le.Full_Legal_Entity_Name__c = company.companyName;
                    }
                    
                    if(checkJ.containsKey(company.country.code))
                        le.Country__c = company.country.code;
                    le.Location__Latitude__s = company.lat;
                    le.Location__Longitude__s = company.lon;
                    le.Legal_Entity_Address__c = company.streetAddress;
                    
                    le.Company__c = mapACCompany.get(mapGuidinternalId.get(guid));
                    le.LEI__c = (company.lei != null) ? company.lei : 'NO LEI UME';
                    le.LEI_Status__c = company.status;
                    le.UME_ID__c = company.guid;
                    le.Legal_Entity_Source__c = 'UME';
                    le.Website__c = company.website;
                    le.pctAnswered__c = ja.pctAnswered;
                    le.pctValidated__c = ja.pctValidated;
                    le.TECH_brid__c = ja.brid;
                    dd.TECH_brid__c = ja.brid;
                    dd.Request_Status__c = UTIL_LegalEntity.getRequestStatus(ja.Status);
                    if (scoring !=null){
                        dd.BaseScore__c = scoring.baseScore;
                        dd.Overall_Total_Risk_Score__c = scoring.totalScore;
                        dd.Country_Risk_Factor__c = scoring.countryRiskFactor*100;
                        if (pume !=null){
                            dd.Overall_Qualification__c = pume.OverallQualification__c;
                            dd.Status__c = pume.StatusAssessment__c;
                            dd.Last_AML_Review__c = pume.LastAMLReview__c;
                            dd.Next_Review_Date__c = pume.NextReviewDate__c;
                            dd.Subjective_Scoring_Factor__c = pume.SubjectiveScoringFactor__c;
                            dd.Summary__c = pume.Summary__c;
                            dd.Status_of_Completion__c = pume.StatusOfCompletion__c;
                        }
                    }
                    LegalEntityToInsert.add(le);
                    if (company.lei != null)
                        lstDueDiligenceToInsert.add(dd);
                }
            }
        }
        try {
            if(LegalEntityToInsert.size()>0)
                Database.insert(LegalEntityToInsert,false);
            if(lstDueDiligenceToInsert.size()>0)
                Database.insert(lstDueDiligenceToInsert,false);
        } catch(Exception e) {
            System.debug('Insertion LE UME - The following exception has occurred: ' + e);
        }
        
    }        
    global void finish(Database.BatchableContext BC) {
        // BATCH007
        Database.executeBatch(new BATCH007_LinkDDToLegalEntities(), 200);        
    }
}