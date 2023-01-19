/** 
* @author Pape DIOUF
* @date Creation 02/09/2016
* @date Modification 07/09/2016 
* @description : Build complete objects for unit testing development / public constants for unit tests
*/

@isTest
public class TestFactory {
    /* -------------------------------- *
* Records creation methods 
* ---------------------------------*/
    
    public static String RECORDTYPE_NAME_PROSPACE = 'Generic Lead'; 
    public static String RECORDTYPE_ID_PROSPACE =  ObjectUtil.getRecordTypeId('Lead', RECORDTYPE_NAME_PROSPACE);
    public static  String WEBSITEROLE_PROSPACETEMP = '5';
    public static  String STATUS_WAITINGFORVALIDATION = '5';
    public static String RECORDTYPE_ID_OPPORTUNITY =  ObjectUtil.getRecordTypeId('Opportunity', 'Generic Opportunity');

    public static Profile simpleProfile;
    public static Profile simpleCarmignacProfile;
    public static User userTechTest;

    public static Profile getSimpleProfile(){

        if(simpleProfile == null)
            simpleProfile = [SELECT Id FROM Profile WHERE UserType='Standard' LIMIT 1];

        return simpleProfile;
    }
    public static Profile getSimpleCarmignacProfile(){
        if(simpleCarmignacProfile == null)
            //TODO check profile
            simpleCarmignacProfile = [SELECT Id FROM Profile WHERE Name='Carmignac - Standard User' LIMIT 1];
            //simpleCarmignacProfile = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        return simpleCarmignacProfile;
    }


    public static Profile getAdminProfile(){
        if(simpleCarmignacProfile == null)
            simpleCarmignacProfile = [SELECT Id FROM Profile WHERE Name='Carmignac - System Administrator' LIMIT 1];

        return simpleCarmignacProfile;
    }
    
    public static Profile getEtouchesInterfaceProfile(){
        Profile prof = [SELECT Id FROM Profile WHERE UserType='Standard' and Name='Carmignac - Interface Etouches' LIMIT 1]; 
        return prof;
    }
    
    public static UserRole getSimpleRole(){
        UserRole usRole =  [SELECT Id FROM UserRole WHERE Name='Carmignac' LIMIT 1]; 
        return usRole;
    }
    
    public static RecordType getSimpleGAMRecordType(){
        RecordType recordtype = [SELECT Id FROM RecordType WHERE Name='Global Account' LIMIT 1]; 
        return recordtype;
    }
    
    public static final Map <String, Schema.SObjectType> schemaMap;
    static {
        SchemaMap = Schema.getGlobalDescribe();
    }
    
    // User
    public static User getStandardUser()
    {
        Profile profile = getSimpleProfile();
        
        User u = new User
            (
                alias = 'User1'
                , email='test'+System.now().getTime()+'@carmignac.com' 
                , emailencodingkey='ISO-8859-1'
                , firstname='firstTest' 
                , lastname='Test' 
                , languagelocalekey='fr' 
                , localesidkey='fr_FR_EURO'
                , profileid = profile.Id
                , timezonesidkey='Europe/Paris'
                , username='etouches_interface_test'+System.now().getTime()+'-crm@carmignac.com'
                , TECH_UserEmail__c = 'TECH_UserEmail'+System.now().getTime()
                , Position__c = 'Business Developer'
                , BusinessDevelopmentRegions__c = 'BP_FR'
                , IsActive = true
                , BypassApexTriggers__c = ''
                , BypassProcessBuilders__c = false
                , BypassValidationRules__c = false
                , BypassWorkflowRules__c = false
            );
        return u;
    }
    
    public static Category_Event__c getCAtegoryEvent(Id CampID)
    {
        Category_Event__c categ = new Category_Event__c
            (
                Name = 'Test'
                ,Tech_Category_Event_ID_Etouches__c = '123456'
                ,   Campaign__c=CampID
            );        
        
        return categ; 
    } 
    
    public static Process_Id__c getProcessID()
    {
        Process_Id__c temp = new Process_Id__c
            (
                Index__c = '123456'
                ,   Status__c='OK'        
            );       
        
        return temp;    
    }    
    
    // User
    public static User getStandardUserWebSite()
    {
        Profile prof = getSimpleCarmignacProfile();
        UserRole usrole = getSimpleRole();
        
        User u = new User
            (
                alias = 'User1'
                , email='test'+System.now().getTime()+'@carmignac.com' 
                , emailencodingkey='ISO-8859-1'
                , userroleId =usrole.Id
                , Phone='+3312345678'
                , firstname='firstTest' 
                , lastname='Test' 
                , languagelocalekey='fr' 
                , localesidkey='fr_FR_EURO'
                , ProfileId = prof.Id
                , timezonesidkey='Europe/Paris'
                , username='etouches_interface_test'+System.now().getTime()+'-crm@carmignac.com'
                , TECH_UserEmail__c = 'TECH_UserEmail'+System.now().getTime()
                //, TECH_UserExternalID__c = '46579864513'
                , Position__c = 'Business Developer'
                , BusinessDevelopmentRegions__c = 'France'
                , IsActive = true
                , BypassApexTriggers__c = ''
                , BypassProcessBuilders__c = false
                , BypassValidationRules__c = false
                , BypassWorkflowRules__c = false
            );
        return u;
    }
    
    
    public static User getStandardCarmignacUser()
    {
        Profile profile = getSimpleCarmignacProfile();
        
        /* List<Id> UserIdList = new  List<Id>();
Id idTempUser;

String TestIfPartCopy = URL.getSalesforceBaseUrl().toExternalForm();
Boolean test = TestIfPartCopy.contains('PARTCOPY');
if (test){
//PARTCOPY
idTempUser = '00558000001rQp1';
}else{
//PROD
idTempUser = '00558000001soLJ';
}

UserIdList.add(idTempUser);

User u = DM023_User.getListByIds(UserIdList).get(0);
*/
        if(userTechTest == null) {
            UserRole usrole = getSimpleRole();

            userTechTest = new User
                    (
                        alias = 'TechCUs'
                        , email = 'TechCarmignacUser' + System.now().getTime() + '@carmignac.com'
                        , emailencodingkey = 'ISO-8859-1'
                        , userroleId = usrole.Id
                        , Phone = '+3312345678'
                        , firstname = 'CarmignacUser'
                        , lastname = 'Tecg'
                        , languagelocalekey = 'fr'
                        , localesidkey = 'fr_FR_EURO'
                        , ProfileId = profile.Id
                        , timezonesidkey = 'Europe/Paris'
                        , username = 'TechCarmignacUser' + System.now().getTime() + '-crm@carmignac.com'
                        , TECH_UserEmail__c = 'TECH_UserEmail' + System.now().getTime()
                        //, TECH_UserExternalID__c = '46579864513'
                        , Position__c = 'Business Developer'
                        //  , BusinessDevelopmentRegions__c = 'France'
                        , IsActive = true
                        , BypassApexTriggers__c = ''
                        , BypassProcessBuilders__c = true
                        , BypassValidationRules__c = true
                        , BypassWorkflowRules__c = false
                        , Bypass_Duplicate_Rules__c = true
                    );
            insert userTechTest ;
        }
        return userTechTest;
    }
    
    // BGU 11/04/2017
    /*public static User getCarmignacUserTestApex()
    {            
        List<Id> UserIdList = new  List<Id>();
        Id idTempUser;
        
        String TestIfPartCopy = URL.getSalesforceBaseUrl().toExternalForm();
        Boolean test = TestIfPartCopy.contains('PARTCOPY');
        if (test){
            //PARTCOPY
            idTempUser = '00558000002Fv5r';
        }else{
            //PROD
            idTempUser = '00558000001rQp1';
        } 
        
        UserIdList.add(idTempUser);
        
        User u = DM023_User.getListByIds(UserIdList).get(0);
        
        return u;
    }*/
    
    public static User getCarmignacUserTestApex()
    {                    
        
        //Profile prof = getAdminProfile();
        Profile prof = getSimpleCarmignacProfile();
        UserRole usrole = getSimpleRole();
        
        User u = new User
            (
                alias = 'TestApex'
                , email='UserTestApex'+System.now().getTime()+'@carmignac.com' 
                , emailencodingkey='ISO-8859-1'
                , userroleId =usrole.Id
                , Phone='+3312345678'
                , firstname='firstTest' 
                , lastname='UserTestApex' 
                , languagelocalekey='fr' 
                , localesidkey='fr_FR_EURO'
                , ProfileId = prof.Id
                , timezonesidkey='Europe/Paris'
                , username='UserTestApex'+System.now().getTime()+'-crm@carmignac.com'
                , TECH_UserEmail__c = 'TECH_UserEmail'+System.now().getTime()
                //, TECH_UserExternalID__c = '46579864513'
                , Position__c = 'Business Developer'
                //, BusinessDevelopmentRegions__c = 'France'
                , BusinessDevelopmentRegions__c = 'BP_FR'
                , IsActive = true
                , BypassApexTriggers__c = ''
                , BypassProcessBuilders__c = true
                , BypassValidationRules__c = true
                , BypassWorkflowRules__c = true
                , Bypass_Duplicate_Rules__c = true
            );
        insert u;
        return u;
    }
    
    public static User getInterfaceEtouchesUser()
    {
        Profile profile = getEtouchesInterfaceProfile();
        
        User u = new User
            (
                alias = 'User2'
                , email='testEtouchesInterface'+System.now().getTime()+'@carmignac.com' 
                , emailencodingkey='ISO-8859-1'
                , firstname='SecondTest' 
                , lastname='EtouchesInterface' 
                , languagelocalekey='fr' 
                , localesidkey='fr_FR_EURO'
                , profileid = profile.Id
                , timezonesidkey='Europe/Paris'
                , username='test'+System.now().getTime()+'-crm@carmignac.com'
                , TECH_UserEmail__c = 'TECH_UserEmail'+System.now().getTime()
                , Position__c = 'Business Developer'
                , BusinessDevelopmentRegions__c = 'France'
                , IsActive = true
                , BypassApexTriggers__c = 'AccountAfterInsert; AccountAfterUpdate; AccountBeforeInsert; AccountBeforeUpdate; ActivityBeforeInsert; ActivityBeforeUpdate; CampaignMemberAfterInsert; CampaignMemberAfterUpdate; CommunicationSubscriptionAfterInsert; CommunicationSubscriptionBeforeDelete; ContactAfterInsert; ContactAfterUpdate; ContactBeforeDelete; GridBeforeInsert; GridBeforeUpdate; RelationshipStatusAfterUpdate; StrategicNewsAfterInsert; UserAfterInsert; UserAfterUpdate; UserBeforeInsert; UserBeforeUpdate'
                , BypassProcessBuilders__c = false
                , BypassValidationRules__c = false
                , BypassWorkflowRules__c = false
            );
        return u;
    }
    
    // Lead
    public static Lead getSimpleProSpaceLead()
    {
        Lead lead = new Lead 
            (
                recordtypeId = RECORDTYPE_ID_PROSPACE
                , Company = 'Company'
                , FirstName = 'Lead'
                , LastName = 'Test'
                , WebsiteCompany__c = 'Carmignac coorp'
                , WebsiteLogin__c = 'test'+System.now().getTime()+'@carmignac.com'
                , WebsiteLanguage__c = 'French'
                , WebsiteCountry__c = 'FR'
                , Technical_ID__c = Math.round(Math.random()*1000)
                , Email = 'test'+System.now().getTime()+'@carmignac.com'
                , WebsiteRole__c = WEBSITEROLE_PROSPACETEMP
                , TrialStatus__c = STATUS_WAITINGFORVALIDATION
                , Street = '3 Rue de Bercy'
                , City = 'Paris'
                , Country = 'France'
                , PostalCode = '75012'
                , Title = 'Maitre'
                
            );
        return lead;
    }

    
    // Lead
    public static Lead getSimpleLead()
    {
        Lead lead = new Lead 
            (
                recordtypeId = RECORDTYPE_ID_PROSPACE
                , Company = 'Company'
                , FirstName = 'Lead'
                , LastName = 'Test'
                , WebsiteCompany__c = 'Carmignac coorp'
                , WebsiteLogin__c = 'test'+System.now().getTime()+'@carmignac.com'
                , WebsiteLanguage__c = 'French'
                , WebsiteCountry__c = 'FR'
                , Email = 'test'+System.now().getTime()+'@carmignac.com'
                , Street = '3 Rue de Bercy'
                , City = 'Paris'
                , Country = 'France'
                , PostalCode = '75012'
                , Title = 'Maitre'
                
            );
        return lead;
    }     
    
    // Lead
    public static Lead getSimpleProSpaceLead2()
    {
        Lead lead = new Lead 
            (
                recordtypeId = RECORDTYPE_ID_PROSPACE
                , Company = 'Company2'
                , FirstName = 'Lead2'
                , LastName = 'Test2'
                , WebsiteCompany__c = 'Carmignac coorp2'
                , WebsiteLogin__c = 'test'+System.now().getTime()+'@Testcarmignac.com'
                , WebsiteLanguage__c = 'French'
                , WebsiteCountry__c = 'FR'
                , Technical_ID__c = Math.round(Math.random()*1000)
                , Email = 'test2'+System.now().getTime()+'@carmignac.com'
                , WebsiteRole__c = WEBSITEROLE_PROSPACETEMP
                , TrialStatus__c = STATUS_WAITINGFORVALIDATION
                , Street = '32 Rue de Bercy'
                , City = 'Paris'
                , Country = 'France'
                , PostalCode = '75012'
                , Title = 'Maitre'
                
            );
        return lead;
    }    
    
    // Contact (ProSpace)
    public static Contact getSimpleProSpaceContact(Id SfAccountId, String TechSUNId, string WebsiteId, string ProfessionalEmail, string PersonalEmail, string TeamEmail)
    {
        
        Contact contact = new Contact 
            (
                AccountId = SfAccountId
                , recordtypeId = ObjectUtil.getRecordTypeId('Contact', 'Distribution Contact')
                , FirstName = 'Lead'
                , LastName = 'Test'
                , Salutation = 'Mr'
                , WebsiteCompany__c = 'Carmignac coorp'
                , WebsiteLogin__c = 'test'+System.now().getTime()+'@carmignac.com'
                , WebsiteLanguage__c = 'French'
                , WebsiteCountry__c = 'FR'
                , WebsiteRole__c = '3'
                , Address1__c = '12 Avenue du Général de Gaulle'
                , Address2__c = 'Zone Industrielle'
                , City__c = 'Paris'
                , Country__c = 'France'
                , PostalCode__c = '75009'
                , Technical_ID__c = Decimal.valueOf(TechSUNId) 
                , TECH_WebSiteID__c = String.valueOf(Math.round(Math.random()*1000)) + 'TEST'             
                , Email = ProfessionalEmail
                , PersonalEmail__c = PersonalEmail
                , TeamEmail__c = TeamEmail
                , Title = 'Maitre'
                //, Technical_ID__c = Math.round(Math.random()*1000)
                
            );
        return contact;
    }
    
    // Contact (No Profile)
    public static Contact getSimpleNoProfileContact(Id SfAccountId, string FirstName, string LastName, string TechSUNId, string WebsiteId, string ProfessionalEmail, string PersonalEmail, string TeamEmail)
    {
        Contact contact = new Contact 
            (
                AccountId = SfAccountId
                , recordtypeId = ObjectUtil.getRecordTypeId('Contact', 'Distribution Contact')
                , FirstName = FirstName
                , LastName = LastName
                , Salutation = 'Mr'
                , WebsiteCompany__c = 'Carmignac coorp'
                , WebsiteLogin__c = 'test'+System.now().getTime()+'@carmignac.com'
                , WebsiteLanguage__c = 'French'
                , WebsiteCountry__c = 'FR'
                , WebsiteRole__c = '1'
                , Address1__c = '12 Avenue du Général de Gaulle'
                , Address2__c = 'Zone Industrielle'
                , City__c = 'Paris'
                //, Country__c = 'FR'
                , PostalCode__c = '75009'
                , Technical_ID__c = Decimal.valueOf(TechSUNId) 
                , TECH_WebSiteID__c = String.valueOf(Math.round(Math.random()*1000)) + FirstName
                , Email = ProfessionalEmail
                , PersonalEmail__c = PersonalEmail
                , TeamEmail__c = TeamEmail
                , Title = 'Maitre'
                , Source__c = 'Web'
            );
        return contact;
    }
    
    public static Opportunity getSimpleOpportunity(){
        Account accountX = getSimpleAccount();
        insert accountX;
        Opportunity newOpportunity  = new Opportunity();       
        
        newOpportunity.Name         = 'word' + math.rint(math.random() * 100000);
        newOpportunity.CloseDate    = Date.today();
        newOpportunity.StageName    = 'New opportunity';       
        newOpportunity.Account = accountX;       
        return newOpportunity;
        
    }
    
    public static Contact getSimpleNoProfileContact()
    {        
        Account account = getSimpleAccount();
        insert account;
        Contact contact = new Contact 
            (
                AccountId = account.id
                , recordtypeId = ObjectUtil.getRecordTypeId('Contact', 'Distribution Contact')
                , FirstName = 'first'
                , LastName = 'Last'
                , WebsiteCompany__c = 'Carmignac coorp'
                , WebsiteLogin__c = 'test'+System.now().getTime()+'@carmignac.com'
                , WebsiteLanguage__c = 'French'
                , WebsiteCountry__c = 'FR'
                , WebsiteRole__c = '1'
                , Address1__c = '12 Avenue du Général de Gaulle'
                , Address2__c = 'Zone Industrielle'
                , City__c = 'Paris'
                //, Country__c = 'FR'
                , PostalCode__c = '75009'
                , Technical_ID__c = Math.round(Math.random()*100000)
                , TECH_WebSiteID__c = String.valueOf(Math.round(Math.random()*10000)) + 'TE'             
                , Email = 'mail@test.com'
                , PersonalEmail__c = 'mail@test.com'
                , TeamEmail__c = 'mail@test.com'
                , Title = 'Maitre'
                
            );
        return contact;
    }
    
    public static Lead getSimpLeadTestSetProfile()
    {
        
        Lead lead = new Lead 
            (
                recordtypeId = RECORDTYPE_ID_PROSPACE
                , Company = 'Company'
                , FirstName = 'Lead'
                , LastName = 'Test'
                , WebsiteCompany__c = 'Carmignac coorp'
                , WebsiteLogin__c = 'test'+System.now().getTime()+'@carmignac.com'
                , WebsiteLanguage__c = 'French'
                , WebsiteCountry__c = 'FR'
                , Technical_ID__c = Math.round(Math.random()*1000)
                , Email = 'test'+System.now().getTime()+'@carmignac.com'
                , Status = null
                , Street = '3 Rue de Bercy'
                , City = 'Paris'
                , Country = 'France'
                , PostalCode = '75012'
                , Title = 'Maitre'
                
            );
        return lead;
    }
    
    // Contact with password reseted and for setting profile
    public static Contact getSimpleContactToSetProfile(Id SfAccountId, string FirstName, string LastName, string TechSUNId, string WebsiteId, string ProfessionalEmail, string PersonalEmail, string TeamEmail)
    {
        Contact contact = new Contact 
            (
                AccountId = SfAccountId
                , recordtypeId = ObjectUtil.getRecordTypeId('Contact', 'Distribution Contact')
                , FirstName = FirstName
                , LastName = LastName
                , Salutation = 'Mr'
                , WebsiteCompany__c = 'Carmignac coorp'
                , WebsiteLogin__c = 'test'+System.now().getTime()+'@carmignac.com'
                , WebsiteLanguage__c = 'French'
                , WebsiteCountry__c = 'FR'
                , Address1__c = '1 Place Vendôme'
                , Address2__c = 'Musée du louvre'
                , City__c = 'Paris'
                //, Country__c = 'FR'
                , PostalCode__c = '75001'
                , Technical_ID__c = Decimal.valueOf(TechSUNId) 
                , TECH_WebSiteID__c = String.valueOf(Math.round(Math.random()*1000))            
                , Email = ProfessionalEmail
                , PersonalEmail__c = PersonalEmail
                , TeamEmail__c = TeamEmail
                , Title = 'Maitre'
                , Website_Reset_Password__c = true
                , Source__c = 'Website'
            );
        return contact;
    }
    
    /* Segmentation
    public static Segmentation__c getSimpleSegmentation(Id SfAccountId)
    {
        Segmentation__c segmentation = new Segmentation__c 
            (
                Company__c = SfAccountId,
                DistributorType__c = 'Bank',
                SubType__c = 'Private Banking',
                InvestmentDecision__c = 'Wholesale',
                FinalDistribution__c = 'Retail',
                InvestmentVehicle__c = 'N/A'
            );
        return segmentation;
    }*/
    
    // Communication
    public static Communication__c getSimpleCommunication(String stringsTECH_WebsiteIds)
    {
        Communication__c communication = new Communication__c 
            (
                TECH_CommunicationWebsiteId__c = stringsTECH_WebsiteIds
            );
        return communication;
    }
    
    // Communication Subscription
    public static CommunicationSubscription__c getSimpleCommunicationSubscription(Id Contact, Id Communication)
    {
        CommunicationSubscription__c communicationSubscription = new CommunicationSubscription__c 
            (
                Contact__c = Contact,
                Communication__c = Communication
            );
        return communicationSubscription;
    }
    
    public static RelationshipStatus__c getSimpleRelationshipStatus(Id SfAccountId)
    {
        RelationshipStatus__c relationshipstatus = new RelationshipStatus__c 
            (
                
            );
        return relationshipstatus;
    }
    
    // Account
    public static Account getSimpleAccount()
    {
        
        
        Account account = new Account 
            (
                Name = 'word' + math.rint(math.random() * 100000),
                LegalForm__c = 'SARL (Société Anonyme à Responsabilité Limitée)',
                BusinessDevelopmentRegion__c = 'BP_FR',
                BillingCountry = 'France',
                Distributor_Type__c = 'Bank',
                Sub_Type__c = 'Private Banking',
                In__c = 'Wholesale',
                Final_Distribution__c = 'Retail',
                Investment_vehicle__c = 'N/A'
                //GAM__c = GAM.Id
            );
        return account;
    }
    
    //Global Account
    public static Account getSimpleGlobalAccount()
    {
       
        
        Account account = new Account 
            (
                recordtypeId = ObjectUtil.getRecordTypeId('Account', 'Global Account'),
                Name = 'GAM' + math.rint(math.random() * 100000),
                LegalForm__c = 'SARL (Société Anonyme à Responsabilité Limitée)',
                BusinessDevelopmentRegion__c = 'BP_FR',
                BillingCountry = 'France',
                Distributor_Type__c = 'Bank',
                Sub_Type__c = 'Private Banking',
                In__c = 'Wholesale',
                Final_Distribution__c = 'Retail',
                Investment_vehicle__c = 'N/A'
                //GAM__c = GAM.Id
                
            );
        return account;
    }    
    
    public static Case getSimpleCase()
    {       
        Case cworkto = new Case 
            (
                recordtypeId = ObjectUtil.getRecordTypeId('Case', 'Data Solution Request'),
                Type = 'Data Solution',
                Status = 'New',
                Origin = 'Email',
                Due_date__c = date.today().addDays(21),
                //DUE DATE
                // REPORT FREQ
                Report_frequency__c = 'Weekly',
                Please_add_Carmignac_Product__c = true
                
            );
        return cworkto;
    }  
    
    public static Campaign getSimpleCampaignEvents()
    {
        Campaign camp1 = new Campaign 
            (
                recordtypeId = ObjectUtil.getRecordTypeId('Campaign', 'Events'),
                CRM_User__c= TestFactory.getStandardCarmignacUser().Id,
                Status = 'Live',
                Name='TestCampaign',
                Sales_Team__c='FR',
                Type='Survey',
                Event_Local_Start_Time__c = '2017/05/09 12:00',
                Event_Local_End_Time__c = '2017/05/09 18:00',
                Start_Date_Time__c= Datetime.now(),
                End_Date_Time__c= Date.today().addDays(1)
            );
        return camp1;
    }

    public static Campaign getCampaignNewsletter() {
        Campaign camp1 = new Campaign
            (
            recordtypeId = RecordTypeUtil.getRecordTypeIdByDeveloperName(Campaign.SObjectType, 'Newsletters'),
            CRM_User__c = TestFactory.getStandardCarmignacUser().Id,
            Description = 'Test',
            Name = 'TestCampaign',

            Newsletter_Country__c = 'France;Italy',
                    Language__c = 'FR;IT'
            );
        return camp1;
    }
/*
    public static NDA__c getNDA()
    {
        return getNDA('NDA_Classic');
    }

    public static NDA__c getNDA(String recordType)
    {
        Id rt = RecordTypeUtil.getRecordTypeIdByDeveloperName(NDA__c.SObjectType, recordType);
        NDA__c nda = new NDA__c(
                Stage__c = 'To update',
                Signatory__c = 'CGL',
                Purpose__c = 'Regulatory',
                Type__c = 'CRR',
                TypeOfDataToSend__c = 'Other',
                RecordTypeId = rt
        );
        return nda;
    }
*/
    public static Campaign getSimpleCampaignEventsEtouhchesNotSend()
    {
        //
        Profile profile = getSimpleCarmignacProfile();
        
        
        UserRole usrole = getSimpleRole();
        
        User TechUserToinsert = new User
            (
                
                alias = 'TechUs'
                , email='userTech'+System.now().getTime()+'@carmignac.com' 
                , emailencodingkey='ISO-8859-1'
                , userroleId =usrole.Id
                , Phone='+3312345678'
                , firstname='userTech' 
                , lastname='userTest' 
                , languagelocalekey='fr' 
                , localesidkey='fr_FR_EURO'
                , ProfileId = profile.Id
                , timezonesidkey='Europe/Paris'
                , username='userTech'+System.now().getTime()+'-crm@carmignac.com'
                , TECH_UserEmail__c = 'TECH_UserEmail'+System.now().getTime()
                //, TECH_UserExternalID__c = '46579864513'
                , Position__c = 'Business Developer'
                //  , BusinessDevelopmentRegions__c = 'France'
                , IsActive = true
                , BypassApexTriggers__c = ''
                , BypassProcessBuilders__c = false
                , BypassValidationRules__c = false
                , BypassWorkflowRules__c = false
            );
       insert TechUserToinsert ;  
        
        Campaign TechCamp = new Campaign ();
            
            TechCamp.recordtypeId = ObjectUtil.getRecordTypeId('Campaign', 'Events');
            TechCamp.CRM_User__c=TechUserToinsert.Id; 
            TechCamp.Status = 'Pre-Event';
            TechCamp.Name='techTestCamp';
            TechCamp.Sales_Team__c='FR';
            //Etouches_invitation__c=true,
            TechCamp.Type='Investment Professional Presentation';
            TechCamp.Start_Date_Time__c= Datetime.now();
            TechCamp.End_Date_Time__c= Date.today().addDays(30);
            TechCamp.Event_Local_Start_Time__c = '2017/05/09 12:00';
            TechCamp.Event_Local_End_Time__c = '2017/05/09 18:00';
            TechCamp.Address_1__c='place vendome';
            TechCamp.Address_2__c='Pays bas';
            TechCamp.Post_Code__c='75001';
            TechCamp.City__c='Paris Test';
            TechCamp.Country__c='France';
            TechCamp.Location_name__c= '2ème étage';
            TechCamp.Map_to_Venue__c='www.carmignac.com';
            TechCamp.Maximum_registration__c= 10.0;
            TechCamp.Local_zone__c ='28';
            
       
        /*Campaign TechCamp = new Campaign 
(
recordtypeId = ObjectUtil.getRecordTypeId('Campaign', 'Events'),
CRM_User__c=TechUserToinsert.Id,
Status = 'Pre-Event',
Name='TechCAmp',
Sales_Team__c='FR',
//Etouches_invitation__c=true,
Type='Investment Professional Presentation',
Start_Date_Time__c= Datetime.now(),
End_Date_Time__c= Date.today().addDays(30),
Event_Local_Start_Time__c = '2017/05/09 12:00',
Event_Local_End_Time__c = '2017/05/09 18:00',
Address_1__c='place vendome',
Address_2__c='Pays bas',
Post_Code__c='75001',
City__c='Paris Test',
Country__c='France',
Location_name__c= '2ème étage',
Map_to_Venue__c='www.carmignac.com',
Maximum_registration__c= 10.0,
Local_zone__c ='28'
);*/
        return TechCamp;
    }
    
    public static Campaign getSimpleCampaignEventsEtouhchesTOSend()
    {
        
        Campaign camp1 = new Campaign 
            (
                recordtypeId = ObjectUtil.getRecordTypeId('Campaign', 'Events'),
                CRM_User__c= TestFactory.getStandardCarmignacUser().Id,
                Status = 'Pre-Event',
                Name='TestCampaignEtouches',
                Sales_Team__c='FR',
                Etouches_invitation__c=true,
                Type='Investment Professional Presentation',
                Start_Date_Time__c= Datetime.now(),
                End_Date_Time__c= Date.today().addDays(30),
                Event_Local_Start_Time__c = '2017/05/09 12:00',
                Event_Local_End_Time__c = '2017/05/09 18:00',
                Address_1__c='place vendome',
                Address_2__c='Pays bas',
                Post_Code__c='75001',
                City__c='Paris Test',
                Country__c='France',
                Location_name__c= '2ème étage',
                Map_to_Venue__c='www.carmignac.com',
                Maximum_registration__c= 10.0,
                Local_zone__c ='28'
            );
        return camp1;
    }
    
    public static EM023_Log.errorToLog getSimpleLogToInsert()
    {
        EM023_Log.errorToLog log1 = new EM023_Log.errorToLog();
        log1.Data='data';
        log1.dateCreate=Datetime.now();
        log1.error='eror log';
        log1.interfaceName='InterfaceName';
        
        return log1;
    }
    
    public static Interface_Log__c getSimpleLogEtouchesToInsert()
    {
        
        Interface_Log__c log1 = new Interface_Log__c(
            
            Interface_Name__c='TestEtouches'
            ,Process_Id__c='123456'  
        );
        return log1;
    }   
    public static void createCustomSettings(){
        
        WebserviceParameters__c param = new WebserviceParameters__c(
            Name ='CarmignacWebSite', 
            Endpoint__c='https://qa.eiseverywhere.com/api/v2',
            key__c= 'e3ffd78336f06f924a3ffc00b8f43994c68f4aa7=',
            Token__c = 'Ub57+fu2p/4KcaqIRNUNQD9HV8nWid+7flRBxbskZIv/DWkaZG0+e6H6ZcjPaAoAGqOtjSq4tHh9ChxUChZdZw',   
            accountid__c='4740');
        
        insert param;
        
        
    }

    public static Legal_Entity__c getLegalEntity(Id accountId)
    {
        Legal_Entity__c testLegalEnity = new Legal_Entity__c
            (
                Name= 'Test Entity',
                LEI__c = '5067007V6269EHSP3295',
                Company__c = accountId
            );
        return testLegalEnity;
    }

    public static Grid__c getGrid(){
        Grid__c franceGrid = new Grid__c(Name = 'France S5');
        return franceGrid;
    }

    public static Convention__c getAgreement(Id accountId, Id gridId){

        Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);

        Convention__c masterAgreement = new Convention__c(Name = 'ConventionAgreement', Grid__c = gridId,  Company__c = accountId,
                Countries_of_Distribution__c = 'AL', Code_Type__c = 'Distribution Agreement', Agreement_Type__c = 'Master',
                RecordTypeId = agmRtMap.get('Request_Agreement'));

        return masterAgreement;
    }

    public static Agreement_Role__c getAgreementRole(Id agreementId, Id legalEntityId){

        Agreement_Role__c role = new Agreement_Role__c(Agreement__c = agreementId, Legal_Entity__c = legalEntityId, Role__c = 'Counterparty – Distributor / Delegate');

        return role;
    }
     
    public static KYD_Due_Diligence_Oversight__c getKYCheckList(Id legalEntityId)
    {
        KYD_Due_Diligence_Oversight__c testCheckList = new KYD_Due_Diligence_Oversight__c
            (
                Name='Test List',
                LegalEntity__c = legalEntityId
            );
        return testCheckList;
    }    
    
    public static KYD_Document__c getKYDocument(Id checkListId)
    {
        KYD_Document__c testDocList = new KYD_Document__c
            (
                Name='Test Doc' ,
                KYD_Due_Diligence_Oversight__c = checkListId
            );
        return testDocList;
    }       
   
}