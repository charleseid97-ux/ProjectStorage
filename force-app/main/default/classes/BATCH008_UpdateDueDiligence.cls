/**
* @author Abderrahmane TRIA
* @date Creation 25/06/2020
* @group BATCH
* @description BATCH to update Due Diligence BATCH003_UpdateLegalEntities
*/
global class BATCH008_UpdateDueDiligence implements Database.Batchable<sObject>, Database.AllowsCallouts{ 
    

    global Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, Legal_Entity__c, TECH_brid__c FROM DueDiligence__c';        
        return Database.getQueryLocator(query);       
    }
    
    global void execute(Database.BatchableContext BC, List<DueDiligence__c> lstDueDiligence) {
                
        List<JSONLegalEntityUME2Apex> jApexUME = UTIL_LegalEntity.getDistributors('/api/v2/network/distributors/');
        
        Map<String, JSONLegalEntityUME2Apex> mapBirdGuid = new Map<String, JSONLegalEntityUME2Apex>();

        for(JSONLegalEntityUME2Apex ja : jApexUME){
            if ( ja != null ) 
                mapBirdGuid.put(ja.brid, ja);
        }
        
        List<DueDiligence__c> lstDueDiligenceToInsert = new List<DueDiligence__c>();
        
        for(DueDiligence__c dd : lstDueDiligence) {
            JSONLegalEntityUME2Apex ja = mapBirdGuid.get(dd.TECH_brid__c);
            if (ja != null) {
                JSONLegalEntityUME2Apex.Scoring scoring = ja.Scoring;

                dd.Request_Status__c = UTIL_LegalEntity.getRequestStatus(ja.Status);
                if (scoring !=null){
                    dd.BaseScore__c = scoring.baseScore;
                    dd.Overall_Total_Risk_Score__c = scoring.totalScore;
                    dd.Country_Risk_Factor__c = scoring.countryRiskFactor*100;
                    JSONScoreUME2Apex jScoreApex = UTIL_LegalEntity.getScore('/api/v2/brs/'+ja.brid+'/controlled/score/current');
                    if (jScoreApex !=null){
                        if(scoring.totalScore < jScoreApex.yellowThreshold)
                            dd.Overall_Qualification__c = 'Low';
                        else if(scoring.totalScore < jScoreApex.redThreshold)
                            dd.Overall_Qualification__c = 'Medium';
                        else
                            dd.Overall_Qualification__c = 'High';
                    }
                }
                JSONAssessmentsUME2Apex jAssessmentsApex = UTIL_LegalEntity.getAssessment('/api/v2/brs/'+ja.brid+'/controlled/assessment/latest');
                if (jAssessmentsApex !=null){
                    if (jAssessmentsApex.assessmentStatus !=null)
                        dd.Status__c = String.valueOf(jAssessmentsApex.assessmentStatus);
                    if (jAssessmentsApex.assessmentDate !=null)
                        dd.Last_AML_Review__c = Date.valueOf(jAssessmentsApex.assessmentDate);
                    if (jAssessmentsApex.expirationDate !=null)
                        dd.Next_Review_Date__c = Date.valueOf(jAssessmentsApex.expirationDate);
                    if (jAssessmentsApex.scoringFactor !=null)
                        dd.Subjective_Scoring_Factor__c = jAssessmentsApex.scoringFactor*100;
                    if (jAssessmentsApex.summary !=null)
                        dd.Summary__c = jAssessmentsApex.summary;
                    if (jAssessmentsApex.assessmentScore !=null)
                        dd.Status_of_Completion__c = jAssessmentsApex.assessmentScore;
                }
            }
            lstDueDiligenceToInsert.add(dd);
        }
        try {
            if(lstDueDiligenceToInsert.size()>0)
                Database.update(lstDueDiligenceToInsert,false);
        } catch(Exception e) {
            System.debug('Update DD UME - The following exception has occurred: ' + e);
        }
    }
    
    global void finish(Database.BatchableContext BC){
        
    }
}