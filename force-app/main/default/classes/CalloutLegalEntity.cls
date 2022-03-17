/**
* @author Abderrahmane TRIA
* @date Creation 07/04/2020
* @group Callour
* @description REST Callout GLEIF & UME to populate fields Legal Entity
*/
public class CalloutLegalEntity {
    @future(callout=true)
    public static void processRecords(String leis) {
        
        // Deserialize the JSON string into collections of primitive data types.
        JSONLegalEntity2Apex jApexGLEIF = UTIL_LegalEntity.getLegalEntity(leis);
        List<JSONLegalEntityUME2Apex> jApexUME = UTIL_LegalEntity.getDistributors('/api/v2/network/distributors/');
        
        Map<String , JSONLegalEntity2Apex.data> mLeiGLEIF = new Map<String , JSONLegalEntity2Apex.data>();
        Map<String , JSONLegalEntityUME2Apex> mLeiUME = new Map<String , JSONLegalEntityUME2Apex>();
        // Map PickList Values
        Map<String,String> checkJ = ObjectUtil.getPickListMapValues('Legal_Entity__c', 'Jurisdiction__c');
        
        List<String> lstLei = leis.split(',');
        
        for(JSONLegalEntity2Apex.data data: jApexGLEIF.data) {
            if (data != null)
                mLeiGLEIF.put(data.id,data);
        }
        for(JSONLegalEntityUME2Apex ja : jApexUME){
            if (ja != null)
                mLeiUME.put(ja.Company.lei,ja);
        }
        
        // Get Legal Entity to Insert
        List<Legal_Entity__c> listLE = [SELECT Business_Zip_Post_Code__c,Country_of_Incorporation__c,Country__c,Id,Initial_Registration_Date__c,
                                        Jurisdiction__c,Last_Registration_Update__c,LEI__c,Legal_Entity_Source__c,Full_Legal_Entity_Name__c,
                                        Legal_Entity_Address__c,Legal_Entity_City__c,UME_ID__c,Legal_Form_ID__c,Legal_Form__c,LEI_Status__c,
                                        Name,Registration_Status__c
                                        FROM Legal_Entity__c
                                        WHERE LEI__c IN :lstLei];
        
        // New Due Diligence & Legal Entity Related Contact
        DueDiligence__c dd = new DueDiligence__c();
        
        for (Legal_Entity__c le:listLE){
            JSONLegalEntity2Apex.data data = mLeiGLEIF.get(le.LEI__c);
            JSONLegalEntityUME2Apex ja = mLeiUME.get(le.LEI__c);
            
            if (lstLei.size() > 1){
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
                    le.Legal_Entity_Source__c = 'GLEIF';
                    Integer maxSize = 80;
                    if(data.attributes.entity.legalName.name.length() > maxSize ){
                        le.Name = data.attributes.entity.legalName.name.substring(0, maxSize);
                        le.Full_Legal_Entity_Name__c = data.attributes.entity.legalName.name;
                    }else {
                        le.Name = data.attributes.entity.legalName.name;
                        le.Full_Legal_Entity_Name__c = data.attributes.entity.legalName.name;
                    }
                } 
                // UME Side
                if (ja != null){
                    JSONLegalEntityUME2Apex.Company company = ja.Company;
                    le.UME_ID__c = company.guid;
                    if (company.guid !=null)
                        le.Legal_Entity_Source__c = 'UME';
                    le.Website__c = company.website;
                    le.pctAnswered__c = ja.pctAnswered;
                    le.pctValidated__c = ja.pctValidated;
                    le.TECH_brid__c = ja.brid;
                }
                
            }else{
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
                    le.Legal_Entity_Source__c = 'GLEIF';
                    Integer maxSize = 80;
                    if(data.attributes.entity.legalName.name.length() > maxSize ){
                        le.Name = data.attributes.entity.legalName.name.substring(0, maxSize);
                        le.Full_Legal_Entity_Name__c = data.attributes.entity.legalName.name;
                    }else {
                        le.Name = data.attributes.entity.legalName.name;
                        le.Full_Legal_Entity_Name__c = data.attributes.entity.legalName.name;
                    }
                }
                if (ja != null) {
                    JSONLegalEntityUME2Apex.Company company = ja.Company;
                    JSONLegalEntityUME2Apex.Scoring scoring = ja.Scoring;
                    JSONLegalEntityUME2Apex.Contact contact = ja.Contact;
                    le.UME_ID__c = company.guid;
                    if (company.guid !=null)
                        le.Legal_Entity_Source__c = 'UME';
                    le.Website__c = company.website;
                    
                    le.pctAnswered__c = ja.pctAnswered;
                    le.pctValidated__c = ja.pctValidated;
                    le.TECH_brid__c = ja.brid;
                    dd.TECH_brid__c = ja.brid;
                    dd.Request_Status__c = UTIL_LegalEntity.getRequestStatus(ja.Status);
                    if (scoring !=null){
                        dd.BaseScore__c = scoring.baseScore;
                        dd.Legal_Entity__c = le.Id;
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
                        dd.Status__c = String.valueOf(jAssessmentsApex.assessmentStatus);
                        dd.Last_AML_Review__c = Date.valueOf(jAssessmentsApex.assessmentDate);
                        dd.Next_Review_Date__c = Date.valueOf(jAssessmentsApex.expirationDate);
                        dd.Subjective_Scoring_Factor__c = jAssessmentsApex.scoringFactor*100;
                        dd.Summary__c = jAssessmentsApex.summary;
                        dd.Status_of_Completion__c = jAssessmentsApex.assessmentScore;
                    }                    
                }
            }
        }
        // Upsert LEgal Entity & insert Due Diligence record
        try {
            // Update the Legal Entity Record
            Database.upsert(listLE,false);
            if (dd.Legal_Entity__c != null && lstLei.size() == 1)
                Database.insert(dd,false);
        } catch(Exception e) {
            System.debug(e);
        }          
    }
}