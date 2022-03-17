/** 
* @author: Adolphe Sonko
* @date : Creation 14/04/2017
* @date : Modification  14/04/2017
* @description : This Class allows to Simule etouches authorization webservices calls.
*/
public with sharing class MCK011_BounceEtouches implements ITF014_GETBounce{

    private static String CLASS_NAME = 'MCK011_BounceEtouches';
       
    public static HttpResponse getAllBounce(HttpRequest request,  String responseType){
        
        String methodName = 'getListSubscriber';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
        response.setBody('[{"email":"test1@test.com","code":"550"},{"email":"test2@test.com","code":"553"}]');
        response.setStatusCode(200);
        response.setStatus('OK');   
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    } 
}