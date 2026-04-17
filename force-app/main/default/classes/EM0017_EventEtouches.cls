/** 
* @author: Briag GUEMARD
* @date : Creation 22/03/2017
* @date : Modification 22/03/2017
* @description : this Class allow to manage Event request fro Scan
*/


public class EM0017_EventEtouches {

	private static String HTTP_METHOD_GET = 'GET';
	
	private static String GET_LIST_EVENT = '/global/listEvents.json';
    private static String GET_EVENT = '/ereg/getEvent.json';
	private static String GET_MAILING_LIST = '/emarketing/listMailinglists.json';
	private static String CLASS_NAME = 'EM0017_EventEtouches';
	
	
	private static ITF011_GETEvent getListEvent_STUB {get {return Etouches1_STUB();}}
	
	private static ITF011_GETEvent Etouches1_STUB(){
		
   		String methodName = 'Etouches1_STUB';
        ITF011_GETEvent STUB;
        
        if (Test.isRunningTest()){
        	
        	// BGU NEED Class test for salesforce testing
            STUB = new MCK008_EventEtouches();
            //STUB = new MCK001_WebsiteContactWS();
                        
            system.debug('BGU Test Need to developp class');
            
        } else {
        	 
        	 STUB = new DM020_eTouchesGetEvent();
        	 
        	 system.debug('BGU arrivé jusquici : method officiel');
        }
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName , '[RESULTS] : ' + STUB);
        return STUB;
   	
   }
	
	public static HttpRequest getAllEventEtouches(WebserviceParameters__c param_setting, String token, datetime dateToSearch){
		
		String methodName = 'getAllEventEtouches';
		
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
		
		HttpRequest request = new HttpRequest();
		
		
		//String stringDate = dateToSearch.format('yyyy-MM-dd kk:mm:ss');
    	//BGU Salesforce does not handle the space in the url request. Only the date without the time
    	String stringDate = dateToSearch.format('yyyy-MM-dd');
    	
		request = getAllEventFromEtouches(param_setting, token ,HTTP_METHOD_GET,GET_LIST_EVENT,stringDate);
		
		request.setTimeout(120000);
		
		return request;
	}
	
	public static HttpRequest getAllEventEtouchesOne(WebserviceParameters__c param_setting, String token, String EventId){
		
		String methodName = 'getAllEventEtouches';
		
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
		
		HttpRequest request = new HttpRequest();
		
		
    	
		//request = getAllEventFromEtouchesOne(param_setting, token ,HTTP_METHOD_GET,GET_LIST_EVENT,EventId);
        //ASO 04/05/2017
        request = getAllEventFromEtouchesOne(param_setting, token ,HTTP_METHOD_GET,GET_EVENT,EventId);
		
		request.setTimeout(120000);
		
		return request;
	}
	
	private static HttpRequest getAllEventFromEtouchesOne(WebserviceParameters__c param_setting, String token,String httpMethod, String ExpectedWebService,String EventId){
				
		String methodName = 'getAllEventFromEtouches';
		
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
		
		HttpRequest request = new HttpRequest();
		
		request.setTimeout(120000);
		
		String requestURL;
	
    /*    requestURL = param_setting.Endpoint__c + ExpectedWebService +	
						'?accesstoken='+token+
						'&fields=name,eventid,status,startdate,starttime,enddate,endtime,timezone,description,max_reg,closedate,closetime,location,programmanager,clientcontact,lastmodified'
						+
						'&search=eventid='+EventId; */
        
        	requestURL = param_setting.Endpoint__c + ExpectedWebService +	
						'?accesstoken='+token+
						'&eventid='+EventId;
		//bgu
						
		system.debug('BGU requestURL   ' + requestURL);
		
			//request.setBody('search=lastmodified>='+Lastmodifieddate);			
		request.setMethod(httpMethod);
		request.setEndpoint(requestURL);
		
		return request;
		
	} 
	
	
	private static HttpRequest getAllEventFromEtouches(WebserviceParameters__c param_setting, String token,String httpMethod, String ExpectedWebService,String Lastmodifieddate){
				
		String methodName = 'getAllEventFromEtouches';
		
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
		
		HttpRequest request = new HttpRequest();
		
		request.setTimeout(120000);
		
		String requestURL;
		
		requestURL = param_setting.Endpoint__c + ExpectedWebService +	
						'?accesstoken='+token+
						'&fields=name,eventid,status,lastmodified'
						+
						'&search=lastmodified>='+Lastmodifieddate;
		//bgu
						
		system.debug('BGU requestURL   ' + requestURL);
		
			//request.setBody('search=lastmodified>='+Lastmodifieddate);			
		request.setMethod(httpMethod);
		request.setEndpoint(requestURL);
		
		return request;
		
	} 
	
	
	public static HttpRequest getLivePreEventtEtouches(WebserviceParameters__c param_setting, String token){
		
		String methodName = 'getLivePreEventtEtouches';
		
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
		
		HttpRequest request = new HttpRequest();
		
		
				    	
		request = getLivePreEventFromEtouches(param_setting, token ,HTTP_METHOD_GET,GET_LIST_EVENT);
		
		request.setTimeout(120000);
		
		return request;
	}
	
	
	private static HttpRequest getLivePreEventFromEtouches(WebserviceParameters__c param_setting, String token,String httpMethod, String ExpectedWebService){
		
		
		String methodName = 'getLivePreEventFromEtouches';
		
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
		
		HttpRequest request = new HttpRequest();
		
		String requestURL;
		
		requestURL = param_setting.Endpoint__c + ExpectedWebService +	
						'?accesstoken='+token+
						'&fields=name,eventid,status&search=status=Pre-Event||Live';
						
		request.setMethod(httpMethod);
		request.setEndpoint(requestURL);
		
		request.setTimeout(120000);
		
		return request;
		
	} 
	
	 public static HttpResponse getListEvent(HttpRequest request,  String responseType){
        
        String methodName = 'getListEvent';
        
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
      
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[response Type] :' + responseType);
                
        HttpResponse response = getListEvent_STUB.getListEvent(request, responseType);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);
                      
        return response ;    
    } 

    public static HttpResponse getEvent(HttpRequest request,  String responseType){
        
        String methodName = 'getListEvent';
        
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
      
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[response Type] :' + responseType);
                
        HttpResponse response = getListEvent_STUB.getEvent(request, responseType);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);
                      
        return response ;    
    } 
    
/** 
* @author: Adolphe Sonko
* @date : Creation 28/03/2017
* @date : Modification 28/03/2017
*/
	public static HttpRequest getAllMailingListEtouches(WebserviceParameters__c param_setting, String token, datetime dateToSearch){
		
		String methodName = 'getAllEventEtouches';
		
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
		
		HttpRequest request = new HttpRequest();
		
		//String stringDate = dateToSearch.format('yyyy-MM-dd kk:mm:ss');
    	//BGU Salesforce does not handle the space in the url request. Only the date without the time
    	String stringDate = dateToSearch.format('yyyy-MM-dd');
    	
		request = getAllMailingListFromEtouches(param_setting, token ,HTTP_METHOD_GET,GET_MAILING_LIST,stringDate);
		
		
		request.setTimeout(120000);
		return request;
	}
	
	
	private static HttpRequest getAllMailingListFromEtouches(WebserviceParameters__c param_setting, String token,String httpMethod, String ExpectedWebService,String Lastmodifieddate){
				
		String methodName = 'getAllMailingListFromEtouches';
		
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
		
		HttpRequest request = new HttpRequest();
		
		String requestURL;
		
		requestURL = param_setting.Endpoint__c + ExpectedWebService +	
						'?accesstoken='+token+
						'&fields=listid,name,eventid,status,folderid,lastmodified'
						+
						'&search=lastmodified>='+Lastmodifieddate;
		//bgu
						
		system.debug('BGU requestURL   ' + requestURL);
		
			//request.setBody('search=lastmodified>='+Lastmodifieddate);			
		request.setMethod(httpMethod);
		request.setEndpoint(requestURL);
		request.setTimeout(120000);
		return request;
		
	}     
     public static HttpResponse getListMailingList(HttpRequest request,  String responseType){
        
        String methodName = 'getListSubscriber';
        
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
      
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[response Type] :' + responseType);
                
        HttpResponse response = getListEvent_STUB.getListMailingList(request, responseType);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);
                      
        return response ;    
    }    

	
    
}