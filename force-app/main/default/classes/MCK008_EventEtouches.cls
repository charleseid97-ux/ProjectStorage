/** 
* @author: Adolphe Sonko
* @date : Creation 14/04/2017
* @date : Modification  14/04/2017
* @description : This Class allows to Simule etouches authorization webservices calls.
*/
public with sharing class MCK008_EventEtouches implements ITF011_GETEvent{
    
	private static String CLASS_NAME = 'MCK008_EventEtouches';
       
    public static HttpResponse getListEvent(HttpRequest request,  String responseType){
        
        String methodName = 'getListEvent';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
        response.setBody('[{"eventid":"73997","name":"Anniversaire Julie"},{"eventid":"95108","name":"Old Template_Quarterly Meeting"},{"eventid":"96359","name":"Lily Webinar_Summer Funds Celebration"}]');
        response.setStatusCode(200);
        response.setStatus('OK');   
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    } 
    
    public static HttpResponse getEvent(HttpRequest request,  String responseType){
        
        String methodName = 'getEvent';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
   //     response.setBody('{"eventid":"187895","accountid":"4740","folderid":"43168","name":"Campaign Test Button ASONKO 10h50","city":"PAris","startdate":"2017-05-09","enddate":"2017-05-09","include_calendar":"0","timezoneid":"30","status":"Pre-Event","event_type":null,"description":null,"programmanager":"Etouches Interface","defaultlanguage":"ita","createdby":"0","deleted":"0","country":"France","modifiedby":"etouchesapi","locationname":"3eme etage","state":"","url":"https:\\qa.eiseverywhere.com/187895","max_reg":"0","statusmessage":null,"clientcontact":"null","lodgingnotes":null,"location":{"name":"","address1":"Opera","address2":"allemagne","address3":"","city":"PAris","state":"","postcode":"75001","country":"France","phone":"","email":"","map":"www.carmignac.com"},"starttime":"12:00:00","endtime":"18:00:00","closedate":"0000-00-00","closetime":null,"timezonedescription":null,"foldername":"FRANCE","eventclosemessage":" We thank you for your interest in our event. However, we are sorry but the registration is now closed.If you wish to participate in our event, please contact: contactinfo","timezone":"[GMT+01:00] Brussels, Copenhagen, Madrid, Paris","createddatetime":"2017-05-11 04:52:20","modifieddatetime":"2017-05-11 04:52:24","login1":"email","login2":"attendeeid"}');
        response.setBody('{"eventid":"187895","accountid":"4740","folderid":"43168","name":"Campaign Test Button ASONKO 10h50","city":"PAris","startdate":"2017-05-09","enddate":"2017-05-09","timezoneid":"30","status":"Pre-Event","event_type":null,"description":null,"programmanager":"Etouches Interface","country":"France","modifiedby":"etouchesapi","locationname":"3eme etage","state":"","url":"https:qa.eiseverywhere.com/187895","max_reg":"0"}');
        response.setStatusCode(200);
        response.setStatus('OK');   
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    } 
    
    public static HttpResponse getListMailingList(HttpRequest request,  String responseType){
        
        String methodName = 'getListMailingList';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
        response.setBody('[{"listid":"85467","name":"Campaign Test Button ASONKO 10h50","status":"Active","folderid":"0","eventid":"187895"}]');
        response.setStatusCode(200);
        response.setStatus('OK');   
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    } 
}