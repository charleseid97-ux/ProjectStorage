/** 
* @author: Adolphe Sonko
* @date : Creation 10/04/2017
* @date : Modification  10/04/2017
* @description : This Class allows to Simule etouches authorization webservices calls.
*/
public with sharing class MCK005_Campaign implements ITF005_PutCloneEtouchesWS, ITF006_UpdateEventEtouchesWS, ITF007_POSTCreateMailingListWS, ITF010_PUTUpdateMailingListWS{
	
    private static String CLASS_NAME = 'MCK005_Campaign';
    
    
    public static HttpResponse putCloneEtouches(HttpRequest request,  String responseType){
        
        String methodName = 'putCloneEtouches';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
     //   response.setBody('{"eventid":"188118","description":"New event successfully created (New event ID: 188118)"}');
        response.setBody('<etouches><eventid>188118</eventid><description>New event successfully created (New event ID: 188118)</description></etouches>');
        response.setStatusCode(200);
        response.setStatus('OK');   
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    } 
    
    public static HttpResponse putUpdateEventEtouches(HttpRequest request,  String responseType){
        
        String methodName = 'putUpdateEventEtouches';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
        response.setBody('<etouches><description>Event successfully updated on 2017-04-16 12:12:32 (Event ID: 188118)</description></etouches>');
        response.setStatusCode(200);
        response.setStatus('OK');   
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    } 
        
   public static HttpResponse postCreateMailinglist(HttpRequest request,  String responseType){
        
        String methodName = 'postCreateMailinglist';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
        response.setBody('<etouches><listid>85540</listid></etouches>');
        response.setStatusCode(200);
        response.setStatus('OK');   
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    } 
    
     public static HttpResponse putUpdateMailinglist(HttpRequest request,  String responseType){
        
        String methodName = 'putUpdateMailinglist';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
      //  response.setBody('{"listid":"85540"}');
        response.setBody('<etouches><listid>85540</listid></etouches>');
        response.setStatusCode(200);
        response.setStatus('OK');   
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    } 
}