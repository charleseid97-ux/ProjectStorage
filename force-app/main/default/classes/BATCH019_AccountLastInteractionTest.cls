/**
 * Created by Saad on 07/08/2022.
 */

@IsTest
private class BATCH019_AccountLastInteractionTest
{
    private static final Datetime LAST_INTERACTION = Datetime.newInstance(2023, 06, 30, 17, 0, 0);

    @TestSetup
    private static void setup()
    {
        Account aAccount = new Account(
                BusinessDevelopmentRegion__c = 'BP_FR',
                BillingCountryCode = 'FR',
                Name = 'Test'
        );

        insert aAccount;

        Contact aContact = new Contact(
                Source__c = 'Event',
                Email = 'test@test.test',
                LastName = 'Test',
                AccountId = aAccount.Id,
                CorporateTitle__c = 'Associate',
                Last_Event_attendance__c = LAST_INTERACTION,
             	ContactStatus__c = 'true'
        );

        insert aContact;

        Contact aContact2 = new Contact(
                Source__c = 'Event',
                Email = 'test@test.test',
                LastName = 'Test',
                AccountId = aAccount.Id,
                CorporateTitle__c = 'Associate',
            	ContactStatus__c = 'true'
        );

        insert aContact2;
    }

    @IsTest
    static void testBehavior()
    {
        BATCH019_AccountLastInteraction batch = new BATCH019_AccountLastInteraction();

        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();

        System.assertEquals(
                [SELECT Last_interaction_with_contact__c FROM Account].Last_interaction_with_contact__c,
                LAST_INTERACTION
        );
    }
}