public with sharing class AccountPlanPDFController 
{  
    /*******************************************************************************************************
    * @description Meeting note sObjectType to hold the meeting note record and related records
    *          String type myDomainName to hold the subdomain value
    */
    private final Account_Plan__c accountPlan;
    private final List<Account_Plan_Objective__c> objectives;
    private final List<Account_Plan_Objective__c> previous_objectives;
    private final List<Opportunity> openOpportunities;
    private final String myDomainName;
    
    /*******************************************************************************************************
    * @description Class constructor - queries the database for the meeting note and related records and stores it in the class attribute 
    * get the subdomain value and store it in the variable myDomainName
    */
    public AccountPlanPDFController() 
    {
        myDomainName= URL.getSalesforceBaseUrl().toExternalForm().substringBefore('--c');
        
        accountPlan = [SELECT Id, 
                       Name,
                       Previous_Account_Plan__c,
                       Executive_Summary__c,
                       Third_Party_Fund_Architecture__c,
                       Company__r.Name,
                       Revenue_Potential__c,
                       (SELECT Id,
                        Strength__c,
                        Strength_Type__c,
                        Weakness__c,
                        Weakness_Type__c
                        FROM Strengths_and_Weaknesses__r),
                       (SELECT Id,
                        Threat__c,
                        Threat_Type__c
                        FROM Threats__r)
                   FROM Account_Plan__c
                   WHERE Id = :ApexPages.currentPage().getParameters().get('id')];

	        accountPlan.Executive_Summary__c = formatEndOfLine(accountPlan.Executive_Summary__c);
            accountPlan.Third_Party_Fund_Architecture__c = formatEndOfLine(accountPlan.Third_Party_Fund_Architecture__c);
        objectives = [SELECT Id,
                      Name,
                      Optional_Related_Company__r.Name,
                      Objective_Type__c,
                      Priority__c,
                      Due_Date__c,
                      (SELECT Subject, Status, ActivityDate FROM Tasks),
                      (SELECT Company__r.Name FROM Account_Plan_Objective_Companies__r)
                      FROM Account_Plan_Objective__c 
                      WHERE Account_Plan__c = :ApexPages.currentPage().getParameters().get('id')];
        
        for(Account_Plan_Objective__c aPO : objectives) {
            if(aPO.Optional_Related_Company__r != null) {
                if(aPO.Optional_Related_Company__r.Name.length() > 20) { 
                    aPO.Optional_Related_Company__r.Name = aPO.Optional_Related_Company__r.Name.substring(0,20)+'...';
                }
            }
            //if(aPO.Name.length() > 25) {
            //    aPO.Name = aPO.Name.substring(0,25)+'...';
            //}
        }

        previous_objectives = [SELECT Id,
                Name,
                Optional_Related_Company__r.Name,
                Objective_Type__c,
                Priority__c,
                Due_Date__c,
        (SELECT Subject, Status, ActivityDate FROM Tasks),
        (SELECT Company__r.Name FROM Account_Plan_Objective_Companies__r)
        FROM Account_Plan_Objective__c
        WHERE Account_Plan__c = :accountPlan.Previous_Account_Plan__c];

        for(Account_Plan_Objective__c aPO : previous_objectives) {
            if(aPO.Optional_Related_Company__r != null) {
                if(aPO.Optional_Related_Company__r.Name.length() > 20) {
                    aPO.Optional_Related_Company__r.Name = aPO.Optional_Related_Company__r.Name.substring(0,20)+'...';
                }
            }
            //if(aPO.Name.length() > 25) {
            //    aPO.Name = aPO.Name.substring(0,25)+'...';
            //}
        }
        
        openOpportunities = AccountPlanCtrl.getOpenOpportunities(ApexPages.currentPage().getParameters().get('id'));
    }

    private static String formatEndOfLine(String value){
        String result = '';
        if(String.isNotBlank(value)) result = value.replaceAll('\n', '<br/>');
        return result;
    }
    
    @AuraEnabled
    public static String accPlanFileName(String accPlanId) {
        Account_Plan__c accPlan = [SELECT Name FROM Account_Plan__c WHERE Id=:accPlanId];
        return accPlan.Name;
    }
    
    /*******************************************************************************************************
    * @description getter method for class attribute
    * @return accountPlan
    */
    public Account_Plan__c getAccountPlan() 
    {
        return accountPlan;
    }
    
    /*******************************************************************************************************
    * @description getter method for class attribute
    * @return accountPlan
    */
    public List<Account_Plan_Objective__c> getObjectives() 
    {
        return objectives;
    }

    /*******************************************************************************************************
   * @description getter method for class attribute
   * @return accountPlan
   */
    public List<Account_Plan_Objective__c> getPrevious_objectives()
    {
        return previous_objectives;
    }
    
    /*******************************************************************************************************
    * @description getter method for class attribute
    * @return openOpportunities
    */
    public List<Opportunity> getOpenOpportunities() 
    {
        return openOpportunities;
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
    public static String downloadAccountPlan(String url)
    { 
        PageReference pr = new PageReference(url); 
        String pdfStr = EncodingUtil.base64Encode(pr.getContentAsPDF());
        
        return pdfStr;  
    }
}