/**
* @author Abderrahmane TRIA
* @date Creation 07/04/2020
* @group UME
* @description REST Callout UME to populate fields Legal Entity (guid, website)
*/
public class CalloutUMELegalEntity {
    
    //Constants
    public static final string guid = 'b56e935b-8a47-479b-b275-764fb30e5cad';
    public static final string UME_Auth = 'ume bUBTLUprhDRaR6UH5Yth9w:epaNbfiB2iNWmwoLg_b7ew';
    
    @future(callout=true)
    public static void  processUME (String lei) {
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint('callout:UME_API/api/v2/network/distributors/');
            request.setMethod('GET');
            request.setHeader('X-ume-CompanyId',guid);
            request.setHeader('Authorization', UME_Auth);
            
            HttpResponse response = http.send(request);
            // If the request is successful, parse the JSON response.
            if (response.getStatusCode() == 200  && !Test.isRunningTest()) {
                
                //Deserialize the JSON string into collections of primitive data types.
                List<JSONLegalEntityUME2Apex>  jsonApex = (List<JSONLegalEntityUME2Apex>)JSON.deserialize(response.getBody(), List<JSONLegalEntityUME2Apex>.class);
                
                // Get Legal Entity to Update
                Legal_Entity__c le = [SELECT LEI__c,UME_ID__c,Website__c,Legal_Entity_Source__c
                                      FROM Legal_Entity__c
                                      WHERE LEI__c = :lei];
                //loop results
                for(JSONLegalEntityUME2Apex ja : jsonApex){
                    if (ja.Company.lei == lei){
                        JSONLegalEntityUME2Apex.Company company = ja.Company;
                        le.UME_ID__c = company.guid;
                        if (company.guid !=null)
                            le.Legal_Entity_Source__c = 'UME';
                        le.Website__c = company.website;
                    }                    
                }
                
                //upsert the record
                update le; 
            }
        }catch(System.CalloutException e) {
            System.debug('Callout UME - The following exception has occurred: ' + e.getMessage());
        }
    }
}