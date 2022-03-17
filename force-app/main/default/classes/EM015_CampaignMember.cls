/** 
* @author: Adolphe SONKO
* @date : Creation 27/02/2017
* @date : Modification 27/02/2017
* @description : this Class allow to manage Campaign Member entity data preparation .
*/

public class EM015_CampaignMember {
    
    private static String CLASS_NAME = 'EM015_CampaignMember';
    public static final String EVENT_STATUS = 'Pre-Event';
    private static String HTTP_METHOD_PUT = 'PUT';
    private static String HTTP_METHOD_POST = 'POST';
    public static String SETTING_NAME = 'EtouchesAPI';
    private static String POST_CREATE_SUBSCRIBER = '/emarketing/createSubscriber.xml';
    private static String PUT_UPDATE_SUBSCRIBER = '/emarketing/updateSubscriber.xml';
     
   private static ITF008_POSTCreateSubscriberWS postCreateSubscriber_STUB {get {return Etouches4_STUB();}}
  
   private static ITF008_POSTCreateSubscriberWS Etouches4_STUB(){
        
        String methodName = 'Etouches4_STUB';
        ITF008_POSTCreateSubscriberWS STUB;
        
        if (Test.isRunningTest()){
            STUB = new MCK006_CampaignMember();            
        } else {             
             STUB = new DM017_etouchesCreateSubscriber();            
        }
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[RESULTS] : ' + STUB);
        return STUB;  
    }    
   
   private static ITF008_POSTCreateSubscriberWS putUpdateSubscriber_STUB {get {return Etouches5_STUB();}}
    
   private static ITF008_POSTCreateSubscriberWS Etouches5_STUB(){
        
        String methodName = 'Etouches5_STUB';
        ITF008_POSTCreateSubscriberWS STUB;
        
        if (Test.isRunningTest()){
            STUB = new MCK006_CampaignMember();            
        } else {             
             STUB = new DM017_etouchesCreateSubscriber();   
        }
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[RESULTS] : ' + STUB);
        return STUB;  
    }
    
    public static HttpRequest getPutUpdateSubscriber(WebserviceParameters__c param_setting, String token, CampaignMember campMember, String categ){
        
        String methodName = 'getPutUpdateSubscriber';
      
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        
        HttpRequest request = getUpdateSubscriber(param_setting, HTTP_METHOD_PUT, PUT_UPDATE_SUBSCRIBER,token,campMember, categ);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);
        return request;
    }    
     
    private static HttpRequest getUpdateSubscriber(WebserviceParameters__c param_setting, String httpMethod, String expectedWebService, String token, CampaignMember campMember, String categ){
        
        String methodName = 'getUpdateSubscriber';
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
        
        String email = '&email=';
        String fname = '&fname=';
        String lname = '&lname=';
        String prefix = '&prefix=';
        String jobTitle = '&title=';
        String company = '&company=';
        String addresLine1 = '&address1=' ;
        String city = '&city=';
        String country = '&country=' ;
        String zip = '&zip=';
        String phone = '&wphone=';
        String mobile = '&mphone=';
        String language = '&language=';
        String contactOwner = '&sendername=';
        String ownerEmail = '&senderemail=';
        
        String cEmail = campMember.Event_Email__c;
        String cFname = campMember.FirstName;
        String cLname = campMember.LastName;
        String cPrefix = campMember.Salutation;
        String cJobTitle = campMember.Job_Title__c;
        String cCompany = campMember.Company_T__c;
        String cAddresLine1 = campMember.Address_Line_1__c ;
        String cCity = campMember.City__c;
        String cCountry = campMember.Country__c ;
        String cZip = campMember.Zip__c;
        String cPhone = campMember.Phone__c;
        String cMobile = campMember.Mobile__c;
        String cLanguage = campMember.Language__c;
        String cContactOwner = campMember.Contact_Owner__c;
        String cOwnerEmail = campMember.Owner_email__c;
        
        If(ObjectUtil.isEmpty(campMember.Event_Email__c)){
            email = '&email';
            cEmail='';
        }
         
        If(ObjectUtil.isEmpty(campMember.FirstName)){
            fname = '&fname';
            cFname='';
        }
         
        If(ObjectUtil.isEmpty(campMember.LastName)){
            lname = '&lname';
            cLname='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Salutation)){
            prefix = '&prefix';
            cPrefix='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Job_Title__c)){
            JobTitle = '&title';
            cJobTitle='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Company_T__c)){
            Company = '&company';
            cCompany='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Address_Line_1__c)){
            AddresLine1 = '&address1';
            cAddresLine1='';
        }
         
        If(ObjectUtil.isEmpty(campMember.City__c)){
            City = '&city';
            cCity='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Country__c)){
            Country = '&country';
            cCountry='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Zip__c)){
            Zip = '&zip';
            cZip='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Phone__c)){
            Phone = '&wphone';
            cPhone='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Mobile__c)){
            Mobile = '&mphone';
            cMobile='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Language__c)){
            Language = '&language';
            cLanguage='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Contact_Owner__c)){
            ContactOwner = '&sendername';
            cContactOwner='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Owner_email__c)){
            OwnerEmail = '&senderemail';
            cOwnerEmail='';
        }
        
        String status = 'Subscribed'; 
        
        if (campMember.Status == 'Unsubscribed' || campMember.Subscriber__c == true)
        {
             status='Unsubscribed';
        }
        
        if (campMember.Status == 'Invited' ){           
             status = 'Subscribed';
        }  
        
        String requestBody =   'subscriberid=' + campMember.TECH_ID_Subscriber__c+                                   
                                    email + EncodeAndChar(cEmail)+
                                    prefix + EncodeAndChar(cPrefix)+
                                    fname + EncodeAndChar(cFname)+
                                    lname + EncodeAndChar(cLname)+                                   
                                    //'&status=' + status+                                    
                                    '&categoryid=' + categ+                                 
                                    jobTitle + EncodeAndChar(cJobTitle)+
                                    company + EncodeAndChar(cCompany)+
                                    addresLine1 + EncodeAndChar(cAddresLine1)+
                                    city + EncodeAndChar(cCity)+
                                    zip + EncodeAndChar(cZip)+
                                    country + EncodeAndChar(cCountry)+
                                    phone + EncodeAndChar(cPhone)+
                                    mobile + EncodeAndChar(cMobile)+
                                    language + EncodeAndChar(cLanguage)+
                                    contactOwner + EncodeAndChar(cContactOwner)+
                                    ownerEmail + EncodeAndChar(cOwnerEmail);
        
        HttpRequest request = new HttpRequest();
        
        request.setEndpoint(param_setting.Endpoint__c + expectedWebService + '?accesstoken='+token);
        request.setMethod(httpMethod);
        request.setBody(requestBody);       
                                   
        request.setTimeout(120000);
        
        return request;     
    }
    
    public static HttpRequest getPostCreateSubscriber(WebserviceParameters__c param_setting, String token, String eventID, String mailinListID, CampaignMember campMember, String categID){
        
        String methodName = 'getPostCreateSubscriber'; 
      
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        
        HttpRequest request = getCreateSubscriber(param_setting, HTTP_METHOD_POST, POST_CREATE_SUBSCRIBER,token,eventID,mailinListID, campMember, categID);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);
        return request;
    }
    
     private static HttpRequest getCreateSubscriber(WebserviceParameters__c param_setting, String httpMethod, String expectedWebService, String token, String eventID, String mailingListID, CampaignMember campMember, String categ){
        
        system.debug('getCreateSubscriber');        
        
        String methodName = 'getCreateSubscriber';
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
        
        HttpRequest request = new HttpRequest();
        String status = 'Subscribed';
        request.setEndpoint(param_setting.Endpoint__c + ExpectedWebService);
        request.setMethod(httpMethod);
        
        String email = '&email=';
        String fname = '&fname=';
        String lname = '&lname=';
        String prefix = '&prefix=';
        String jobTitle = '&title=';
        String company = '&company=';
        String addresLine1 = '&address1=' ;
        String city = '&city=';
        String country = '&country=' ;
        String zip = '&zip=';
        String phone = '&wphone=';
        String mobile = '&mphone=';
        String language = '&language=';
        String contactOwner = '&sendername=';
        String ownerEmail = '&senderemail=';
         
        String cEmail = campMember.Event_Email__c;
        String cFname = campMember.FirstName;
        String cLname = campMember.LastName;
        String cPrefix = campMember.Salutation;
        String cJobTitle = campMember.Job_Title__c;
        String cCompany = campMember.Company_T__c;
        String cAddresLine1 = campMember.Address_Line_1__c ;
        String cCity = campMember.City__c;
        String cCountry = campMember.Country__c ;
        String cZip = campMember.Zip__c;
        String cPhone = campMember.Phone__c;
        String cMobile = campMember.Mobile__c;
        String cLanguage = campMember.Language__c;
        String cContactOwner = campMember.Contact_Owner__c;
        String cOwnerEmail = campMember.Owner_email__c;
        
        If(ObjectUtil.isEmpty(campMember.Event_Email__c)){
            email = '&email';
            cEmail='';
        }
         
        If(ObjectUtil.isEmpty(campMember.FirstName)){
            fname = '&fname';
            cFname='';
        }
         
        If(ObjectUtil.isEmpty(campMember.LastName)){
            lname = '&lname';
            cLname='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Salutation)){
            prefix = '&prefix';
            cPrefix='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Job_Title__c)){
            JobTitle = '&title';
            cJobTitle='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Company_T__c)){
            Company = '&company';
            cCompany='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Address_Line_1__c)){
            AddresLine1 = '&address1';
            cAddresLine1='';
        }
         
        If(ObjectUtil.isEmpty(campMember.City__c)){
            City = '&city';
            cCity='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Country__c)){
            Country = '&country';
            cCountry='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Zip__c)){
            Zip = '&zip';
            cZip='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Phone__c)){
            Phone = '&wphone';
            cPhone='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Mobile__c)){
            Mobile = '&mphone';
            cMobile='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Language__c)){
            Language = '&language';
            cLanguage='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Contact_Owner__c)){
            ContactOwner = '&sendername';
            cContactOwner='';
        }
         
        If(ObjectUtil.isEmpty(campMember.Owner_email__c)){
            OwnerEmail = '&senderemail';
            cOwnerEmail='';
        }
                
        // Create body        
        String requestBody = 'accesstoken=' + token+
                                    '&email=' + EncodeAndChar(cEmail) +
                                    '&listid=' + EncodeAndChar(mailingListID) +                                    
                                    prefix + EncodeAndChar(cPrefix) +
                                    fname + EncodeAndChar(cFname) +
                                    lname + EncodeAndChar(cLname) +
                                    '&status=' + status +                                    
                                    '&categoryid=' + categ +
                                    '&eventid=' + eventID +
                                    '&salesforce_id=' + campMember.Id +                                    
                                    jobTitle + EncodeAndChar(cJobTitle) +
                                    company + EncodeAndChar(cCompany) +
                                    addresLine1 + EncodeAndChar(cAddresLine1) +
                                    city + EncodeAndChar(cCity) +
                                    zip + EncodeAndChar(cZip) +
                                    country + EncodeAndChar(cCountry) +
                                    phone + EncodeAndChar(cPhone) +
                                    mobile + EncodeAndChar(cMobile) +
                                    language + EncodeAndChar(cLanguage) +
                                    contactOwner + EncodeAndChar(cContactOwner) +
                                    ownerEmail + EncodeAndChar(cOwnerEmail);
                                         
        request.setBody(requestBody);
        request.setTimeout(120000);
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);
        return request;
    }
    
    public static HttpResponse createSubscriber(HttpRequest request,  String responseType){
        
        String methodName = 'createSubscriber';
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] :' + request);
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request body] :' + request.getBody());
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[response Type] :' + responseType);
        
        HttpResponse response = postCreateSubscriber_STUB.postCreateSubscriber(request, responseType); 
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    }    
    
     public static HttpResponse updateSubscriber(HttpRequest request,  String responseType){
        
        String methodName = 'updateSubscriber';
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] :' + request);
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request body] :' + request.getBody());
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[response Type] :' + responseType);
               
        HttpResponse response = putUpdateSubscriber_STUB.putUpdateSubscriber(request, responseType);
                
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    } 
    
    public static List<CampaignMember> getListCampaignMember(List<Id> campaignMemberListId){

        String methodName = 'getListCampaignMember';
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[campaignMemberListId ] :' + campaignMemberListId);
        
        List<CampaignMember> listReturn = DM017_etouchesCreateSubscriber.getListByIds(campaignMemberListId);
        
        return listReturn;
    }   
    
        /** 
* @author: JLConsulting
* @date : Creation 06/05/19
* @date : Modification
* @description : this method retrieves the campaign member regarding the attendee ID. Taget process 16204 / 16244.
*/
    public static List<CampaignMember> getListCampaignMemberByAttendeeID (List<String> listAttendeeID){
        
        String methodName = 'getListCampaignMemberByAttendeeID';
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[listAttendeeID ] :' + listAttendeeID);
        List<CampaignMember> listCampaignMemberByAttendeeIDReturned = DM017_etouchesCreateSubscriber.getListByAttendeeID(listAttendeeID);
        
        return listCampaignMemberByAttendeeIDReturned;
    }
    
     public static HttpRequest getPutUpdateDeleteSubscriber(WebserviceParameters__c param_setting, String token, String campMemberId){
        
        String methodName = 'getPutUpdateDeleteSubscriber';
      
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        
        HttpRequest request = getDeleteSubscriber(param_setting, HTTP_METHOD_PUT, PUT_UPDATE_SUBSCRIBER,token,campMemberId);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[request] : ' + request);
        return request;
    } 
    
     private static HttpRequest getDeleteSubscriber(WebserviceParameters__c param_setting, String httpMethod, String expectedWebService, String token, String subscriberID){
        
        String methodName = 'getDeleteSubscriber';
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
        
        HttpRequest request = new HttpRequest();
        
        request.setEndpoint(param_setting.Endpoint__c + expectedWebService);
        request.setMethod(httpMethod);
               
        // Create body        
        String requestBody = 'accesstoken='+token+'&subscriberid='+subscriberID+'&deleted=1';
        request.setBody(requestBody);
        
        request.setTimeout(120000);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);
        return request;
    }
    
    public static List<CampaignMember> getAllCMFromCampaign (Campaign campToTest, List<CampaignMember> cMtofilter){
        
        String methodName = 'getAllCMFromCampaign';
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[Campaign] : ' + campToTest);
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[CampaignMember list ] : ' + cMtofilter);
        List<CampaignMember> listCMreturn = new List<CampaignMember>();
        
        for (CampaignMember cm : cMtofilter){
            if (cm.CampaignId == campToTest.Id ){
                listCMreturn.add(cm);
            }
        }
        
        return  listCMreturn;   
    }
    
   public static List<CampaignMember> getListByContactIds(List<String> contactIds){
        
        String methodName = 'getListByContactIds';
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[contactIds] : ' + contactIds);
        List<CampaignMember> listCMreturn = new List<CampaignMember>();
        
        List<CampaignMember> listReturn = DM017_etouchesCreateSubscriber.getListByContactIds(contactIds);
        
        return listReturn;
    
    }
    
   public static List<CampaignMember> getListByLeadIds(List<String> leadIds){
        
        String methodName = 'getListByLeadIds';
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[leadIds] : ' + leadIds);
        List<CampaignMember> listCMreturn = new List<CampaignMember>();
        
        List<CampaignMember> listReturn = DM017_etouchesCreateSubscriber.getListByLeadIds(leadIds);
        
        return listReturn;  
    }    

    /**
     * @auteur : Youssef MISSAOUI
     * @date : Creation 20/10/2017
     * @date : Modification 20/10/2017
     * @description : Permet d'encoder la chaine de caractère avec '&'.
     * @param : String paramName : chaine a encoder.
     * @return : String
     */
    
     public static String EncodeAndChar(String txt){
         if(txt !=null){
          txt = txt.replace('&', '%26');
         }
         return txt;
     }
}