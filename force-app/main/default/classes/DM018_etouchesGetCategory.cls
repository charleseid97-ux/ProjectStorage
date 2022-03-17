/** 
* @author: Adolphe SONKO
* @date : Creation 15/03/2017
* @date : Modification 15/03/2017
* @description : his Class allows to Call the Webservices for eTouches create miling list
*/

public class DM018_etouchesGetCategory implements ITF009_GETCategoryWS{
    private static String CLASS_NAME = 'DM018_etouchesGetCategory';
	
		/** 
		* @author: Adolphe SONKO
		* @date : Creation 15/03/2017
		* @date : Modification 15/03/2017
		* @description : This Methods call webservices method
     	* @param : HttpRequest request This param is the HTTP request.
     	* @return : HttpResponse The webservice call response.
    	*/    
    	 	
    public HttpResponse getAllEtouchesCategory(HttpRequest request,  String responseType){
    	
    	string methodName = 'getAllEtouchesCategory';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
       	system.debug('ADBS DM018_etouchesGetCategory ' + response.getBody());
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;       	
    }
    
    
     public static void createCategoryEvent(Campaign campaign, Map<String,String> mapCategoryNameByIds){
        
        String methodName = 'createCategoryEvent';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Campaign] :' + campaign);
         
        List<Category_Event__c> listCategoryEvent = new List<Category_Event__c>(); 
        For(String catId: mapCategoryNameByIds.keySet()){
             
             Category_Event__c categoryEvent = new Category_Event__c();  
       		 categoryEvent.Name = mapCategoryNameByIds.get(catId);
       		 categoryEvent.Campaign__c  = campaign.Id ;
        	 categoryEvent.Tech_Category_Event_ID_Etouches__c = catId;
             
             listCategoryEvent.add(categoryEvent);
         }        
        
        insert listCategoryEvent;
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCategoryEvent);         
    }
}