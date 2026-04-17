/** 
* @author: Adolphe Sonko
* @date : Creation 10/04/2017
* @date : Modification  10/04/2017
* @description : This Class allows to Simule etouches authorization webservices calls.
*/
public with sharing class MCK004_eTouchesAuthWS implements ITF004_eTouchesAuthWS {
    
    private static String CLASS_NAME = 'MCK004_eTouchesAuthWS';
    

    /**
     * @auteur : Trotto Stéphane
     * @date : Création 13/09/2016
     * @date : Modification 13/09/2016
     * @description : This Methods call webservices method of contact creation
     * @param : HttpRequest request This param is the HTTP request.
     * @return : HttpResponse The webservice call response.
     */
    public HttpResponse createAuthEtouches(HttpRequest request,  String responseType){
        
        String methodName = 'deactivateContact';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        // Create Manually json response For Test Class
        HttpResponse response = new HttpResponse();
        // This Section will be completed after website webservices developpements
        
        response.setBody('{"accesstoken":"123456789ABCDEFGH"}');
        response.setStatusCode(200);
        response.setStatus('OK');
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    }
}