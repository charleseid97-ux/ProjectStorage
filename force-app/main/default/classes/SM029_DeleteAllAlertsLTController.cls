public class SM029_DeleteAllAlertsLTController {
    
    @AuraEnabled
    public static void deleteAllProspaceAlerts(Id aContactId, List<String> selectedAlertTypes) {
        
        Contact contactRec;
        Lead leadRec;
        
        System.debug('object is '+ aContactId.getsobjecttype());
        
        String objectType = aContactId.getSObjectType().getDescribe().getName();
        
        if(objectType == 'Contact'){
            contactRec = [SELECT Id, WebsiteCountry__c, Prospace_Status__c, TECH_WebSiteID__c FROM Contact WHERE Id = :aContactId];
        }else{
            leadRec = [SELECT Id, WebsiteCountry__c, Prospace_Status__c, TECH_WebSiteID__c FROM Lead WHERE Id = :aContactId];
        }
        
        if(objectType == 'Contact'){
            if(!String.isBlank(contactRec.TECH_WebSiteID__c)){
                SM029_WebCommunication.deleteAllProspaceAlerts(contactRec, selectedAlertTypes);
            }
        }else if(!String.isBlank(leadRec.TECH_WebSiteID__c)){
            SM029_WebCommunication.deleteAllProspaceAlerts(leadRec, selectedAlertTypes);
        } 
        
    }
    
   /*
	*  Get alert type from object
	*/
    @AuraEnabled
    public static Map<String, String> initializePicklistAlertType(Id aContactId){
        System.debug('//NGO initializePicklistAlertType');
        
        String websiteContactLanguage = getWebsiteLanguage(aContactId);
   
        List<AlertType__c> alertTypeList = getSpecificAlertTypeRecords(FALSE);
        
        return mapOptionsAlertTypes(alertTypeList, websiteContactLanguage);

    }
    
    /*
	*  Get alert type from object
	*/
    @AuraEnabled
    public static Map<String, String> initializePicklistAlertTypePub(Id aContactId){
        System.debug('//NGO initializePicklistAlertType');
        
        String websiteContactLanguage = getWebsiteLanguage(aContactId);

        List<AlertType__c> alertTypeList = getSpecificAlertTypeRecords(TRUE);
            
        return mapOptionsAlertTypes(alertTypeList, websiteContactLanguage);
    }
    
    private static List<AlertType__c> getSpecificAlertTypeRecords(Boolean isPublication){
        
        List<AlertType__c> alertTypeList = [SELECT Id, Name, Site__c FROM AlertType__c WHERE Site__c != NULL AND isPublication__c = :isPublication LIMIT 1000];
    	return alertTypeList;
    }
    
    private static String getWebsiteLanguage(Id aContactId){
        
        String objectType = aContactId.getSObjectType().getDescribe().getName();
        String websiteContactLanguage = '';
        
        if(objectType == 'Contact'){
            websiteContactLanguage = [SELECT Id, WebsiteCountryLanguage__c FROM Contact WHERE Id = :aContactId LIMIT 1].WebsiteCountryLanguage__c;
        }else{
            websiteContactLanguage = [SELECT Id, WebsiteCountryLanguage__c FROM Lead WHERE Id = :aContactId LIMIT 1].WebsiteCountryLanguage__c;
        }
        
        return websiteContactLanguage;
    }
    
    private static Map<String, String> mapOptionsAlertTypes(List<AlertType__c> aAlertTypeList, String aContactLanguage){
        
        Map<String, String> options = new Map<String, String>();
        
        for(AlertType__c  alert : aAlertTypeList){
            if(alert.Site__c.contains(aContactLanguage)){
                options.put(alert.Id, alert.Name);
            }
        }
        
        return options;
    }
    
}