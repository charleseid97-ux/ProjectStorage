/** 
* @author: Adolphe Sonko
* @date : Creation 10/04/2017
* @date : Modification  10/04/2017
* @description : This Class allows to Simule etouches authorization webservices calls.
*/
public with sharing class MCK007_CategoryEvent implements ITF009_GETCategoryWS {
	
     private static String CLASS_NAME = 'MCK007_CategoryEvent';
    
    public static HttpResponse getAllEtouchesCategory(HttpRequest request,  String responseType){
        
        String methodName = 'getAllEtouchesCategory';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
        response.setBody('<etouches><item><categoryid>201</categoryid><parentid>0</parentid><name>Event Exhibitor</name></item><item><categoryid>202</categoryid><parentid>0</parentid><name>Event Staff</name></item></etouches>');
        response.setStatusCode(200);
        response.setStatus('OK');   
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ; 
    } 
}