/** 
* @author: Briag GUEMARD
* @date : Creation 06/03/2017
* @date : Modification 06/03/2017
* @description : his Class allows to Call the Webservices for eTouches clone event
*/

public class DM013_eTouchesCloneEvent implements ITF005_PutCloneEtouchesWS {
	
	private static String CLASS_NAME = 'DM013_eTouchesCloneEvent';
    
		/** 
		* @author: Briag GUEMARD
		* @date : Creation 06/03/2017
		* @date : Modification 06/03/2017
		* @description : This Methods call webservices method
     	* @param : HttpRequest request This param is the HTTP request.
     	* @return : HttpResponse The webservice call response.
    	*/    
    
    public HttpResponse putCloneEtouches(HttpRequest request,  String responseType){
        
        String methodName = 'putCloneEtouches';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
       	system.debug('BGU DM013_eTouchesCloneEvent ' + response.getBody());
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    } 
    
    
}