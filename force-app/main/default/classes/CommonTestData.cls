/*************************************************************************************************************************
Class Name      :   CommonTestdata
Class Desc.     :    testclass for test data generation(mainly for contactmove process)
Author          :   Alpha FMC

Change History
Date             Author         version             Description                                 Requested By           Tag
--------------------------------------------------------------------------------------------------------------------------
Dec-2014         Alpha FMC       0.01            Initial build of class                           Client               None        
***************************************************************************************************************************/
@isTest
public without sharing class CommonTestData {
  // Create test data for most classes in here to speed up the processing.

  //Users
  public static User frenchUser;
  public static User frenchUser2;
  public static User spanishUser;
  public static User HOC1;
  public static User HOC2;
  
  // Accounts
  public static Account HeadAct; 
  public static Account ChildAct;
  public static Account OtherAct;
  public static Account GeneralAct;
  public static Account InternalAct;
  
  // Contacts
  public static Contact AccContact;
  public static Contact EmployeeContact;
  public static Product__c Product;
  public static Opportunity Opp;
    
  
    public static void getData()
    {
        //UserRole r = new UserRole(DeveloperName = 'MyCustomRole', Name = 'My Role');
		//insert r;
        User u = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Carmignac - Standard User'].Id,
            LastName = 'last',
            Email = 'puser000@amamama.com',
            Username = 'puser000@amamama.com' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            //UserRoleId = r.Id,
            BypassApexTriggers__c = 'UserAfterInsert; UserAfterUpdate',
            BypassProcessBuilders__c = true,
            BypassValidationRules__c = true,
            BypassWorkflowRules__c = true,
            Bypass_Duplicate_Rules__c = true
        );

        frenchUser = u.clone(false,true);
        frenchUser.LastName='French';
        frenchUser.alias='fAlias';
        frenchUser.Email = 'fuser000@amamama.com';
        frenchUser.BusinessDevelopmentRegions__c='BP_FR';
        frenchUser.Username = 'puser1000@amamama.com' + System.currentTimeMillis();
        frenchUser.BypassApexTriggers__c = 'UserAfterInsert; UserAfterUpdate';
        insert frenchUser;
        
        frenchUser2 = u.clone(false,true);
        frenchUser2.LastName='French2';
        frenchUser2.alias='f2Alias';
        frenchUser2.Email = 'f2user000@amamama.com';
        frenchUser2.BusinessDevelopmentRegions__c='BP_FR';
        frenchUser2.Username = 'puser1000@amamama.com' + System.currentTimeMillis();
        frenchUser2.BypassApexTriggers__c = 'UserAfterInsert; UserAfterUpdate';
        insert frenchUser2;
        
        spanishUser = u.clone(false,true);
        spanishUser.alias='sAlias';
        spanishUser.Email = 'suser000@amamama.com';
        spanishUser.Id=null;
        spanishUser.LastName='Spain';
        spanishUser.BusinessDevelopmentRegions__c='BP_ES';
        spanishUser.Username = 'puser2000@amamama.com' + System.currentTimeMillis();
        spanishUser.BypassApexTriggers__c = 'UserAfterInsert; UserAfterUpdate';
		insert spanishUser;
        
        HOC1 = u.clone(false,true);
        HOC1.Id=null;
        HOC1.alias='h1Alias';
        HOC1.Email = 'h1user000@amamama.com';
        HOC1.LastName='HOC1';
        HOC1.BusinessDevelopmentRegions__c='BP_FR';
        HOC1.TECH_TextBusinessDevelopmentRegions__c = 'BP_FR';
        HOC1.Position__c='Head of Country';
        HOC1.Username = 'puser3000@amamama.com' + System.currentTimeMillis();
        HOC1.BypassApexTriggers__c = 'UserAfterInsert; UserAfterUpdate';
        insert HOC1;
        
        HOC2 = u.clone(false,true);
        HOC2.Id=null;
        HOC2.alias='h2Alias';
        HOC2.Email = 'h2user000@amamama.com';
        HOC2.LastName='HOC2';
        HOC2.BusinessDevelopmentRegions__c='BP_ES';
        HOC2.TECH_TextBusinessDevelopmentRegions__c = 'BP_ES';
        HOC2.Position__c='Head of Country';
        HOC2.Username = 'puser4000@amamama.com' + System.currentTimeMillis();
        HOC2.BypassApexTriggers__c = 'UserAfterInsert; UserAfterUpdate';
        insert HOC2;
        
        User usr = [Select id from User where Id = :UserInfo.getUserId()];
        usr.BypassProcessBuilders__c = true;
        usr.BypassValidationRules__c = true;
        usr.BypassWorkflowRules__c = true;
        usr.Bypass_Duplicate_Rules__c = true;
        usr.BypassApexTriggers__c = 'UserAfterInsert; UserAfterUpdate';

        System.runAs(usr) {

        HeadAct = new Account();
        headAct.Name = 'Parent Account';
        HeadAct.RecordTypeId = UtilitiesSobject.getRecordTypeIdsByDeveloperName('Account').get('Ultimate_Parent');
        HeadAct.Type = 'Asset Manager';
        HeadAct.BusinessDevelopmentRegion__c = 'BP_FR';
        insert HeadAct;
        
        
        ChildAct = new Account();
        ChildAct = HeadAct.clone(false,true);  
        ChildAct.ParentId = HeadAct.Id;
        insert ChildAct;
    
        OtherAct = new Account();
        OtherAct = HeadAct.clone(false,true);
        OtherAct.ParentId = null;
        insert OtherAct;        
    
        GeneralAct = new Account();
        GeneralAct = HeadAct.clone(false,true);
        insert GeneralAct;
    
	    InternalAct = new Account();
	    InternalAct = HeadAct.clone(false,true);
	    InternalAct.ParentId = null;
		InternalAct.RecordTypeId = UtilitiesSobject.getRecordTypeIdsByDeveloperName('Account').get('Internal_Organisation');
	    insert InternalAct;	    
	   
        Product = new Product__c(Name = 'testProduct', Product_Name__c='Test Product');
        insert Product;
        
        Id fred = UtilitiesSObject.getRecordTypeIdsByDeveloperName('Contact').get('Contact_DistributionContact');
        system.debug('ContactRecType:'+fred);
        AccContact = new Contact();
        AccContact.RecordTypeId = UtilitiesSObject.getRecordTypeIdsByDeveloperName('Contact').get('Contact_DistributionContact');
        AccContact.LastName = 'AccContact';
        AccContact.Email = 'john.backhouse@alphafmc.com';
        AccContact.Source__c = 'Event';
        AccContact.AccountId = HeadAct.Id;
        AccContact.Technical_ID__c = Math.round(Math.random()*10000);
        insert AccContact;
        
        EmployeeContact = new Contact();
        EmployeeContact.RecordTypeId = UtilitiesSObject.getRecordTypeIdsByDeveloperName('Contact').get('Internal_Carmignac_Contact');
        EmployeeContact.LastName = 'employeeContact';
        EmployeeContact.Email = 'john.smith@alphafmc.com';
        EmployeeContact.Technical_ID__c = Math.round(Math.random()*1000);
        EmployeeContact.AccountId = InternalAct.Id;
        insert EmployeeContact;
        
        Opp = new Opportunity();
        Opp.Name = 'TestOpp';
        Opp.amount = 500000;
        Opp.AccountId = ChildAct.Id;
        Opp.closedate = system.today();
        Opp.StageName = 'Internally Identified';
        insert Opp;
        
        }
        system.debug('End of static data');
    }
    
}