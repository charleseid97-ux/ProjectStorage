/** 
* @author: Adolphe Sonko
* @date : Creation 27/03/2017
* @date : Modification 27/03/2017
* @description : this Class allow to manage Subscriber request for Scan
*/

public class EM018_SubscriberEtouches {
    
	private static String CLASS_NAME = 'EM018_SubscriberEtouches';    
	private static String HTTP_METHOD_GET = 'GET';	
	private static String GET_LIST_EVENT = '/emarketing/listSubscribers.json';
	private static ITF012_GETSubscriber getListEvent_STUB {get {return Etouches_STUB();}}
	
	private static ITF012_GETSubscriber Etouches_STUB(){
		
   		String methodName = 'Etouches_STUB';
        ITF012_GETSubscriber STUB;
        
        if (Test.isRunningTest())
        {   
            STUB = new MCK009_SubscriberEtouches();      
                        
            system.debug('Test Need to developp class');            
        } 
        else 
        {        	 
        	 STUB = new DM021_eTouchesGetSubscriber();
        	 
        	 system.debug('arrivé jusquici : method officiel');
        }
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName , '[RESULTS] : ' + STUB);
        return STUB;   	
   }
	
	public static HttpRequest getAllSubscribers(WebserviceParameters__c param_setting, String token, datetime dateToSearch, String listid, String limits){
		
		String methodName = 'getAllSubscribers';
		
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
		
		HttpRequest request = new HttpRequest();		
		
    	//BGU Salesforce does not handle the space in the url request. Only the date without the time
    	String stringDate =null;
        
    	if (dateToSearch != null)
        {
    		stringDate = dateToSearch.format('yyyy-MM-dd');
    	} 
    	
		request = getAllSubscribersfromEtouches(param_setting,token,HTTP_METHOD_GET,GET_LIST_EVENT,stringDate,listid,limits);
		request.setTimeout(120000);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] : ' + request);
		
		return request;
	}
	
	public static HttpRequest getAllSubscribersX(WebserviceParameters__c param_setting, String token, datetime dateToSearch, String listid, String limits, String OffSet){
		
		String methodName = 'getAllSubscribers';
		
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
		
		HttpRequest request = new HttpRequest();	
		
    	//BGU Salesforce does not handle the space in the url request. Only the date without the time
    	String stringDate =null;
    	if (dateToSearch != null)
        {
    		stringDate = dateToSearch.format('yyyy-MM-dd');
    	}  
    	
		request = getAllSubscribersfromEtouchesX(param_setting,token,HTTP_METHOD_GET,GET_LIST_EVENT,stringDate,listid,limits, OffSet);
		
		request.setTimeout(120000);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] : ' + request);
		
		return request;
	}
	
	private static HttpRequest getAllSubscribersfromEtouchesX(WebserviceParameters__c param_setting, String token,String httpMethod, String ExpectedWebService,String Lastmodifieddate, String listid, String limits, String OffSet){
				
		String methodName = 'getAllSubscribersfromEtouches';
		
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
		
		HttpRequest request = new HttpRequest();
		
		String requestURL;
        
		requestURL = param_setting.Endpoint__c + ExpectedWebService +	
						'?accesstoken='+token+
            			'&listid='+listid+            			
            			'&fields=subscriberid,email,fname,lname,status'+
            			'&search=status!=Subscribed'+
            			'&offset='+OffSet;	

        ObjectUtil.debugLog(CLASS_NAME, methodName , '[requestURL] : ' + requestURL);
				
		request.setMethod(httpMethod);
		request.setEndpoint(requestURL);		
		request.setTimeout(120000);
        
		ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] : ' + request);
		return request;		
	}	
	
	private static HttpRequest getAllSubscribersfromEtouches(WebserviceParameters__c param_setting, String token,String httpMethod, String expectedWebService,String lastmodifieddate, String listid, String limits){
				
		String methodName = 'getAllSubscribersfromEtouches';
		
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
		
		HttpRequest request = new HttpRequest();
		
		String requestURL;
		if (Lastmodifieddate !=null)
        {				
			requestURL = param_setting.Endpoint__c + expectedWebService +	
							'?accesstoken='+token+
	            			'&listid='+listid+	            			
							'&fields=subscriberid,email,fname,lname,status'+
							'&search=lastmodified>='+lastmodifieddate;				
		}
        else
        {				
			requestURL = param_setting.Endpoint__c + expectedWebService +	
							'?accesstoken='+token+
	            			'&listid='+listid+	            			
							'&fields=subscriberid,email,fname,lname,status'+'&search=status!=Subscribed';			
		}		
			
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[requestURL] : ' + requestURL);
				
		request.setMethod(httpMethod);
		request.setEndpoint(requestURL);		
		request.setTimeout(120000);
        
		ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] : ' + request);
        
		return request;		
	}	

	 public static HttpResponse getListSubscriber(HttpRequest request,  String responseType){
        
        String methodName = 'getListSubscriber';
        
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);      
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[response Type] :' + responseType);                
        HttpResponse response = getListEvent_STUB.getListSubscriber(request, responseType);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[response] :' + response);
                      
        return response ;    
    } 
    
      public static List<CampaignMember> getListByCampaignIds(List<Id> listcampaignsIds){
        
        String methodName = 'getListByCampaignIds';    
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[ListcampaignsIds] :' + listcampaignsIds);
        
        List<CampaignMember> listCampaignMembers = DM017_etouchesCreateSubscriber.getListByCampaignIds(listcampaignsIds);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[listCampaignMembers] :' + listCampaignMembers);
        return listCampaignMembers; 
    }
    
     public static List<CampaignMember> getListByCampaignMemberByMail(List<String> listMailCM){
        
        String methodName = 'getListByCampaignMemberByMail';    
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[ListMailCM] :' + ListMailCM);
        
        List<CampaignMember> listCampaignMembers = DM017_etouchesCreateSubscriber.getListByAttendeeEmail(listMailCM);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[listCampaignMembers] :' + listCampaignMembers);
        return listCampaignMembers; 
    }
 
   public static List<CampaignMember> getListBySubscriberIds(Set<String> subscriberIds){
        
        String methodName = 'getListBySubscriberIds';    
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[SubscriberIds] :' + subscriberIds);
        
        List<CampaignMember> listCampaignMembers = DM017_etouchesCreateSubscriber.getListBySubscriberIds(subscriberIds);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[listCampaignMembers] :' + listCampaignMembers);
        return listCampaignMembers; 
    }
    
    public static CampaignMember getCMByUpdateAttendee(WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber updateSubscriber){
         String methodName = 'getCMByUpdateAttendee';    
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[updateSubscriber] :' + updateSubscriber);
        
        CampaignMember campMember = DM017_etouchesCreateSubscriber.getCMByUpdateAttendee(updateSubscriber);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[CampMember] :' + campMember);
        return CampMember; 
    } 
}