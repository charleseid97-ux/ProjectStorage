/** 
* @author: Adolphe Sonko
* @date : Creation 14/04/2017
* @date : Modification  14/04/2017
* @description : This Class allows to Simule etouches authorization webservices calls.
*/
public with sharing class MCK009_SubscriberEtouches implements ITF012_GETSubscriber{
    
    private static String CLASS_NAME = 'MCK009_SubscriberEtouches';
       
    public static HttpResponse getListSubscriber(HttpRequest request,  String responseType){
        
        String methodName = 'getListSubscriber';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
        response.setBody('[{"subscriberid":"72320736","email":"test@test-carmignac.com","fname":"Adolphe","lname":"SONKO"}]');
        response.setStatusCode(200);
        response.setStatus('OK');   
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    } 
    
    
   public static HttpResponse getSubscriber(HttpRequest request,  String responseType){
        
        String methodName = 'getSubscriber';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
        response.setBody('{"categoryid":"1234","name":"Category Test 1"}');
        response.setStatusCode(200);
        response.setStatus('OK');   
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    }
}