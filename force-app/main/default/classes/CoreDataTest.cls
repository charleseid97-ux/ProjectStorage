/*************************************************************************************************************************
Class Name      :  CoreDataTest
Class Desc.     :    Main testclass for test data generation across the org
Author          :   Alpha FMC

Change History
Date             Author         version             Description                                 Requested By           Tag
--------------------------------------------------------------------------------------------------------------------------
Dec-2014         Alpha FMC       0.01            Initial build of class                           Client               None        
***************************************************************************************************************************/
 
 @isTest
 public without sharing class CoreDataTest 
 {    
    public static list<Contact> Contacts;
    public static list<Contact> Employees;
    public static list<Account> Accounts;
    public static list<Opportunity> Opportunities;
    public static list<Product__c> Products;

   //public static list<Legal_Entity__c> LegalEntities;

    public static list<User> Users;
    //public static list<Agreement__c> Agreements;
    public static list<Campaign> Campaigns;
    public static list<CampaignMember> CampaignMembers;
    //public static list<Portfolio__c> Portfolios;

    public static map<String, Schema.RecordTypeInfo> CompanyRecordTypes;
    public static Profile Prof = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];    
    
    public static Account getTestAccount(string pName)
    {
        //Account acc = (Account) SmartFactory.createSObject('Account');
        Account acc = new Account();
        acc.Name = pName;
        acc.BillingStreet = 'Street';
        acc.BillingCity = 'City'; 
        acc.BillingPostalCode = 'LE2 1ZE';
        acc.BillingCountry = 'United Kingdom';
        acc.BillingState = null;
        acc.ShippingStreet = 'Street';
        acc.ShippingCity = 'City'; 
        acc.ShippingPostalCode = 'LE4 4EB';
        acc.ShippingCountry = 'United Kingdom';
        acc.ShippingState = null; 
        acc.BusinessDevelopmentRegion__c = 'BP_FR';
        acc.Distributor_Type__c = 'Bank';
        acc.Sub_Type__c = 'Retail Banking';
        acc.Investment_vehicle__c = null;
        acc.Investment_vehicle_type__c = null;
                  
        return acc; 
    }


    public static void getData()
    {
        
        if (CompanyRecordTypes == null) CompanyRecordTypes = UtilitiesAccount.RecordTypeInfosByDevName;
        
       
        if (Accounts ==  null)
        {
            Accounts = new list<Account>{
                
                getTestAccount('TEST SPONSOR'),
                getTestAccount('TEST PARENT'),
                getTestAccount('Internal')
            };
    
            Accounts[0].RecordTypeId = CompanyRecordTypes.get('Account_Distributor').getRecordTypeId();
            Accounts[1].RecordTypeId = CompanyRecordTypes.get('Ultimate_Parent').getRecordTypeId();
            Accounts[2].RecordTypeId = CompanyRecordTypes.get('Internal_Organisation').getRecordTypeId();
            
            insert Accounts;        
            
            list<Account> refreshAccs = [SELECT Name FROM Account];
            for (Account a :refreshAccs)
            {
                if (a.Id == Accounts[0].Id) Accounts[0].Name = a.Name;
                else if (a.Id == Accounts[1].Id) Accounts[1].Name = a.Name;
                else if (a.Id == Accounts[2].Id) Accounts[2].Name = a.Name;
                else if (a.Id == Accounts[3].Id) Accounts[3].Name = a.Name;
                
            }   
        }

        if (Contacts == null)
        {
            Contacts = new list<Contact>{
                new Contact(),
                new Contact(),
                new Contact(),
                new Contact(),
                new Contact()
            };
            
            for (integer i = 0; i < Contacts.size(); i++) 
            {
                Contacts[i].FirstName = 'TESTFIRSTNAME';
                Contacts[i].LastName = 'TESTCONTACT' + i;
                Contacts[i].LastName = 'TESTCONTACT' + i;
                
                Contacts[i].Email = 'test'+i+'@email.com';
                Contacts[i].Source__c = 'Event';
                Contacts[i].MailingStreet = 'Street';
                Contacts[i].MailingCity = 'City';
                Contacts[i].MailingPostalCode = 'LE2 1ZE';
                Contacts[i].MailingCountry = 'United Kingdom';
                Contacts[i].MailingState = null;
                Contacts[i].OtherStreet = 'Street';
                Contacts[i].OtherCity = 'City';
                Contacts[i].OtherPostalCode = 'LE4 4EB';
                Contacts[i].OtherCountry = 'United Kingdom';
                Contacts[i].OtherState = null;
                Contacts[i].AccountId =  Accounts[Integer.valueOf(Math.floor(i/2))].Id; 
                Contacts[i].RecordTypeId = Contacts[i].AccountId == Accounts[2].Id 
                                         ? UtilitiesContact.RecordTypeInfosByDeveloperName.get('Internal_Carmignac_Contact').getRecordTypeId()
                                         : UtilitiesContact.RecordTypeInfosByDeveloperName.get('Contact_DistributionContact').getRecordTypeId();  
            }
                    
            //Contacts[0].User__c = Users[0].Id;
        
            //Contacts[1].User__c = Users[1].Id;

            
            //Current user must have an Employee contact record
            Contact currUserEmployee  = new Contact();
            currUserEmployee.FirstName = 'TESTFIRSTNAME';
            currUserEmployee.LastName = 'TESTCONTACT';
            currUserEmployee.Email = 'testcontact@test.com';
            currUserEmployee.MailingStreet = 'Street';
            currUserEmployee.MailingCity = 'City';
            currUserEmployee.MailingPostalCode = 'LE2 1ZE';
            currUserEmployee.MailingCountry = 'United Kingdom';
            currUserEmployee.MailingState = null;
            currUserEmployee.OtherPostalCode = 'LE4 1ZE';
            currUserEmployee.OtherStreet = 'Street';
            currUserEmployee.OtherCity = 'City';
            currUserEmployee.OtherCountry = 'United Kingdom';
            currUserEmployee.OtherState = null;
            currUserEmployee.User__c = UserInfo.getUserId();
  			currUserEmployee.AccountId =  Accounts[2].Id;
            currUserEmployee.RecordTypeId = UtilitiesContact.RecordTypeInfosByDeveloperName.get('Internal_Carmignac_Contact').getRecordTypeId();
            
            Contacts.add(currUserEmployee);       
            insert Contacts;            
        }

        getEmployees();
        
        if (Opportunities == null)
        {
            Opportunities = new list<Opportunity>{
                (Opportunity) SmartFactory.createSObject('Opportunity'),
                (Opportunity) SmartFactory.createSObject('Opportunity'),
                (Opportunity) SmartFactory.createSObject('Opportunity'),
                (Opportunity) SmartFactory.createSObject('Opportunity')
            };
            
            for (integer i = 0; i < Opportunities.size(); i++) 
            {
                Opportunities[i].Name = 'TEST OPP ' + i;
                Opportunities[i].AccountId = Accounts[0].Id; //investor sponsor
                Opportunities[i].Amount = 100000 ;
                
            }
            
            insert Opportunities;            
        }
       
        if (Products == null)
        {
            Products = new list<Product__c>{
                (Product__c) SmartFactory.createSObject('Product__c'),
                (Product__c) SmartFactory.createSObject('Product__c')
            };
            
            for (integer i = 0; i < Products.size(); i++) 
            {
                Products[i].Name = 'TEST PRODUCT ' + i;
                Products[i].Validity__c = true;
            }
            
            insert Products;            
        }
        
        
        /*if (Campaigns == null)
        {
                            
            Campaigns = new list<Campaign>{
                (Campaign) SmartFactory.createSObject('Campaign'),
                (Campaign) SmartFactory.createSObject('Campaign')           
            };
            for (integer i = 0; i < Campaigns.size(); i++) 
            {                               
                Campaigns[i].Name = 'TEST CAMPAIGN ' + i;
                Campaigns[i].isactive = true;
                Campaigns[i].status = 'In Progress'; 
                Campaigns[i].StartDate = null;
                Campaigns[i].EndDate = null;          
            }
            insert Campaigns;       
            system.debug(system.logginglevel.ERROR, 'INSERTED Campaigns in CDT');              
        }   
        
        for (CampaignMemberStatus cms : [select Label from CampaignMemberStatus]) system.debug(system.logginglevel.ERROR, cms);         
        
        if (CampaignMembers == null)
        {           
            CampaignMembers = new list<CampaignMember>{
                (CampaignMember) SmartFactory.createSObject('CampaignMember'),
                (CampaignMember) SmartFactory.createSObject('CampaignMember')
            };
            for (integer i = 0; i < CampaignMembers.size(); i++) 
            {
                CampaignMembers[i].CampaignId = Campaigns[0].Id;
                CampaignMembers[i].ContactId = Contacts[i + 2].Id;          
            }
            insert CampaignMembers;
            system.debug(system.logginglevel.ERROR, 'INSERTED Campaign Members in CDT');            
        }*/
    }
    
    public static Contact[] getEmployees(){
         
         if(Employees == null)
         {

            Employees = new list <Contact>();
             
            for (Contact c : Contacts){
                if (c.RecordTypeId == RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Contact.sObjectType).get('Internal_Carmignac_Contact')){
                    Employees.add(c);
                }
            }
         } 
         
         return Employees;
     }
        
    public static testmethod void testGetData()
    {
        Test.startTest();
        getData();
        Test.stopTest();
    }
}