global with sharing class AccountUtil {
	
    @AuraEnabled
    public static Account confirmClientTier(String accId){
        return queryAccount('SELECT Name, Id, Client_Tier__c, Ultimate_Parent_Tier__c FROM Account WHERE Id = \'' + accId + '\'');
    }

    @AuraEnabled
    public static Account returnGAMAccount(String accId) {
        return queryAccount('SELECT Name, Id FROM Account WHERE Id = \'' + accId + '\'');
    }

    @AuraEnabled
    public static Account returnAccount(String accId) {
        return queryAccount('SELECT Name, Id FROM Account WHERE Id = \'' + accId + '\'');
    }

    private static Account queryAccount(String soqlQuery) {
        Account acc = Database.query(soqlQuery);
        System.debug('Account Record: ' + acc);
        return acc;
    }

    @AuraEnabled
    public static Account initializeBuyListDetail(String accId){
        String soqlQuery = 'SELECT Name, Id, Buy_List_Information__c FROM Account WHERE Id = \'' + accId + '\'';
        Account acc = Database.query(soqlQuery);
        return acc;
    }
    
    @AuraEnabled
    public static void saveBuyListDetailCtrl(String accId, String buyListDetailVal){
        Account acc = new Account(Id = accId);
        acc.Buy_List_Information__c = buyListDetailVal;
        try{
            update acc;
        }
        catch(DMLException ex){
            AuraHandledException e = new AuraHandledException(ex.getMessage());
            throw e;
        }
    }

    @AuraEnabled
    public static List < String > getselectOptions(sObject objObject, string fld) {
		List < String > allOpts = new list < String > ();
		Schema.sObjectType objType = objObject.getSObjectType();
 
      	Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
 
		map < String, Schema.SObjectField > fieldMap = objDescribe.fields.getMap();
 
        list < Schema.PicklistEntry > values =
        	fieldMap.get(fld).getDescribe().getPickListValues();
         
        for (Schema.PicklistEntry a: values) {
	        allOpts.add(a.getValue());
        }
        system.debug('allOpts ---->' + allOpts);
        allOpts.sort();
    	return allOpts;
	}

    //Mass deactivate Contacts

    @AuraEnabled
    public static AccountWrapper returnCompanyInformation(String accId) {
        Account acc = queryAccount('SELECT Name, Id, (SELECT Name, '+
                            'AccountId, '+
                            'JobTitle__c, '+
                            'Title, '+
                            'Phone, '+
                            'MobilePhone, '+
                            'Email, '+
                            'AssistantName, '+
                            'AssistantPhone, '+
                            'ReportsToId, '+
                            'Fax, '+
                            'MailingStreet, '+
                            'MailingCity, '+
                            'MailingState, '+
                            'MailingPostalCode, '+
                            'MailingCountry, '+
                            'MailingLatitude, '+
                            'OtherStreet, '+
                            'OtherCity, '+
                            'OtherState, '+
                            'OtherPostalCode, '+
                            'OtherCountry, '+
                            'OtherLatitude, '+
                            'HasOptedOutOfEmail, '+
                            'Subscriber__c, '+
                            'RecordTypeId '+
                            'FROM Contacts), '+
                            '(SELECT Id, Contact.Name FROM AccountContactRelations WHERE IsDirect = false) ' +
                            'FROM Account WHERE Id = \'' + accId + '\'');

        Boolean hasContacts = (acc.Contacts.size() > 0) ? true : false;
        Boolean hasRelated = (acc.AccountContactRelations.size() > 0) ? true : false;
        AccountWrapper accWrap = new AccountWrapper(acc, acc.AccountContactRelations, hasContacts, hasRelated);
        return accWrap;
    }

    @AuraEnabled
    public static Boolean convertProspectCtrl(Account company) {
        Id prospectRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Account_Prospect').getRecordTypeId();
        company.RecordTypeId = prospectRecordTypeId;
        update company;
        return true;
    }

    @AuraEnabled
    public static Boolean deactivateCompanyCtrl(Account company, List<Contact> linkedContacts, Boolean deactivateAllContacts, List<AccountContactRelation> relatedContacts, Boolean deactivateAllRelationships) {
        system.debug('LC ' + linkedContacts);
        system.debug('DAC ' + deactivateAllContacts);
        system.debug('RC ' + relatedContacts);
        system.debug('DAR ' + deactivateAllRelationships);
        
        company.CompanyStatus__c = 'Inactive';
        update company;
        
        if(deactivateAllContacts && linkedContacts != null) {
            Account generalContactAccount = UtilitiesAccount.InactiveContactsAccount;
            List<Former_Employment_Relationship__c> FEList = new List<Former_Employment_Relationship__c>();
            List<Contact> contactUpd = new List<Contact>();
            List<Id> contactIdList = new List<Id>();
            
            for(Contact contId : linkedContacts) {
                contactIdList.add(contId.Id);
            }
            AccountContactRelation[] currentEmploymentRelation = [SELECT Id FROM AccountContactRelation WHERE IsDirect = true AND ContactId IN: contactIdList];
            
            for(Contact cont : linkedContacts) {

                FEList.add(new Former_Employment_Relationship__c( 
                    Account__c = cont.AccountId,
                    Email__c =  cont.Email,
                    Assistant__c = cont.AssistantName,
                    Assistant_Phone__c = cont.AssistantPhone,
                    Reports_to__c = cont.ReportsToId,
                    Role_Title__c = cont.JobTitle__c,
                    Title__c = cont.Title,
                    Fax__c = cont.Fax,
                    Phone__c = cont.Phone,
                    Mobile_Phone__c = cont.MobilePhone,
                    Contact__c = cont.Id,
                    Mailing_Street__c = cont.MailingStreet,
                    Mailing_City__c = cont.MailingCity,
                    Mailing_Postcode__c = cont.MailingPostalCode,
                    Other_Street__c = cont.OtherStreet,
                    Other_City__c = cont.OtherCity,
                    Other_Postcode__c = cont.OtherPostalCode,
                    Date_Left__c = date.today()
                ));

                cont.AccountId = generalContactAccount.Id;
                cont.JobTitle__c = '';
                cont.Title = '';
                cont.Phone = '';
                cont.MobilePhone = '';
                cont.MailingCity = '';
                cont.MailingCountry = '';
                cont.MailingLatitude = 0;
                cont.MailingLongitude = 0;
                cont.MailingPostalCode = '';
                cont.MailingState = '';
                cont.MailingStreet = '';
                cont.OtherCity = '';
                cont.OtherCountry = '';
                cont.OtherLatitude = 0;
                cont.OtherLongitude = 0;
                cont.OtherPostalCode = '';
                cont.OtherState = '';
                cont.OtherStreet = '';
                cont.ContactStatus__c = 'false';
                cont.ReportsToId = null;
                cont.Bypass_Apex__c = true;
                // Change RecordType to Inactive External Contact
                cont.RecordTypeId = UtilitiesContact.RecordTypeIdsByDevName.get('Inactive_External_Contact');
                
                system.debug('bp felist ' + FEList);

                contactUpd.add(cont);
            }
            update contactUpd;
            insert FEList;
            if(currentEmploymentRelation != null) {
                delete currentEmploymentRelation;
            }
            
        }
        
        if(deactivateAllRelationships && relatedContacts != null) {
            delete relatedContacts;
        }
                
        return true;
    }
    
    public class AccountWrapper {
        @AuraEnabled
        public Account account {get;set;}
        @AuraEnabled
        public List<AccountContactRelation> relatedContacts {get;set;}
        @AuraEnabled
        public Boolean hasContacts {get;set;}
        @AuraEnabled
        public Boolean hasRelated {get;set;}
        
        public AccountWrapper(Account account, List<AccountContactRelation> relContacts, Boolean hasContacts, Boolean hasRelated){
            this.account = account;
            this.relatedContacts = relContacts;
            this.hasContacts = hasContacts;
            this.hasRelated = hasRelated;
        }
    }
}