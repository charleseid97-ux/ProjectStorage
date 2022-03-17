/** 
* @author: Adolphe Sonko
* @date : Creation 10/04/2017
* @date : Modification  10/04/2017
* @description : This Class allows to Simule etouches authorization webservices calls.
*/
public with sharing class MCK006_CampaignMember implements ITF008_POSTCreateSubscriberWS {
	
    private static String CLASS_NAME = 'MCK006_CampaignMember';
    
    
    public static HttpResponse postCreateSubscriber(HttpRequest request,  String responseType){
        
        String methodName = 'postCreateSubscriber';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
        //response.setBody('{"subscriberid":"72320755"}');
        response.setBody('<etouches><subscriberid>72320755</subscriberid></etouches>');
        response.setStatusCode(200);
        response.setStatus('OK');   
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    } 
    
    
     public static HttpResponse putUpdateSubscriber(HttpRequest request,  String responseType){
        
        String methodName = 'putUpdateSubscriber';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
     //   response.setBody('{"subscriberid":"72320755"}');
        response.setBody('<etouches><subscriberid>72320755</subscriberid></etouches>');
        response.setStatusCode(200);
        response.setStatus('OK');  
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    } 
}