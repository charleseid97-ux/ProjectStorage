/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 11-02-2025
 * @last modified by  : Thanina YAYA
**/
@isTest
private class CTL_MeetingNotesTest {
     @TestSetup
    static void createData(){

        //Create Users
        /*User businDev = TestDataFactory.getUser(TestDataFactory.getProfileIdByName('Carmignac - Business Developer'), 'busDev', 'Test', 'busTest','Business Developer');
        insert businDev;
        User crm = TestDataFactory.getUser(TestDataFactory.getProfileIdByName('Carmignac - CRM'), 'crm', 'Test', 'crmTest','CRM');
        insert crm;*/

        EnhancedLetterhead el = new EnhancedLetterhead(
            Name='Also test',
            LetterheadFooter='test'
        );
        insert el;
        EmailTemplate et = New EmailTemplate(
            htmlvalue = '',
            subject = 'test meeting note',
            EnhancedLetterheadId = el.id,
            DeveloperName='TestMeetingNote',
            Name = 'Test Meeting Note',
            TemplateType='custom',
            TemplateStyle='none',
            isActive=true,
            RelatedEntityType = 'Meeting_Note__c',
            UiType='SFX',
            Encoding='ISO-8859-1'
        );
        insert et;
        
        //Create Client Account
        Account client = TestDataFactory.getAccount('Client Test', TestDataFactory.ACCOUNT_DISTRIBUTOR_RECID);
        insert client;
        //Create Client Contact
        Contact cc = TestDataFactory.getContact(client, 'Client-test', 'Contact','true',TestDataFactory.CONTACT_DISTRIBUTION_RECID);
        insert cc;
        //Create Carmignac Account
        Account carmiAcc = TestDataFactory.getAccount('CARMIGNAC', TestDataFactory.ACCOUNT_INTERNAL_RECID);
        insert carmiAcc;
        //Create Carmignac Contact
        Contact carmiCont = TestDataFactory.getContact(carmiAcc, 'Carmignac', 'Contact','true',TestDataFactory.CONTACT_INTERNAL_RECID);
        insert carmiCont;
        //Create Products
        Strategy__c stratA = new Strategy__c(Name='S1', AssetClass__c='Equity', SubAssetClass__c='Global', Code__c = 'S01');
        insert stratA;
        Strategy__c stratI = new Strategy__c(Name='S2', AssetClass__c='Equity', SubAssetClass__c='Global', Code__c = 'S02');
        insert stratI;
        Product__c fundA = TestDataFactory.getProduct(TestDataFactory.PRODUCT_FUND_RECID, 'fund', 'Test Fund active', true); // Active Fund
        insert fundA;

        //Create Meeting note
        Meeting_Note__c mn = TestDataFactory.getMeetingNote('Meeting from test class',client,'Meeting',true,false,null,'It s just a test!');
        insert mn; 
    }

    @IsTest
    public static void getOrgIdTest(){
        String orgId = UserInfo.getOrganizationId();
        String res = '';
        Test.startTest();
        res = CTL_MeetingNotes.getOrgId();
        Test.stopTest();
        System.assertEquals(orgId, res);
    }

    @IsTest
    public static void getNeededContactsTest(){
        List<Contact> res = new List<Contact>();
        Test.startTest();
        res = CTL_MeetingNotes.getNeededContacts();
        Test.stopTest();
        System.assertEquals(1, res.size());
        System.assertEquals([SELECT Id FROM Contact WHERE ContactStatus__c = 'true' AND Account.Name = 'CARMIGNAC'].size(), res.size());
    }

    @IsTest
    public static void getClientContactsTest(){
        List<Contact> res = new List<Contact>();
        Test.startTest();
        res = CTL_MeetingNotes.getClientContacts('Client-test', new List<String>());
        Test.stopTest();
        System.assert(res[0].Name.contains('Client'));
        System.assertEquals(1, res.size());
        System.assertNotEquals([SELECT Id FROM Contact WHERE ContactStatus__c = 'true'].size(), res.size());
    }

    @IsTest
    public static void getUsersTest(){
        List<User> res = new List<User>();
        Test.startTest();
        res = CTL_MeetingNotes.getUsers();
        Test.stopTest();
        System.assert(!res.isEmpty());
    }

    @IsTest
    public static void getProductsTest(){
        List<Strategy__c> res = new List<Strategy__c>();
        Test.startTest();
        res = CTL_MeetingNotes.getProducts('');
        Test.stopTest();
        System.assertEquals(2, res.size());
        //System.assertEquals('Strategy', res[0].RecordType.Name);
        //System.assertNotEquals([Select Id FROM Product__c].size(), res.size());
    }

    @IsTest
    public static void createRelatedObjectsTest(){
        CTL_MeetingNotes.CreationWrapper res = new CTL_MeetingNotes.CreationWrapper(null, null);
        Meeting_Note__c mn = [SELECT Id FROM Meeting_Note__c LIMIT 1];
        Event evt = new Event(
            StartDateTime = DateTime.now(),
            EndDateTime = DateTime.now(),
            Subject = 'Event for Test',
            Meeting_Note__c = mn.Id
        );
        List<ClientInterest__c> clInt = new List<ClientInterest__c>();
        clInt.add(new ClientInterest__c(
            Strategy__c = [SELECT Id FROM Strategy__c LIMIT 1].Id,
            Interest__c = 3,
            MeetingNote__c = mn.Id
        ));

        List<String> contPart = new List<String>();
        for(Contact cont:[SELECT Id from Contact]) contPart.add(cont.Id);
        List<Task> tasks = new List<Task>();
        tasks.add(new Task(
            Subject = 'Task for Meeting Note',
            WhatId = mn.Id
        ));

        Test.startTest();
        res = CTL_MeetingNotes.createRelatedObjects(evt, contPart, clInt, tasks);
        Test.stopTest();
        System.assert(res.success);
    }

    @IsTest
    public static void getEmailTemplateTest(){
        Map<String, String> res = new Map<String, String>();
        Test.startTest();
        res = CTL_MeetingNotes.getEmailTemplate('Test Meeting Note');
        Test.stopTest();
        System.assert(res.containsKey('Subject'));
        System.assertEquals([SELECT Id FROM EmailTemplate WHERE Name = 'Test Meeting Note' LIMIT 1].Id, res.get('Id'));
    }

    @IsTest
    public static void sendEmailMeetingTest() {
        Meeting_Note__c mn = [SELECT Id FROM Meeting_Note__c LIMIT 1];
        EmailTemplate et = [SELECT Id, HtmlValue, Subject, DeveloperName, Name, TemplateType, TemplateStyle, IsActive, RelatedEntityType, UiType, Encoding, EnhancedLetterheadId FROM EmailTemplate LIMIT 1];
        List<Contact> contactList = [SELECT Id, LastName, FirstName, Email FROM Contact];
        Boolean res = false;
        Test.startTest();
        res = CTL_MeetingNotes.sendEmailMeeting(et, contactList, mn.Id);
        Test.stopTest();
        System.Debug('debug =>'+res);
    }

    // @IsTest
    // public static void createMeetingNotesFromVideoCallsTest() {
    //     // Create VideoCall records
    //     VideoCall vc = new VideoCall(
    //         Name = 'Test VideoCall',
    //         EndDateTime = DateTime.now(),
    //         StartDateTime = DateTime.now().addHours(-1),
    //         Description = 'Video Call Description',
    //         IntelligenceScore = 90,
    //         VendorMeetingKey ='123sqd1qs2d1sq'
    //     );
    //     insert vc;

    //     // Invoke the method
    //     Test.startTest();
    //     CTL_MeetingNotes.createMeetingNotesFromVideoCalls(new List<Id>{ vc.Id });
    //     Test.stopTest();

    //     // Verify the Meeting Note was created
    //     System.Debug('debug =>' + [SELECT Id FROM Meeting_Note__c WHERE Name = 'Test VideoCall'].size());
    // }
}