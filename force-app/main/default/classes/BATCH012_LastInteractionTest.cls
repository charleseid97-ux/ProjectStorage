/**
 * @author  Saad LOZZI
 * @date    30/06/2021
 * @details ...
 *
 * -- History
 * -- Date        Name                       Version  Remarks
 * -- ----------- -------------------------  -------  ---------------------------------------
 * -- 30/06/2021  Saad LOZZI                  1.0      Create
 */

@IsTest
private class BATCH012_LastInteractionTest
{
    private static final String QUERY_CONTACT = '' +
        'SELECT ' +
        '   Id, ' +
        '   AccountId,' +
        '   CreatedDate, ' +
        '   CorporateTitle__c, ' + 
        '   First_Last_name__c, ' +
        '   Last_interaction__c,' +
        '   Last_Meeting_Call__c, ' +
        '   Last_Newsletter_sent__c, ' +
        '   Last_Event_attendance__c, ' +
        '   Last_Event_attendance_Type__c ' +
        '   FROM ' +
        '       Contact';

    private static final Datetime LAST_EVENT = Datetime.newInstance(2021, 06, 29, 18, 0, 0);
    private static final Datetime LAST_MEETING = Datetime.newInstance(2021, 06, 30, 17, 0, 0);
    private static final Datetime LAST_NEWSLETTER = Datetime.newInstance(2021, 06, 30, 19, 0, 0);

    private static final Datetime LAST_EVENT_CONTACT = Datetime.newInstance(2021, 06, 30, 15, 0, 0);
    private static final Datetime LAST_MEETING_CONTACT = Datetime.newInstance(2021, 06, 30, 14, 0, 0);
    private static final Datetime LAST_NEWSLETTER_CONTACT = Datetime.newInstance(2021, 06, 30, 16, 0, 0);

    @TestSetup
    private static void setup()
    {
        Account aAccount = new Account(
            BusinessDevelopmentRegion__c = 'BP_FR',
            BillingCountryCode = 'FR',
            Name = 'Test'
        );

        Account aAccount2 = new Account(
                BusinessDevelopmentRegion__c = 'BP_FR',
                BillingCountryCode = 'FR',
                Name = 'Test Account without Contact'
        );

        insert new List<Account>{aAccount, aAccount2};

        Contact aContact = new Contact(
            Source__c = 'Event',
            Email = 'test@test.test',
            LastName = 'Test',
            AccountId = aAccount.Id,
            CorporateTitle__c = 'Associate',
            Last_Meeting_Call__c = LAST_MEETING_CONTACT,
            Last_Event_attendance__c = LAST_EVENT_CONTACT,
            Last_Newsletter_sent__c = LAST_NEWSLETTER_CONTACT
        );

        insert aContact;

        Test.setCreatedDate(aContact.Id, Datetime.newInstance(2012,12,12));
        Test.setCreatedDate(aAccount.Id, Datetime.newInstance(2012,12,12));
        Test.setCreatedDate(aAccount2.Id, Datetime.newInstance(2012,12,12));

        insert new Event(
            WhoId = aContact.Id,
            EndDateTime = LAST_EVENT,
            Type = 'Call',
            ActivityDateTime = LAST_EVENT
        );
    }

    @IsTest
    private static void testBehavior()
    {
        BATCH012_LastInteraction batch = new BATCH012_LastInteraction(QUERY_CONTACT);

        SCH_LastInteraction_Full sh1 = new SCH_LastInteraction_Full();
        String sch1 = '0 0 23 * * ?'; 

        SCH_LastInteraction_Delta sh2 = new SCH_LastInteraction_Delta();
        String sch2 = '0 0 23 * * ?'; 

        Test.startTest();
        System.schedule('Test Sche1', sch1, sh1);
        System.schedule('Test Sche2', sch2, sh2);
        Database.executeBatch(batch);
        Test.stopTest();

        Account aAccount =
        [
            SELECT
                CreatedDate,
                Last_Contact_involved__c,
                Last_interaction_with_contact__c,
                Last_contact_interaction_Corporate_Title__c
            FROM
                Account
            LIMIT 1
        ];

        Contact aContact =
        [
            SELECT
                CreatedDate,
                First_Last_name__c,
                CorporateTitle__c,
                Last_Interaction__c
            FROM
                Contact
        ];

        System.assertEquals(LAST_NEWSLETTER_CONTACT, aAccount.Last_interaction_with_contact__c);
        System.assertEquals(LAST_NEWSLETTER_CONTACT, aContact.Last_Interaction__c);
        System.assertEquals(aContact.First_Last_name__c, aAccount.Last_Contact_involved__c);
        System.assertEquals(aContact.CorporateTitle__c, aAccount.Last_contact_interaction_Corporate_Title__c);
    }
}