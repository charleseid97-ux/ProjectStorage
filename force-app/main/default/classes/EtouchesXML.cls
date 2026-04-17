/** 
* @author: Briag GUEMARD
* @date : Creation 09/03/2017
* @date : Modification 09/03/2017
* @description : this Class allow to manage xml reponse from etouches busness entity data preparation .
*/

public class EtouchesXML {
		
	private static String CLASS_NAME = 'EtouchesXML';
    private static String XmlBaliseItem = 'item';
	private static String XmlBaliseEventId = 'eventid';
    private static String XmlBaliseMailinglistId = 'listid';
    private static String XmlBaliseCategoryId = 'categoryid';
    private static String XmlBaliseCategoryName = 'name';
    private static String XmlBaliseSubscriberId = 'subscriberid';
    
    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();
	
	public static String getEventID(HttpResponse response){		
		
		String methodName = 'getEventID';    
		String EventID;
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[HttpResponse] :' + response.getBody());
		
		Dom.Document doc = response.getBodyDocument();
		
		Dom.XMLNode etouches = doc.getRootElement();
		
		EventID = etouches.getChildElement(XmlBaliseEventId, null).getText();
    	 
    	ObjectUtil.debugLog(CLASS_NAME, methodName , '[EventID] :' + EventID);
		
		return EventID;
	}
	
	
	public static String getSubscriberID(HttpResponse response){		
		
		String methodName = 'getSubscriberID';    
		String SubscriberID;
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[response body] :' + response.getBody());
		
		Dom.Document doc = response.getBodyDocument();		
		Dom.XMLNode etouches = doc.getRootElement();
        
        try
        { 
		  SubscriberID = etouches.getChildElement(XmlBaliseSubscriberId, null).getText();
		  ObjectUtil.debugLog(CLASS_NAME, methodName, '[SubscriberID] :' + SubscriberID);		   
        } 
        catch(Exception e)
        {  
        	EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
        	newErro.dateCreate = Datetime.now();
        	newErro.interfaceName ='Etouches';
        	newErro.Data = response.getBody();
        	newErro.error = e.getStackTraceString();
		        	
        	listLogError.add(newErro); 
        }       
		
		return SubscriberID;
	}
    
    
   /**
    * @auteur :Adolphe SONKO
    * @date : Création 14/03/2017
    * @date : Modification 14/03/2017
    * @description : This method get the etouches mailig list ID
    */
	public static String getMailinglistID(HttpResponse response){

        String methodName = 'getMailinglistID';    
		String MailinglistID;
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[response body] :' + response.getBody());
		
		Dom.Document doc = response.getBodyDocument();		
		Dom.XMLNode etouches = doc.getRootElement();
		
		MailinglistID = etouches.getChildElement(XmlBaliseMailinglistId, null).getText();
			
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[MailinglistID] :' + MailinglistID);		
        
		return MailinglistID;
	}
    
   /**
    * @auteur :Adolphe SONKO
    * @date : Création 15/03/2017
    * @date : Modification 15/03/2017
    * @description : This method get the etouches mailig list ID
    */
    public static Map<String,String> getListCategoryID_NAME(HttpResponse response){
				
		String methodName = 'getListCategoryID_NAME';    
		String CategoryID;
        String CategoryName;
        List<String> listCategoryIds = new List<String>();
        List<String> listCategoryNames = new List<String>();
        Map<String,String> mapCategoryNameById = new Map<String,String>();
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[response body] :' + response.getBody());
		
		Dom.Document doc = response.getBodyDocument();		
		Dom.XMLNode etouches = doc.getRootElement();
        
        for(Dom.XmlNode node: etouches.getChildElements()){
            if(node.getName() == XmlBaliseItem){ 
                 for(Dom.XmlNode subnode: node.getChildElements()){
                    if(subnode.getName() == XmlBaliseCategoryId){                     
                     	  CategoryID = subnode.getText();
                          listCategoryIds.add(CategoryID);
                        ObjectUtil.debugLog(CLASS_NAME, methodName, '[CategoryID] :' + CategoryID);                        
                    }    
                    if(subnode.getName() == XmlBaliseCategoryName){                       
                        CategoryName = subnode.getText();
                        listCategoryNames.add(CategoryName);                       
                        ObjectUtil.debugLog(CLASS_NAME, methodName, '[listCategoryNames] :' + listCategoryNames);  
                    } 
                }
            }                       
            mapCategoryNameById.put(CategoryID, CategoryName);
        }        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[mapCategoryNameById] :' + mapCategoryNameById.keySet()); 
		return mapCategoryNameById;
	}
}