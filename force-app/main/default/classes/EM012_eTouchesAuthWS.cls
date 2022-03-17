/** 
* @author: Briag Guemard
* @date : Creation 27/02/2017
* @date : Modification 27/02/2017
* @description : This Class allows to prepare data for Etouches Auth webservices.
*/

public   class EM012_eTouchesAuthWS {
    
    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();
    
    private static String CLASS_NAME = 'EM012_eTouchesAuthWS';
    //private static String HTTP_METHOD_POST = 'POST';
    //private static String HTTP_METHOD_PUT = 'PUT';
    //private static String HTTP_METHOD_DELETE = 'DELETE';
    private static String HTTP_METHOD_GET = 'GET';
    private static String AUTH_WS = '/global/authorize.format?';
    //Custom Setting Name, Webservice Parameters
    public static String SETTING_NAME = 'EtouchesAPI';
    
    /**
     * @auteur : Briag Guemard
     * @date : Creation 06/03/2017
     * @date : Modification 06/03/2017 
     * @description : Set the new token 
     * @return : eTouches token.
     */
    
    @future(callout=true)
    public static void getToken()
    {	
    	String methodName = 'getToken';
	    String accessToken='';
    	
    	WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(SETTING_NAME);
    	
    	system.debug('BGU param_setting - getAuthorize : ' + param_setting);
    	
    	HttpRequest request1 = new HttpRequest();
    	
    	request1 = getCreateAuthRequest(param_setting);
    	
    	request1.setTimeout(120000);
    	
    	system.debug('BGU  request bad: ' + request1.getBody());
    	system.debug('BGU  request bad: ' + request1);    	

    	HttpResponse response1 = createAuth(request1, null); 
    	
    	if(response1.getStatusCode()!= 200 || response1.getBody().contains('error')){
        	
        	//Interface Log        	
        	 	
    		String fullResp = ' - Response: ' + response1 + 
    		' / Response body: ' + response1.getBody()+
    		' /  Response getStatus: ' + response1.getStatus()+
    		' /  Response getStatusCode: ' + response1.getStatusCode();        	
        	
        	String fullReq = ' - Request : ' + request1 ;
        	
        	String recordData = ' - Token Etouches : ';
        	
        	String Data =  'Class name :' + CLASS_NAME + '  Get Token in Etouches - Methodname : '
        	 + methodName + recordData
        	+ fullReq ;
        	        	        	
        	EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
        	newErro.dateCreate = Datetime.now();
        	newErro.interfaceName = 'Get Token in Etouches';
        	newErro.Data = Data;
        	newErro.error = fullResp;
		        	
        	listLogError.add(newErro);
        	
        	EM023_Log.insertLogError(listLogError); 
        }
        else
        {        	
        	ObjectUtil.debugLogEnd(CLASS_NAME, methodName , '[response body] : ' + response1.getBody());
        	ObjectUtil.debugLogEnd(CLASS_NAME, methodName , '[response ] : ' + response1);
        	    		
	    	accessToken = response1.getBody();
	    	   	
	    	//Parse Token
	    	JSONParser parser = JSON.createParser(accessToken);
			// Advance to the start object marker.
			parser.nextToken();
			// Advance to the next value.
			parser.nextValue();
			// Get the arrival time.
			String cleanToken = parser.getText();
	
			system.debug('BGU cleanToken: ' + cleanToken);
	    	
	    	EM013_Token.setToken(cleanToken);
        }
    }
    
  	private static ITF004_eTouchesAuthWS authEtouches_STUB {
        get {
            return Etouches_STUB();
        }
    }
   
    private static ITF004_eTouchesAuthWS Etouches_STUB(){
        
        String methodName = 'Etouches_STUB';
        ITF004_eTouchesAuthWS STUB;
        
        if (Test.isRunningTest()){
            //STUB = new MCK001_WebsiteContactWS();
            //STUB = new MCK001_WebsiteContactWS();
            // BGU NEED Class test for salesforce testing
           STUB = new MCK004_eTouchesAuthWS();
            system.debug('BGU Test Need to developp class');
            
        } else {
        	 
        	 STUB = new DM012_eTouchesAuthWS();
        	 
        	 system.debug('BGU arrivé jusquici : method officiel');
        }
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName , '[RESULTS] : ' + STUB);
        return STUB; 
    }
    
    /**
    * @auteur :Briag GUEMARD
    * @date : Création 27/02/2017
    * @date : Modification 27/02/2017
    * @description : This method create a http request.
    * @param : WebserviceParameters__c param_setting This parameter is the parameterss.
    * @return : HttpRequest The request
    */
    public static HttpRequest getCreateAuthRequest(WebserviceParameters__c param_setting){
    	
    	String methodName = 'getAuthRequest';
      
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
    	
    	HttpRequest request = getAuthRequest(param_setting, HTTP_METHOD_GET, AUTH_WS);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[request] : ' + request);
    	return request;
    } 
    
    public static HttpRequest getAuthRequest(WebserviceParameters__c param_setting, String httpMethod, String ExpectedWebService){
    	
    	String methodName = 'getAuthRequest';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
    	
    	HttpRequest request = new HttpRequest();
    	
    	request.setEndpoint(param_setting.Endpoint__c + ExpectedWebService + 'accountid='+param_setting.accountid__c+ '&key='+param_setting.key__c);
        request.setMethod(httpMethod);        
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[request] : ' + request);
        
        request.setTimeout(120000);
        
    	return request;
    }    
    
     public static HttpResponse createAuth(HttpRequest request,  String responseType){
        
        String methodName = 'createAuth';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[responseType] :' + responseType);
        
        HttpResponse response = authEtouches_STUB.createAuthEtouches(request, responseType); 
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    }     
}