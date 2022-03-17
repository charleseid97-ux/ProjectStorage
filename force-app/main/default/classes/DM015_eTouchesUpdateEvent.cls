/** 
* @author: Briag GUEMARD
* @date : Creation 13/03/2017
* @date : Modification 13/03/2017
* @description : his Class allows to Call the Webservices for eTouches update event
*/

public class DM015_eTouchesUpdateEvent implements  ITF006_UpdateEventEtouchesWS{
	
	
	private static String CLASS_NAME = 'DM015_eTouchesUpdateEvent';
	
	
		/** 
		* @author: Briag GUEMARD
		* @date : Creation 13/03/2017
		* @date : Modification 13/03/2017
		* @description : This Methods call webservices method
     	* @param : HttpRequest request This param is the HTTP request.
     	* @return : HttpResponse The webservice call response.
    	*/    
    	
    	
    public HttpResponse putUpdateEventEtouches(HttpRequest request,  String responseType){
    	
    	string methodName = 'putUpdateEventEtouches';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
       	system.debug('BGU DM015_eTouchesUpdateEvent ' + response.getBody());
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    	
    }
    
}