public with sharing class MeetingNotePDFController 
{  
    /*******************************************************************************************************
    * @description Meeting note sObjectType to hold the meeting note record and related records
    *          String type myDomainName to hold the subdomain value
    */
    private final Meeting_Note__c meetingNote;
    private final String myDomainName;
    
    /*******************************************************************************************************
    * @description Class constructor - queries the database for the meeting note and related records and stores it in the class attribute 
    *                    get the subdomain value and store it in the variable myDomainName
    */
    public MeetingNotePDFController() 
    {
        myDomainName= URL.getSalesforceBaseUrl().toExternalForm().substringBefore('--c');
        
        meetingNote = [SELECT Id, 
                       Name,
                       Purpose__c,
                       Meeting_Type__c,
                       Date__c,
                       Note__c,
                       (SELECT Id,
                        Opportunity__c,
                        Opportunity__r.Name,
                        Campaign__c,
                        Campaign__r.Name,
                        Case__c,
                        Case__r.Subject,
                        Contact__c,
                        Contact__r.Name,
                        Employee__c,
                        Employee__r.Name,
                        Account__c,
                        Account__r.Name,
                        Product__c,
                        Product__r.Name
                        FROM Meeting_Links__r)
                   FROM Meeting_Note__c
                   WHERE Id = :ApexPages.currentPage().getParameters().get('id')];
    }
    
    
    /*******************************************************************************************************
    * @description utility method to return the Name of the meeting note for the file name
    * @return meetingNote file name
    */
    @AuraEnabled
    public static String meetingNoteFileName(String meetingNoteId) {
        Meeting_Note__c mNote = [SELECT Name FROM Meeting_Note__c WHERE Id=:meetingNoteId];
        return 'Meeting Note - ' + mNote.Name;
    }
    
    /*******************************************************************************************************
    * @description getter method for class attribute
    * @return meetingNote 
    */
    public Meeting_Note__c getMeetingNote() 
    {
        return meetingNote;
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
    * @description returns PDF as string to lightning controller helper
    * @param url - url with query string parameters
    * @return pdfStr PDF as string
    */    
    @AuraEnabled
    public static String downloadMeetingNote(String url)
    { 
        PageReference pr = new PageReference(url); 
        String pdfStr = EncodingUtil.base64Encode(pr.getContentAsPDF());
        
        return pdfStr;  
    }
}