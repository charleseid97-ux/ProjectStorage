/** 
* @author: Briag GUEMARD
* @date : Creation 28/02/2017
* @date : Modification 28/02/2017
* @description : his Class allows to Call the Webservices Auth for eTouches authent
*/

public class DM012_eTouchesAuthWS implements ITF004_eTouchesAuthWS {
	
	private static String CLASS_NAME = 'DM012_eTouchesAuthWS';
    
		/** 
		* @author: Briag GUEMARD
		* @date : Creation 28/02/2017
		* @date : Modification 28/02/2017
		* @description : This Methods call webservices method
     	* @param : HttpRequest request This param is the HTTP request.
     	* @return : HttpResponse The webservice call response.
    	*/
  /*  public HttpResponse getAuthEtouches(HttpRequest request,  String responseType){
        
        String methodName = 'getAuthEtouches';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
      
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    }  */
    
    
    public HttpResponse createAuthEtouches(HttpRequest request,  String responseType){
        
        String methodName = 'createAuthEtouches';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
        
        
       	system.debug('BGU DM012_eTouchesAuthWS ' + response.getBody());
        
       
             
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    } 
    
    
}