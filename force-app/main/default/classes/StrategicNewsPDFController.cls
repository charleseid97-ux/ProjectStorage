public with sharing class StrategicNewsPDFController 
{  
    /*******************************************************************************************************
	* @description Meeting note sObjectType to hold the meeting note record and related records
	*          String type myDomainName to hold the subdomain value
	*/
    private final List<StrategicNews__c>  strategicNews;
    private final String myDomainName;
    private final String accountName;
    
    /*******************************************************************************************************
	* @description Class constructor - queries the database for the meeting note and related records and stores it in the class attribute 
	* get the subdomain value and store it in the variable myDomainName
	*/
    public StrategicNewsPDFController() 
    {
        myDomainName= URL.getSalesforceBaseUrl().toExternalForm().substringBefore('--c');
        
        List<Id> snIds = ApexPages.currentPage().getParameters().get('id').split(',');
        accountName = ApexPages.currentPage().getParameters().get('accountName');
        strategicNews = [SELECT Id, 
                         Name,
                         Company__r.Name,
                         Type__c,
                         Subtype__c,
                         Title__c,
                         ShortSubjectDescription__c,
                         StrategicNews__c
                         FROM StrategicNews__c
                         WHERE Id IN :snIds];
        
    }
    
    @AuraEnabled
    public static String SNFileName(String SNId) {
        StrategicNews__c sn = [SELECT Name FROM StrategicNews__c WHERE Id=:SNId];
        return sn.Name;
    }
     
    @AuraEnabled
    public static String ACCFileName(String accId) {
        Account acc = [SELECT Name FROM Account WHERE Id=:accId];
        return acc.Name;
    }        
    
    /*******************************************************************************************************
	* @description getter method for class attribute
	* @return accountPlan
	*/
    public List<StrategicNews__c> getStrategicNews() 
    {
        return strategicNews;
    }
    
    /*******************************************************************************************************
	* @description getter method for class attribute
	* @return myDomainName 
	*/
    public String getMyDomainName()
    {
        return myDomainName;
    }
    
    /*******************************************************************************************************
	* @description getter method for class attribute
	* @return accountName 
	*/
    public String getAccountName()
    {
        return accountName;
    }
    
    /*******************************************************************************************************
	* @description returns PDF as string to lightning controller helper
	* @param url - url with query string parameters
	* @return pdfStr PDF as string
	*/    
    @AuraEnabled
    public static String downloadStrategicNews(String url)
    { 
        PageReference pr = new PageReference(url); 
        String pdfStr = EncodingUtil.base64Encode(pr.getContentAsPDF());
        
        return pdfStr;  
    }
}