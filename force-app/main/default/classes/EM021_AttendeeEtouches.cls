/** 
* @author: Adolphe Sonko
* @date : Creation 27/03/2017
* @date : Modification 27/03/2017
* @description : this Class allow to manage Attendee request for Scan
*/

public class EM021_AttendeeEtouches {
    private static String CLASS_NAME = 'EM021_AttendeeEtouches';
    
	private static String HTTP_METHOD_GET = 'GET';	
	private static String GET_LIST_ATTENDEES = '/ereg/listAttendees.json';
	private static String GET_ATTENDEE = '/ereg/getAttendee.json';

    private static ITF013_GETAttendee getListAttendee_STUB {get {return Etouches_STUB();}}
	
	private static ITF013_GETAttendee Etouches_STUB(){
		
   		String methodName = 'Etouches_STUB';
        ITF013_GETAttendee STUB;
        
        if (Test.isRunningTest()){        	
        	// BGU NEED Class test for salesforce testing
            STUB = new MCK010_AttendeeEtouches(); 
        } else {        	 
        	 STUB = new DM022_eTouchesGetAttendee();        	 
        }
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName , '[RESULTS] : ' + STUB);
        return STUB;   	
   }
	
	public static HttpRequest getAllAttendees(WebserviceParameters__c param_setting, String token, datetime dateToSearch, String EventId, String limits){
		
		String methodName = 'getAllAttendees';
		
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
		
		HttpRequest request = new HttpRequest();
				
    	//Salesforce does not handle the space in the url request. Only the date without the time
    	String stringDate =null;
    	if (dateToSearch != null){
    		stringDate = dateToSearch.format('yyyy-MM-dd');
    	}
    	
		request = getAllAttendeesfromEtouches(param_setting,token,HTTP_METHOD_GET,GET_LIST_ATTENDEES,stringDate,EventId,limits);
				
		request.setTimeout(120000);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] : ' + request);
		return request;
	}
	
	private static HttpRequest getAllAttendeesfromEtouches(WebserviceParameters__c param_setting, String token,String httpMethod, String expectedWebService,String lastmodifieddate, String eventId, String limits){
				
		String methodName = 'getAllAttendeesfromEtouches';
		
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
		
		HttpRequest request = new HttpRequest();
		
		String requestURL;
		
		if(lastmodifieddate !=null){
			requestURL = param_setting.Endpoint__c + expectedWebService +	
						'?accesstoken='+token+
            			'&eventid='+eventId+
            			'&limit='+limits+
						+
						'&modifiedfrom='+lastmodifieddate;
			
		}
        else
		{			
			requestURL = param_setting.Endpoint__c + expectedWebService +	
						'?accesstoken='+token+
            			'&eventid='+eventId+
            			'&limit='+limits;
		}
		
		ObjectUtil.debugLog(CLASS_NAME, methodName , '[requestURL] : ' + requestURL); 
						
		request.setMethod(httpMethod);
		request.setEndpoint(requestURL);
		request.setTimeout(120000);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] : ' + request); 
        
		return request;		
	} 	
	
	public static HttpRequest getAllAttendeesX(WebserviceParameters__c param_setting, String token, datetime dateToSearch, String eventId, String limits, String offset){
		
		String methodName = 'getAllAttendees';
		
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
		
		HttpRequest request = new HttpRequest();
				
    	//BGU Salesforce does not handle the space in the url request. Only the date without the time
    	String stringDate =null;
        
    	if (dateToSearch != null){
    		stringDate = dateToSearch.format('yyyy-MM-dd');
    	}
		request = getAllAttendeesfromEtouchesX(param_setting,token,HTTP_METHOD_GET,GET_LIST_ATTENDEES,stringDate,eventId,limits, offset);
		request.setTimeout(120000);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] : ' + request);
		return request;
	}
	
	private static HttpRequest getAllAttendeesfromEtouchesX(WebserviceParameters__c param_setting, String token,String httpMethod, String expectedWebService,String lastmodifieddate, String eventId, String limits, String offset){
				
		String methodName = 'getAllAttendeesfromEtouches';
		
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
		
		HttpRequest request = new HttpRequest();
		
		String requestURL;
		
		if(lastmodifieddate != null){
			requestURL = param_setting.Endpoint__c + expectedWebService +	
						'?accesstoken='+token+
            			'&eventid='+eventId+
            			'&limit='+limits+
            			'&offset='+offset+
						'&modifiedfrom='+lastmodifieddate;
		}else{
			requestURL = param_setting.Endpoint__c + expectedWebService +	
						'?accesstoken='+token+
            			'&eventid='+eventId+
            			'&limit='+limits+
            			'&offset='+offset;
		}
		
		
		ObjectUtil.debugLog(CLASS_NAME, methodName , '[requestURL] : ' + requestURL);
				
		request.setMethod(httpMethod);
		request.setEndpoint(requestURL);
		request.setTimeout(120000);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] : ' + request);
        
		return request;		
	} 

	public static HttpResponse getListAttendee(HttpRequest request,  String responseType){
        
        String methodName = 'getListAttendee';
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] :' + request);      
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[response Type] :' + responseType);
                
        HttpResponse response = getListAttendee_STUB.getListAttendee(request, responseType);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[response] :' + response);
                      
        return response ;    
    } 
    
    public static HttpRequest getAttendees(WebserviceParameters__c param_setting, String token, String eventId, String attendeeid){
		
		String methodName = 'getAttendees';
		
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
		
		HttpRequest request = new HttpRequest();
    	
		request = getAttendeefromEtouches(param_setting,token,HTTP_METHOD_GET,GET_ATTENDEE,eventId,attendeeid);
		
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] :' + request);
        
		return request;
	}
    
    private static HttpRequest getAttendeefromEtouches(WebserviceParameters__c param_setting, String token,String httpMethod, String expectedWebService,String eventId, String attendeeid){
				
		String methodName = 'getAttendeefromEtouches';
		
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
		
		HttpRequest request = new HttpRequest();
		
		String requestURL;
		
		requestURL = param_setting.Endpoint__c + expectedWebService +	
						'?accesstoken='+token+
            			'&eventid='+eventId+
            			'&attendeeid='+attendeeid+
						'&responseArray='+'1';
		
		ObjectUtil.debugLog(CLASS_NAME, methodName, '[requestURL] :' + requestURL);
				
		request.setMethod(httpMethod);
		request.setEndpoint(requestURL);
		request.setTimeout(120000);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] :' + request);
        
		return request;		
	}
    
    public static HttpResponse getAttendee(HttpRequest request,  String responseType){
        
        String methodName = 'getAttendee';
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] :' + request);      
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[response Type] :' + responseType);
                
        HttpResponse response = getListAttendee_STUB.getAttendee(request, responseType);
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[response] :' + response);
                      
        return response ;    
    }
    
}