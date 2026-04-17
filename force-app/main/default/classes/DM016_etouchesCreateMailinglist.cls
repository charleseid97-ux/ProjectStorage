/** 
* @author: Adolphe SONKO
* @date : Creation 14/03/2017
* @date : Modification 14/03/2017
* @description : his Class allows to Call the Webservices for eTouches create miling list
*/

public class DM016_etouchesCreateMailinglist implements ITF007_POSTCreateMailingListWS{
	
    private static String CLASS_NAME = 'DM016_etouchesCreateMailinglist';
	
		/** 
		* @author: Adolphe SONKO
		* @date : Creation 14/03/2017
		* @date : Modification 14/03/2017
		* @description : This Methods call webservices method
     	* @param : HttpRequest request This param is the HTTP request.
     	* @return : HttpResponse The webservice call response.
    	*/    
    	 	
    public HttpResponse postCreateMailinglist(HttpRequest request,  String responseType){
    	
    	string methodName = 'postCreateMailinglist';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
       	system.debug('ADBS DM016_etouchesCreateMailinglist ' + response.getBody());
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;       	
    }
}