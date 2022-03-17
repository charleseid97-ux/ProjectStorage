/** 
* @author: Briag GUEMARD
* @date : Creation 27/02/2017
* @date : Modification 27/02/2017
* @description : this Class allow to manage Campaign busness entity data preparation .
*/

public class EM011_Campaign {    
        
    private static String CLASS_NAME = 'EM011_Campaign';
    public static final String EVENT_STATUS = 'Pre-Event';
    private static String HTTP_METHOD_GET = 'GET';
    private static String HTTP_METHOD_PUT = 'PUT';
    private static String HTTP_METHOD_POST = 'POST';
    public static String SETTING_NAME = 'EtouchesAPI';
    private static String PUT_CLONE_WS = '/global/cloneEvent.xml';
    private static String PUT_UPDATE_EVENT = '/ereg/updateEvent.xml';
    private static String POST_CREATE_MAILING_LIST = '/emarketing/createMailinglist.xml';
    private static String PUT_UPDATE_MAILING_LIST = '/emarketing/updateMailinglist.xml';
    	
  	private static ITF006_UpdateEventEtouchesWS putUpdateEventEtouches_STUB {
        get {
            return Etouches1_STUB();
        }
    }

  	private static ITF006_UpdateEventEtouchesWS Etouches1_STUB(){
   		 String methodName = 'Etouches_STUB';
        ITF006_UpdateEventEtouchesWS STUB;
          
        if (Test.isRunningTest()){ 
            STUB = new MCK005_Campaign();            
        } else {
        	 STUB = new DM015_eTouchesUpdateEvent();  
        }
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName , '[RESULTS] : ' + STUB);
        return STUB; 
   }
   
   private static ITF005_PutCloneEtouchesWS putCloneEtouches_STUB {
       get {
           return Etouches2_STUB();
       }
   }
  
   private static ITF005_PutCloneEtouchesWS Etouches2_STUB(){
        
        String methodName = 'Etouches_STUB';
        ITF005_PutCloneEtouchesWS STUB;
        
        if (Test.isRunningTest()){
            STUB = new MCK005_Campaign();
        } else {        	 
        	 STUB = new DM013_eTouchesCloneEvent();   
        }
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName , '[RESULTS] : ' + STUB);
        return STUB;  
    }
       
   private static ITF007_POSTCreateMailingListWS postCreateMailingList_STUB {
       get {
           return Etouches3_STUB();
           }
   }
  
   private static ITF007_POSTCreateMailingListWS Etouches3_STUB(){
        
        String methodName = 'Etouches3_STUB';
        ITF007_POSTCreateMailingListWS STUB;
        
        if (Test.isRunningTest()){
            STUB = new MCK005_Campaign();            
        } else {        	 
        	 STUB = new DM016_etouchesCreateMailinglist(); 
        }
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[RESULTS] : ' + STUB);
        return STUB; 
    }    
    
    private static ITF010_PUTUpdateMailingListWS putUpdateMailingList_STUB {
        get {
            return Etouches4_STUB();
        }
    }
    
    private static ITF010_PUTUpdateMailingListWS Etouches4_STUB(){
        
        String methodName = 'Etouches4_STUB';
        ITF010_PUTUpdateMailingListWS STUB;
        
        if (Test.isRunningTest()){
            STUB = new MCK005_Campaign();   
        } else {        	 
        	 STUB = new DM019_etouchesUpdateMailinglist();  
        }
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[RESULTS] : ' + STUB);
        return STUB;   
    }
  
     public static List<Campaign> getListByIds(Set<id> CampaignsIds){
        
        String methodName = 'getListByIds';    
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[CampaignsIds] :' + CampaignsIds);
        
        List<Campaign> listCampaigns = DM011_Campaign.getListByIds(CampaignsIds);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[listCampaigns] :' + listCampaigns);
        return listCampaigns; 
    }    
    
    /**
    * @auteur :Briag GUEMARD
    * @date : Création 16/03/2017
    * @date : Modification 16/03/2017
    * @description : This method get a list of campaign from a campaign Id list
    * @param : List<ID> of Campaig nobject record
    * @return : List<Campaign>
    */
     public static List<Campaign> getAllListByIds(List<Id> ListcampaignsIds){
        
        String methodName = 'getListByIds';    
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[ListcampaignsIds] :' + ListcampaignsIds);
        
        List<Campaign> listCampaigns = DM011_Campaign.getAllListByIds(ListcampaignsIds);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[listCampaigns] :' + listCampaigns);
        return listCampaigns; 
    }      
  
    /**
    * @auteur :Briag GUEMARD
    * @date : Création 03/03/2017
    * @date : Modification 03/03/2017
    * @description : This method create a http request to clone the Event
    * @param : WebserviceParameters__c param_setting This parameter is the parameterss.
    * @return : HttpRequest The request
    */
    public static HttpRequest getCreatePutCLONE(WebserviceParameters__c param_setting, String token, String templateID,String folderId, String nameEvent){
    	
    	String methodName = 'getAuthRequest';
      
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
    	
    	HttpRequest request = getPutCLONE(param_setting, HTTP_METHOD_PUT, PUT_CLONE_WS,token,templateID,folderId, nameEvent);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);
    	return request;
    }    
    
    public static HttpResponse cloneEvent(HttpRequest request,  String responseType){
        
        String methodName = 'cloneEvent';
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] :' + request);
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request body] :' + request.getBody());
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[response Type] :' + responseType);
        
        HttpResponse response = putCloneEtouches_STUB.putCloneEtouches(request, responseType); 
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[response] :' + response);              
        return response ;    
    }  
 
 	 /**
    * @auteur :Briag GUEMARD
    * @date : Création 09/03/2017
    * @date : Modification 09/03/2017
    * @description : This method create a http request to update an event
    * @param : WebserviceParameters__c param_setting This parameter is the parameterss.
    * @return : HttpRequest The request
    */    
    public static HttpRequest getPutUpateEvent(WebserviceParameters__c param_setting, String token,Campaign camp, String etouchesID, User owner1, User crmSales){
    	
    	String methodName = 'getPutUpateEvent';
      
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);    
        
    	HttpRequest request = getPutEvent(param_setting, HTTP_METHOD_PUT, PUT_UPDATE_EVENT,token,camp,etouchesID,owner1,crmSales);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);
    	return request;
    } 
     
    public static HttpResponse upateEvent(HttpRequest request,  String responseType){
        
        String methodName = 'upateEvent';
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] :' + request);
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request body] :' + request.getBody());
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[response Type] :' + responseType);
               
        HttpResponse response = putUpdateEventEtouches_STUB.putUpdateEventEtouches(request, responseType);         
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[response] :' + response);              
        return response ;    
    }
    
    public static HttpRequest getPostCreateMailingList(WebserviceParameters__c param_setting, String token, String eventID, Campaign campaign){
    	
    	String methodName = 'getPostCreateMailingList';
      
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
    	
    	HttpRequest request = getCreateMailingList(param_setting, HTTP_METHOD_POST, POST_CREATE_MAILING_LIST,token,eventID,campaign);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);
    	return request;
     }
    
    public static HttpResponse createMailinglist(HttpRequest request,  String responseType){
        
        String methodName = 'createMailinglist';
        
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request body] :' + request.getBody());
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[response Type] :' + responseType);
        
        HttpResponse response = postCreateMailingList_STUB.postCreateMailinglist(request, responseType); 
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[response] :' + response);              
        return response ;    
     } 

     public static void updateEtouhcheData(Campaign campaign, String Etouches_Event_ID,HttpResponse response ){
  	
  	    String methodName = 'updateEtouhcheData';
  		
  		ObjectUtil.debugLog(CLASS_NAME, methodName , '[campaign input ] :' + campaign);
  		
  		DM011_Campaign.setEtoucheEventID(campaign,Etouches_Event_ID);  		
  		ObjectUtil.debugLog(CLASS_NAME, methodName , '[campaign after DM011_Campaign.setEtoucheEventID] :' + campaign);
  		
  		// Update Campaign => DM 
  		String Etouches_Mailinglist_ID = EtouchesXML.getMailinglistID(response);
  		DM011_Campaign.setEtouchesData(campaign,Etouches_Mailinglist_ID,Etouches_Event_ID);  		
  		ObjectUtil.debugLog(CLASS_NAME, methodName , '[campaign after DM011_Campaign.setEtouchesData] :' + campaign); 
    }

    public static HttpRequest getPutUpdateMailingList(WebserviceParameters__c param_setting, String token, Campaign campaign){
    	
    	String methodName = 'getPutUpdateMailingList';
      
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
    	
    	HttpRequest request = putUpdateMailingList(param_setting, HTTP_METHOD_PUT, PUT_UPDATE_MAILING_LIST,token,campaign);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);
    	return request;
    }     
    
    public static HttpResponse updateMailinglist(HttpRequest request,  String responseType){
        
        String methodName = 'updateMailinglist';
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] :' + request);
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request body] :' + request.getBody());
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[response Type] :' + responseType);
        
        HttpResponse response = putUpdateMailingList_STUB.putUpdateMailinglist(request, responseType); 
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    } 

    public static List<String> ListMailingListID(List<String> ListEventID){

    	String methodName = 'ListMailingListID';
    	 
    	ObjectUtil.debugLog(CLASS_NAME, methodName , '[ListEventID] :' + ListEventID);
    	 
    	List<String> ListMailingListID = new List<String>();
    	
    	ListMailingListID = DM011_Campaign.getMailingListIdsByEventID(ListEventID) ;
    	
    	return ListMailingListID;
    }
    
    public static List<Campaign> ListEvent(Set<String> ListEtouchesEventID){

    	String methodName = 'ListEvent';
    	 
    	ObjectUtil.debugLog(CLASS_NAME, methodName , '[ListEtouchesEventID] :' + ListEtouchesEventID);
    	 
    	List<Campaign> ListEvent = new List<Campaign>();
    	
    	ListEvent = DM011_Campaign.getEventListIdsByEventID(ListEtouchesEventID) ;
    	
    	return ListEvent;
    }
    
    public static List<Campaign> ListCampaign(List<String> ListEtouchesEventID){

    	String methodName = 'ListEvent';
    	 
    	ObjectUtil.debugLog(CLASS_NAME, methodName , '[ListEtouchesEventID] :' + ListEtouchesEventID);
    	 
    	List<Campaign> ListEvent = new List<Campaign>();
    	
    	ListEvent = DM011_Campaign.getEventListsByEventID(ListEtouchesEventID) ;
    	
    	return ListEvent;
    }
    
    public static Campaign campaignByEtouchesEventID(String EtouchesEventID, List<Campaign> listCampToSearch){

    	String methodName = 'campaignByEtouchesEventID';
    	 
    	ObjectUtil.debugLog(CLASS_NAME, methodName , '[campaignByEtouchesEventID] :' + EtouchesEventID);
    	 
    	Campaign campaignReturn = new Campaign();
    	
    	for ( Campaign campsearched : listCampToSearch){
    		
    		if(campsearched.Event_code_Etouches__c == EtouchesEventID){
    			campaignReturn = campsearched;
    		}
    	}
    	
    	return campaignReturn;    	
    }
    
    public static List<Campaign> getEventListsByScheduleId(List<String> List_ID_Schedule){

    	String methodName = 'getEventListsByScheduleId';
    	 
    	ObjectUtil.debugLog(CLASS_NAME, methodName , '[List_ID_Schedule] :' + List_ID_Schedule);
    	 
    	List<Campaign> ListEvent = new List<Campaign>();
    	
    	ListEvent = DM011_Campaign.getEventListsByScheduleId(List_ID_Schedule) ;
    	
    	return ListEvent;
    }
    
    public static Campaign getCampaignByID(String CampaignID){
        String methodName = 'getCampaignByID';
    	 
    	ObjectUtil.debugLog(CLASS_NAME, methodName , '[CampaignID] :' + CampaignID);
    	 
    	Campaign camp = new Campaign();
    	
    	camp = DM011_Campaign.getCampaignByID(CampaignID) ;
    	
    	return camp;
    }
    
     private static HttpRequest getPutCLONE(WebserviceParameters__c param_setting, String httpMethod, String expectedWebService, String token,String templateID,String folderId,String nameEvent){
    	
    	String methodName = 'getPutCLONE';
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
    	
    	HttpRequest request = new HttpRequest();
    	
    	request.setEndpoint(param_setting.Endpoint__c + expectedWebService);
        request.setMethod(httpMethod); 
         
        String requestBody = 'accesstoken='+token+'&eventid='+templateID+'&folderid='+folderId+'&name='+nameEvent;
		
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[requestBody] : ' + requestBody);
         
     	request.setTimeout(120000);
        request.setBody(requestBody);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);
    	return request;
    }
    
    private static HttpRequest getPutEvent(WebserviceParameters__c param_setting, String httpMethod, String expectedWebService, String token, Campaign camp, String etouchesID,User owner1, User crmSales){
    	
    	String methodName = 'getPutEvent';
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
    	
    	HttpRequest request = new HttpRequest();
    	
     	system.debug(camp.Start_Date_Time__c);     	
     	
     	String requestURL;
     	
     	datetime myStartDate = camp.Start_Date_Time__c;     	
     	datetime myEndDate = camp.End_Date_Time__c;
              	
     	String etouchesStartDate;
        String etouchesStartTime;
        String etouchesEndDate;
        String etouchesEndTime;
        
         if(!ObjectUtil.isEmpty(camp.Event_Local_Start_Time__c)){
             etouchesStartDate = camp.Event_Local_Start_Time__c.substringBefore(' ');
             etouchesStartTime = camp.Event_Local_Start_Time__c.substringAfter(' ');
         }
         
         if(!ObjectUtil.isEmpty(camp.Event_Local_End_Time__c)){
             etouchesEndDate = camp.Event_Local_End_Time__c.substringBefore(' ');
             etouchesEndTime = camp.Event_Local_End_Time__c.substringAfter(' ');
         }
         
     	String stringStartDate;
     	String stringStartTime;
     	String stringEndDate;
     	String stringEndTime;
     	
     	if (myEndDate != null){
     		stringEndDate = myEndDate.format('yyyy-MM-dd');
    	 	stringEndTime = myEndDate.format('kk:mm');
     	}
     	
     	if(myStartDate != null){
     		stringStartDate = myStartDate.format('yyyy-MM-dd');
    	    stringStartTime = myStartDate.format('kk:mm');
     	}    	 
    	
    	String ClosedDate_str;
    	String ClosedTime_str;
    	 
    	datetime ClosedDate = camp.Registration_Closed_Date__c;
    	if(ClosedDate != null){
    			ClosedDate_str = ClosedDate.format('yyyy-MM-dd');
    	 		ClosedTime_str = ClosedDate.format('kk:mm');    		
    	}

        String replace = '&';
        String target = '%26';

        String name = String.isEmpty(camp.name) ? '&name' : '&name=' + camp.name.replace(replace, target);
        String locationname = String.isEmpty(camp.Location_name__c) ? '&locationname' : '&locationname=' + camp.Location_name__c;
        String MaximumRegistration = String.isEmpty(String.valueOf(camp.Maximum_registration__c)) ? '&max_reg' : '&max_reg=' + camp.Maximum_registration__c;
        String Addres1 = String.isEmpty(camp.Address_1__c) ? '&address1' : '&address1=' + camp.Address_1__c;
        String Addres2 = String.isEmpty(camp.Address_2__c) ? '&address2' : '&address2=' + camp.Address_2__c;
        String City = String.isEmpty(camp.City__c) ? '&city' : '&city=' + camp.City__c;
        String Country = String.isEmpty(camp.Country__c) ? '&country' : '&country=' + camp.Country__c;
        String Zip = String.isEmpty(camp.Post_Code__c) ? '&postcode' : '&postcode=' + camp.Post_Code__c;
        String ProgramManager = String.isEmpty(owner1.Name) ? '&programmanager' : '&programmanager=' + owner1.Name;
        String ClientContact = String.isEmpty(CrmSales.Name) ? '&clientcontact' : '&clientcontact=' + CrmSales.Name;
        String maptovenue = String.isEmpty(camp.Map_to_Venue__c) ? '&map' : '&map=' + camp.Map_to_Venue__c;
        String timezoneid = String.isEmpty(camp.Local_zone__c) ? '&timezoneid' : '&timezoneid=' + camp.Local_zone__c;
        String closedate = String.isEmpty(ClosedDate_str) ? '&closedate=' : '&closedate=' + ClosedDate_str;
        String closetime = String.isEmpty(ClosedTime_str) ? '&closetime=' : '&closetime=' + ClosedTime_str;


        requestURL = param_setting.Endpoint__c + ExpectedWebService + '?accesstoken=' + token;


        String requestBody = 'eventid=' + etouchesID +
                name +
                '&startdate=' + etouchesStartDate +
                '&starttime=' + etouchesStartTime +
                '&enddate=' + etouchesEndDate +
                '&endtime=' + etouchesEndTime +
                locationname +
                Addres1 +
                Addres2 +
                Zip +
                City +
                ProgramManager +
                ClientContact +
                Country +
                maptovenue +
                MaximumRegistration +
                timezoneid +
                closedate +
                closetime;
	
		ObjectUtil.debugLog(CLASS_NAME, methodName, '[request url] : ' + requestURL); 
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request body] : ' + requestBody); 
	
     	request.setBody(requestBody);
    	request.setEndpoint(requestURL);
        request.setMethod(httpMethod);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);        
        
        request.setTimeout(120000);
    	return request;      	
    }    
    
    
    private static HttpRequest putUpdateMailingList(WebserviceParameters__c param_setting, String httpMethod, String expectedWebService, String token, Campaign campaign){
    	
    	String methodName = 'putUpdateMailingList';
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
    	
    	HttpRequest request = new HttpRequest();
    	String status = 'Active';
         
        String requestURL = param_setting.Endpoint__c + expectedWebService + '?accesstoken='+token;
         
        String replace = '&';
        String target = '%26';
        String nameEvent =campaign.Name;
         
        String  nameEvent2 = nameEvent.replace(replace,target);
               
        // Create body        
        String requestBody = 'name='+nameEvent2+
            								'&listid='+campaign.TECH_Mailing_List_ID_Etouches__c+
            								'&status='+status+
            								'&created='+campaign.CreatedDate+
            								'&lastmodified='+campaign.LastModifiedDate+
            								'&eventid='+campaign.Event_code_Etouches__c;
        request.setEndpoint(requestURL);
        request.setMethod(httpMethod);     
        request.setBody(requestBody);
        request.setTimeout(120000);
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);
    	return request;
    }
    
    private static HttpRequest getCreateMailingList(WebserviceParameters__c param_setting, String httpMethod, String expectedWebService, String token, String eventID, Campaign campaign){
    	
    	String methodName = 'getCreateMailingList';
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
    	
    	HttpRequest request = new HttpRequest();
    	String status = 'Active';
    	request.setEndpoint(param_setting.Endpoint__c + expectedWebService);
        request.setMethod(httpMethod);
         
        String replace = '&';
        String target = '%26';
        String nameEvent =campaign.Name;
         
        String  nameEvent2 = nameEvent.replace(replace,target);
        
        // Create body        
        String requestBody = 'accesstoken=' + token+
            								'&name=' + nameEvent2+
            								'&status=' + status+
            								'&created=' + campaign.CreatedDate+
            								'&lastmodified=' + campaign.LastModifiedDate+
            								'&eventid=' + eventID;
     
        request.setBody(requestBody);
        request.setTimeout(120000);
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);
    	return request;
    }  
    
}