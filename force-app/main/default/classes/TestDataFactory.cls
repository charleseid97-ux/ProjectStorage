/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 10-11-2023
 * @last modified by  : Thanina YAYA
**/
@isTest
public class TestDataFactory {
    /** Final Static Variables */
    public final static Id PRODUCT_STRATEDY_RECID = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Strategy').getRecordTypeId();
    public final static Id PRODUCT_FUND_RECID = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
    public final static Id CONTACT_DISTRIBUTION_RECID = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Contact_DistributionContact').getRecordTypeId();
    public final static Id CONTACT_INTERNAL_RECID = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Internal_Carmignac_Contact').getRecordTypeId();
    public final static Id ACCOUNT_DISTRIBUTOR_RECID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Account_Distributor').getRecordTypeId();
    public final static Id ACCOUNT_ULTIMATE_RECID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Ultimate_Parent').getRecordTypeId();
    public final static Id ACCOUNT_GLOBAL_RECID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Account_GlobalAccount').getRecordTypeId();
    public final static Id ACCOUNT_INTERNAL_RECID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Internal_Organisation').getRecordTypeId();

    public static Account getAccount() {
        return new Account(Name='Account For Test',
                          BusinessDevelopmentRegion__c='BP_FR',
                          BillingCountry='France',
                          BillingCity='Paris',
                          BillingStreet='12 place Vendome',
                          BillingPostalCode='75001');
    }
    public static Account getAccount(String name, Id recTypeId){
        return new Account(Name=name,
                          BusinessDevelopmentRegion__c='BP_FR',
                          BillingCountry='France',
                          BillingCity='Paris',
                          BillingStreet='12 place Vendome',
                          BillingPostalCode='75001',
                          RecordTypeId = recTypeId,
                          CompanyStatus__c = 'Active');
    }
    public static Account_Plan__c getAccountPlan(Id accountId) {
        return new Account_Plan__c(Company__c=accountId);
    }
    
    public static CampaignMember getCampaignMember(Id linkedId, Id campaign) {
        CampaignMember cm = new CampaignMember(campaignId=campaign);
        if (Schema.Contact.SObjectType == linkedId.getSobjectType()) {
            cm.contactId = linkedId;
        }
        else {
            cm.LeadId = linkedId;
        }
        return cm;
    }
            
    public static Campaign getCampaign(String recordType) {
        Id recordTypeId = Schema.SObjectType.Campaign.getRecordTypeInfosByName().get(recordType).getRecordTypeId();
        Campaign c = new Campaign(RecordTypeId=recordTypeId,
                                 Name='Test Campaign on ' + DateTime.now(),
                                 Status='Email Sent',
                                 Description='Test Data for Campaign. RecordType: ' + recordType,
                                 Type_of_client__c='All',
                                 Start_Date_Time__c=DateTime.now().addDays(7));
        return c;
    }
    
    public static Contact getContact() {
        Contact c = new Contact(LastName='Last',
                               FirstName='First',
                               email='first.last@invalid.com');
        return c;
    }

    public static Contact getContact(Account acc,String lastName,String firstName,String isActive,Id recTypeId) {
        Contact c = new Contact(LastName= lastName,
                               FirstName= firstName,
                               email=lastName+'.'+firstName+'@test.com',
                               AccountId=acc.Id,
                               ContactStatus__c = isActive,
                               RecordTypeId= recTypeId);
        return c;
    }
    /**
     * @strat : should be a strategy product (recordType = Strategy) , we have a lookup filter on this field in "Client Interest" Object
     */
    /*public static ClientInterest__c getClientInterest(Product__c strat,Integer inter,Meeting_Note__c mn){
        ClientInterest__c ci = new ClientInterest__c(Product__c= strat.Id,
                                                     Interest__c = inter,
                                                     MeetingNote__c = mn.Id);
        return ci;
    }*/
    public static ClientInterest__c getClientInterest(Strategy__c strat,Integer inter,Meeting_Note__c mn){
        ClientInterest__c ci = new ClientInterest__c(Strategy__c= strat.Id,
                                                     Interest__c = inter,
                                                     MeetingNote__c = mn.Id);
        return ci;
    }

    public static Product__c getProduct(Id recId, String code, String name, Boolean isActive){
        return ( new Product__c (RecordTypeId = recId,
                                 Name = code,
                                 Product_Name__c = name,
                                 Validity__c = isActive));
        
    }

    // create meeting note
    public static Meeting_Note__c getMeetingNote(String name,Account acc,String type,Boolean isSales,Boolean isRelation, String topic,String note){
        return (new Meeting_Note__c(Date__c = Date.today(),
                                    Name= name, Company__c = acc.Id,
                                    Meeting_Type__c=type,
                                    SalesPresentation__c= isSales,
                                    RelationshipManagement__c = isRelation,
                                    Note__c=note,Topic__c=topic));
        
    }
    // create Event 
    public static Event getEvent(Meeting_Note__c mn,String subj){
        return (new Event(Subject = subj,
                          Meeting_Note__c = mn.Id,
                          DurationInMinutes = 30,
                          whatId = mn.Company__c,
                          ActivityDateTime = DateTime.newInstance(mn.Date__c.year(), mn.Date__c.month(), mn.Date__c.day())));
    }
    // create Event Relation (as contact participant of an event representing Meeting note)
    public static EventRelation getEventRelation(Contact c,Event e){
        return ( new EventRelation(RelationId = c.Id,
                                   EventId = e.Id,IsInvitee = false,
                                   IsParent = true,IsWhat= false));
    }
    // create tasks for meetingNotes
    public static Task getTask(Meeting_Note__c mn,String des){
        return (new Task(Subject ='follow up - '+mn.Meeting_Type__c+' - '+mn.CompanyName__c, 
                         Description__c =des, 
                         ActivityDate = mn.Date__c.addDays(15), 
                         WhatId = mn.Id, 
                         Priority = 'Normal',Type= 'Follow Up '+mn.Meeting_Type__c));
    }
    //get Profile Id by name.
    public static Id getProfileIdByName(String profName){
        return ([SELECT Id FROM Profile WHERE Name = :profName]?.Id);
    }
    //create User
    public static User getUser(Id profId,String firstN,String lastN,String alias,String pos){
        return (new User(ProfileId = profId,
            FirstName = firstN,
            LastName = lastN,
            Email = firstN+'.'+lastN+'@test.com',
            Username = firstN+'.'+lastN+'-'+ Datetime.now().second() + '@test.com' ,
            alias = alias,
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'fr_FR_EURO',
            EmailEncodingKey = 'ISO-8859-1',
            LanguageLocaleKey = 'fr',
            Position__c = pos, // EX: 'Business Developer'
            BusinessDevelopmentRegions__c = 'BP_FR',
            IsActive = true,
            BypassApexTriggers__c = '',
            BypassProcessBuilders__c = false,
            BypassValidationRules__c = false,
            BypassWorkflowRules__c = false
        ));
    }

    public static List<Preference_Center_Category__mdt> getPreferenceCenterCategory() {
        List<Preference_Center_Category__mdt> prefList = new List<Preference_Center_Category__mdt>();
        
        Preference_Center_Category__mdt prefComm = new Preference_Center_Category__mdt();
        prefComm.MasterLabel = 'Newsletter';
        prefComm.DeveloperName = 'Monthly_Newsletter';
        prefComm.Category__c = 'Communication Type';
        prefComm.Order__c = 0;
        prefList.add(prefComm);

        Preference_Center_Category__mdt prefPreference = new Preference_Center_Category__mdt();
        prefPreference.MasterLabel = 'Equities';
        prefPreference.DeveloperName = 'Equities';
        prefPreference.Category__c = 'Preference';
        prefPreference.Order__c = 0;
        prefPreference.Childs__c = 'Carmignac_Climate_Transition_CC__c:Carmignac Climate Transition (CC);Carmignac_Emergents_CE_PE_UKCE__c:Carmignac Emergents (CE/PE/UKCE)';
        prefList.add(prefPreference);

        Preference_Center_Category__mdt prefInterest = new Preference_Center_Category__mdt();
        prefInterest.MasterLabel = 'Corporate';
        prefInterest.DeveloperName = 'Corporate';
        prefInterest.Category__c = 'Interest';
        prefInterest.Order__c = 0;
        prefList.add(prefInterest);

        return prefList;
    }

    public static Legal_Entity__c getLegalEntity() {
        Legal_Entity__c le = new Legal_Entity__c(
            Name = 'Test'
        );

        return le;
    }
}