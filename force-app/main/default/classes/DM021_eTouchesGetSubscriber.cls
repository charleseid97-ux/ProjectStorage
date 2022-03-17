/** 
* @author: Adolphe Sonko
* @date : Creation 27/03/2017
* @date : Modification 27/03/2017
* @description : his Class allows to Call the Webservices for eTouches get Subscriber
*/
public class DM021_eTouchesGetSubscriber implements ITF012_GETSubscriber{
    
	private static String CLASS_NAME = 'DM021_eTouchesGetSubscriber';
	
	  public HttpResponse getListSubscriber(HttpRequest request,  String responseType){
    	
    	string methodName = 'getListSubscriber';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
       	system.debug('ADBS DM021_eTouchesGetSubscriber getListSubscriber ' + response.getBody());
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    	
    }
    
    
      public HttpResponse getSubscriber(HttpRequest request,  String responseType){
    	
    	string methodName = 'getSubscriber';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
       	system.debug('ADBS DM021_eTouchesGetSubscriber  getSubscriber ' + response.getBody());
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    	
    }

}