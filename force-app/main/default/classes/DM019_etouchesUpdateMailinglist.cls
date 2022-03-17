/** 
* @author: Adolphe SONKO
* @date : Creation 15/03/2017
* @date : Modification 15/03/2017
* @description : his Class allows to Call the Webservices for eTouches update miling list
*/

public class DM019_etouchesUpdateMailinglist implements ITF010_PUTUpdateMailingListWS {
     private static String CLASS_NAME = 'DM019_etouchesUpdateMailinglist';
    
    	/** 
		* @author: Adolphe SONKO
		* @date : Creation 15/03/2017
		* @date : Modification 15/03/2017
		* @description : This Methods call webservices method
     	* @param : HttpRequest request This param is the HTTP request.
     	* @return : HttpResponse The webservice call response.
    	*/    
    	 	
    public HttpResponse putUpdateMailinglist(HttpRequest request,  String responseType){
    	
    	string methodName = 'putUpdateMailinglist';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
       	system.debug('ADBS DM019_etouchesUpdateMailinglist ' + response.getBody());
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;       	
    }

}