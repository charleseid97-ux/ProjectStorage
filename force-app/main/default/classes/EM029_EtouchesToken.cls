public class EM029_EtouchesToken {
    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();    
    private static String CLASS_NAME = 'EM029_EtouchesToken';
    private static String HTTP_METHOD_GET = 'GET';
    private static String AUTH_WS = '/global/authorize.format?';    
    public static String SETTING_NAME = 'EtouchesAPI';
    public static String REFRESH_TOKEN = '';
    
    public static String getNewToken()
    {	
    	String methodName  = 'getNewToken';
	    String accessToken = '' ;

        if (String.isBlank(REFRESH_TOKEN)) {

            WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(SETTING_NAME);
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [param_setting] : ' + param_setting);
            HttpRequest request = new HttpRequest();
            request = getCreateAuthRequest(param_setting);
            request.setTimeout(120000);
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [request] : ' + request);
            HttpResponse response = createAuth(request, null);
            if (response.getStatusCode() != 200 || response.getBody().contains('error')) {

                //Interface Log
                String fullResp = ' - Response: ' + response +
                        ' / Response body: ' + response.getBody() +
                        ' /  Response getStatus: ' + response.getStatus() +
                        ' /  Response getStatusCode: ' + response.getStatusCode();

                String fullReq = ' - Request : ' + request ;
                String recordData = ' - Token Etouches : ';

                String Data = 'Class name :' + CLASS_NAME + '  Get Token in Etouches - Methodname : '
                        + methodName + recordData
                        + fullReq ;

                EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
                newErro.dateCreate = Datetime.now();
                newErro.interfaceName = 'Etouches';
                newErro.Data = Data;
                newErro.error = fullResp;
                listLogError.add(newErro);
                //EM023_Log.insertLogError(listLogError);
            } else {
                ObjectUtil.debugLog(CLASS_NAME, methodName, '[response] : ' + response);
                accessToken = response.getBody();
                //Parse Token
                JSONParser parser = JSON.createParser(accessToken);
                // Advance to the start object marker.
                parser.nextToken();
                // Advance to the next value.
                parser.nextValue();
                // Get the arrival time.
                REFRESH_TOKEN = parser.getText();
                ObjectUtil.debugLog(CLASS_NAME, methodName, '[REFRESH_TOKEN] : ' + REFRESH_TOKEN);
            }
        }


        return REFRESH_TOKEN;
    }
    
    private static HttpRequest getCreateAuthRequest(WebserviceParameters__c param_setting){
    	
    	String methodName = 'getAuthRequest';
      
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        
    	HttpRequest request = getAuthRequest(param_setting, HTTP_METHOD_GET, AUTH_WS); 
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);
    	return request;
    } 
    
    private static HttpRequest getAuthRequest(WebserviceParameters__c param_setting, String httpMethod, String ExpectedWebService){
    	
    	String methodName = 'getAuthRequest';
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
           	
    	HttpRequest request = new HttpRequest();
    	request.setEndpoint(param_setting.Endpoint__c + ExpectedWebService + 'accountid='+param_setting.accountid__c+ '&key='+param_setting.key__c);
        request.setMethod(httpMethod);        
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);
        
        request.setTimeout(120000);
        
    	return request;
    }    
    
     private static HttpResponse createAuth(HttpRequest request,  String responseType){
        
        String methodName = 'createAuth';
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[request] :' + request);
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[responseType] :' + responseType);
        
        HttpResponse response = authEtouches_STUB.createAuthEtouches(request, responseType); 
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[response] :' + response);              
        return response ;    
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
           STUB = new MCK004_eTouchesAuthWS();                     
        } else {        	 
        	 STUB = new DM012_eTouchesAuthWS();  
        }
        
        ObjectUtil.debugLog(CLASS_NAME, methodName , '[RESULTS] : ' + STUB);
        return STUB; 
    }
}