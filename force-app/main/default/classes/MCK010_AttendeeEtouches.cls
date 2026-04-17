/** 
* @author: Adolphe Sonko
* @date : Creation 14/04/2017
* @date : Modification  14/04/2017
* @description : This Class allows to Simule etouches authorization webservices calls.
*/
public with sharing class MCK010_AttendeeEtouches implements ITF013_GETAttendee{
    
    private static String CLASS_NAME = 'MCK010_AttendeeEtouches';
       
    public static HttpResponse getListAttendee(HttpRequest request,  String responseType){
        
        String methodName = 'getListAttendee';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
        response.setBody('{"error":{"data":"No attendees found.","help":"http:\\developer.etouches.com\\ehome\\50138\\get-list-attendees\"}}');
        response.setStatusCode(200);
        response.setStatus('OK');   
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    } 
    
    
   public static HttpResponse getAttendee(HttpRequest request,  String responseType){
        
        String methodName = 'getAttendee';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
       response.setBody('{"attendeeid":"1234","categoryid":"1","name":"Category Test 1","registrationstatus":"Confirmed","lastmodified":"2014-10-06 14:10:31","responses":[{"fieldname":"email","response":"mail@mail1.com"},{"fieldname":"fname","response":"TestFName"},{"fieldname":"lname","response":"LastNameTestCarmignac"}]}');
        response.setStatusCode(200);
        response.setStatus('OK');  
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    }
}