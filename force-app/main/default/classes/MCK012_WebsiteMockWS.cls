public class MCK012_WebsiteMockWS {
    
    private static String CLASS_NAME = 'MCK012_WebsiteMockWS';
    
    public HttpResponse syncContact(HttpRequest request,  String requestType, String status){
        
        String methodName = 'syncContact';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        
        if(status=='success'){
            response.setStatusCode(200);
            response.setStatus('OK'); 
            
            if(requestType == 'POST'){
                response.setBody('{"error":0,"message":"success", "id":"9999"}');
            }else{
                response.setStatusCode(400);
                response.setStatus('KO'); 
                response.setBody('{"error":1,"message":"fail"}');
            }   
        }       
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    } 
    
    
    public HttpResponse syncWebCommunication(HttpRequest request,  String requestType, String status, Web_Communication__c aWebCom){
        
        String methodName = 'syncContact';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        
        if(status=='success'){
            
            
            if(requestType == 'POST'){
                response.setStatusCode(200);
                response.setStatus('OK'); 
                if(aWebCom.Contact__c != null){
                    response.setBody('{"error":0,"message":"success","TEST":"success", "successRecords":[], "errorRecords":[{ "SalesForceId":"'+aWebCom.Contact__c+'", "ReferenceId":"003_Carmingnac"}] }');
                }
            }else{
                response.setBody('{"error":0,"message":"success","TEST":"success", "errorRecords":[], "successRecords":[{ "SalesForceId":"'+aWebCom.Contact__c+'", "ReferenceId":"003_Carmingnac"}] }');
            }   
        }
        
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    }     
    
}