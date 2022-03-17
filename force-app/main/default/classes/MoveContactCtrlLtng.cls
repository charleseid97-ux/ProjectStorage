public with sharing class MoveContactCtrlLtng {
    
    @AuraEnabled
    public static List<String> getCorporateTitleOptions(){
        List<String> options = new List<String>();
        Schema.DescribeFieldResult fieldResult = Contact.CorporateTitle__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry f: ple) {
            options.add(f.getLabel());
        }
        return options;
    }
    
    @AuraEnabled
    public static List<String> getJobFunctionOptions(){
        List<String> options = new List<String>();
        Schema.DescribeFieldResult fieldResult = Contact.JobFunction__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry f: ple) {
            options.add(f.getLabel());
        }
        return options;
    }
    
    @AuraEnabled
    public static List<String> getJobTitleOptions(){
        List<String> options = new List<String>();
        Schema.DescribeFieldResult fieldResult = Contact.JobTitle__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry f: ple) {
            options.add(f.getLabel());
        }
        return options;
    }
    
    @AuraEnabled
    public static void doSave(Id oldContactId,
                              Contact newContact, 
                              Id toAccountId,
                              boolean isSameHierarchy, 
                              boolean moveToInactiveContacts, 
                              Date dateLeft,
                              Contact oldContact){
                                  
                                  newContact.AccountId = toAccountId;
                                  
                                  AccountContactRelation[] currentEmploymentRelation = [SELECT Id FROM AccountContactRelation WHERE IsDirect = true AND ContactId =: oldContact.Id];
                                  
                                  Account toAccount = new Account(id = toAccountId);
                                  
                                  Contact cont = [select AccountId, 
                                                  CorporateTitle__c, 
                                                  JobFunction__c, 
                                                  JobTitle__c, 
                                                  Business_Card_Title__c, 
                                                  Title, 
                                                  Phone, 
                                                  MobilePhone, 
                                                  Email,
                                                  AssistantName,
                                                  AssistantPhone,
                                                  ReportsToId,
                                                  Fax,
                                                  MailingStreet, 
                                                  MailingCity, 
                                                  MailingState, 
                                                  MailingPostalCode, 
                                                  MailingCountry,
                                                  MailingLatitude,
                                                  OtherStreet, 
                                                  OtherCity, 
                                                  OtherState, 
                                                  OtherPostalCode, 
                                                  OtherCountry,
                                                  OtherLatitude,
                                                  HasOptedOutOfEmail,
                                                  Subscriber__c,
                                                  RecordTypeId
                                                  from Contact where id = : oldContactId];
                                  
                                  if (toAccountId != null){
                                      
                                      toAccount= [select Id,
                                                  BillingStreet, 
                                                  BillingCity, 
                                                  BillingState, 
                                                  BillingPostalCode, 
                                                  BillingCountry,
                                                  BillingLatitude,
                                                  ShippingStreet, 
                                                  ShippingCity, 
                                                  ShippingState, 
                                                  ShippingPostalCode, 
                                                  ShippingCountry,
                                                  ShippingLatitude
                                                  from Account where id = : toAccountId];
                                  }
                                  
                                  UtilitiesMoveContact.save(cont, 
                                                            newContact, 
                                                            toAccount,
                                                            isSameHierarchy, 
                                                            moveToInactiveContacts, 
                                                            dateLeft);
                                  
                                  if(currentEmploymentRelation != null) {
                                      delete currentEmploymentRelation;
                                  }
                              }
    
    @AuraEnabled
    public static boolean checkSameHierarchy(Id fromAccountId, Id toAccountId){
        
        Account toAccount = new Account(Id = toAccountId);
        boolean result = UtilitiesMoveContact.checkSameHierarchy(fromAccountId, toAccount);
        
        return result;
    }
    @AuraEnabled
    public static List<String> getConvRelatedContact (Id contactId){
        List<ConventionRelatedContact__c> ConvRelatedContact = [SELECT Id,Convention__r.Name,Contact__c, Convention__r.Status__c 
                                                                FROM ConventionRelatedContact__c 
                                                                WHERE Contact__c =: contactId
                                                                AND Convention__r.Status__c = 'Terminated']; // Added by SLI to let user move contact with an expired agreement
        List<String> result = new List<String>();
        if(ConvRelatedContact!= null) {
            for(ConventionRelatedContact__c crc: ConvRelatedContact )
                result.add(crc.Convention__r.Name);
        }
        return result;
    }
    
}