/** 
* @author: Adolphe Sonko
* @date : Creation 27/03/2017
* @date : Modification 27/03/2017
* @description : his Class allows to Call the Webservices for eTouches get Subscriber
*/

public class DM022_eTouchesGetAttendee implements ITF013_GETAttendee{
    
	private static String CLASS_NAME = 'DM022_eTouchesGetAttendee';
	
	  public HttpResponse getListAttendee(HttpRequest request,  String responseType){
    	
    	string methodName = 'getListAttendee';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
       	system.debug('ADBS DM022_eTouchesGetAttendee getListAttendee ' + response.getBody());
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    	
    }
    
    
      public HttpResponse getAttendee(HttpRequest request,  String responseType){
    	
    	string methodName = 'getAttendee';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
       	system.debug('ADBS DM022_eTouchesGetAttendee  getAttendee ' + response.getBody());
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    	
    }
    
    
}