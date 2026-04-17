/** 
* @author: Briag GUEMARD
* @date : Creation 22/03/2017
* @date : Modification 22/03/2017
* @description : his Class allows to Call the Webservices for eTouches get event
*/

public class DM020_eTouchesGetEvent implements  ITF011_GETEvent{
	
	
	private static String CLASS_NAME = 'DM020_eTouchesGetEvent';
	
	  public HttpResponse getListEvent(HttpRequest request,  String responseType){
    	
    	string methodName = 'getListEvent';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
       	system.debug('BGU DM020_eTouchesGetEvent getListEvent ' + response.getBody());
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    	
    }
    
    
      public HttpResponse getEvent(HttpRequest request,  String responseType){
    	
    	string methodName = 'getEvent';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
       	system.debug('BGU DM020_eTouchesGetEvent  getEvent ' + response.getBody());
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    	
    }

  public HttpResponse getListMailingList(HttpRequest request,  String responseType){
    	
    	string methodName = 'getListMailingList';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
       	system.debug('ADBS DM020_eTouchesGetEvent getListMailingList ' + response.getBody());
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    	
    }
 
}