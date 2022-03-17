/** 
* @author: Adolphe SONKO
* @date : Creation 27/02/2017
* @date : Modification 27/02/2017
* @description : this Class allow to manage Campaign Member entity data preparation .
*/

public class EM016_Category {
    
 	private static String CLASS_NAME = 'EM016_Category';
    public static final String EVENT_STATUS = 'Pre-Event';
    private static String HTTP_METHOD_GET = 'GET';
    private static String HTTP_METHOD_PUT = 'PUT';
    private static String HTTP_METHOD_POST = 'POST';
    public static String SETTING_NAME = 'EtouchesAPI';
    private static String GET_ListCategories = '/ereg/listCategories.xml';
    private static String GET_Category = '/ereg/getCategory.xml';
    
    private static ITF009_GETCategoryWS getListCategory_STUB {get {return Etouches_STUB();}}
  
    private static ITF009_GETCategoryWS Etouches_STUB(){
        
        String methodName = 'Etouches_STUB';
        ITF009_GETCategoryWS STUB;
        
        if (Test.isRunningTest()){
            //STUB = new MCK001_WebsiteContactWS();
            //STUB = new MCK001_WebsiteContactWS();
            // BGU NEED Class test for salesforce testing
            STUB = new MCK007_CategoryEvent(); 
            system.debug('ADBS Test Need to developp class');
            
        } else {
        	 
        	 STUB = new DM018_etouchesGetCategory();        	 
        	 system.debug('ADBS arrivé jusquici : method officiel');
        }
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName , '[RESULTS] : ' + STUB);
        return STUB; 
    }
    
    public static void insertCategoryEvent(Campaign campaign, HttpResponse response){
  	
  		String methodName = 'insertCategoryEvent';
  		
  		ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[Campaign] :' + campaign);
  		
  		Map<String,String> mapCategoryNameById = EtouchesXML.getListCategoryID_NAME(response);
  		
        DM018_etouchesGetCategory.createCategoryEvent(campaign, mapCategoryNameById);
  		
  		ObjectUtil.debugLogEnd(CLASS_NAME, methodName , '[RESULTS] :' + mapCategoryNameById);
   }
    
     /**
    * @auteur :Adolphe SONKO
    * @date : Création 15/03/2017
    * @date : Modification 15/03/2017
    * @description : This method create a http request to get category 
    * @param : WebserviceParameters__c param_setting This parameter is the parameterss.
    * @return : HttpRequest The request
    */
    public static HttpRequest getAllCategoryEvent(WebserviceParameters__c param_setting, String Token, String EventID, Campaign campaign){
    	
    	String methodName = 'getAllCategoryEvent';
      
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
    	
    	HttpRequest request = getAllCategory(param_setting, HTTP_METHOD_GET, GET_ListCategories,Token,EventID,campaign);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[request] : ' + request);
    	return request;
    }
    
    
     private static HttpRequest getAllCategory(WebserviceParameters__c param_setting, String httpMethod, String ExpectedWebService, String Token, String EventID, Campaign campaign){
    	
    	String methodName = 'getAllCategory';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[param_setting] : ' + param_setting);
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[httpMethod] : ' + httpMethod);
    	
    	HttpRequest request = new HttpRequest();
    	//request.setEndpoint(param_setting.Endpoint__c + ExpectedWebService);
        request.setMethod(httpMethod);
        
        String Header = param_setting.Endpoint__c + ExpectedWebService +'?accesstoken='+Token+ '&eventid='+EventID;
        request.setEndpoint(Header);
        // Create body       
        
        /* 
        String requestBody = 'accesstoken='+Token+
									//'&name='+campaign.Name+
                                    '&eventid='+EventID;
     
        request.setBody(requestBody);*/
        
        request.setTimeout(120000);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[request] : ' + request);
    	return request;
    }
    
    public static HttpResponse createAllCategory(HttpRequest request,  String responseType){       
        String methodName = 'createAllCategory';
        
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request body] :' + request.getBody());
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[response Type] :' + responseType);
        
        HttpResponse response = getListCategory_STUB.getAllEtouchesCategory(request, responseType); 
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;    
    } 
    
    public static List<Category_Event__c> getListCategoryToInsert(httpResponse responseCategory, Campaign CampToEvent){
    	
    	String methodName = 'getListCategory';
    	
    	ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[httpResponse] : ' + responseCategory);
    	 
    	ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[Campaign] : ' + CampToEvent);
    	
    	Map<String,String> mapCategoryNameById =  EtouchesXML.getListCategoryID_NAME(responseCategory);
    	
    	List<Category_Event__c> categToInster = new List<Category_Event__c>();
    	
    	
    	for (String catId : mapCategoryNameById.keySet())
    	{
    		Category_Event__c tempCateg = new Category_Event__c();
    		
    		tempCateg.Name=mapCategoryNameById.get(catId);
    		
    		tempCateg.Tech_Category_Event_ID_Etouches__c = catId;
    		
    		tempCateg.Campaign__c = CampToEvent.Id;
    		
    		categToInster.add(tempCateg);
    	}
    	
    	
    	return categToInster;
    }
    
 
}