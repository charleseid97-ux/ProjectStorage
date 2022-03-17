/**
 * Created by Saad LOZZI on 07/09/2021.
 */
@IsTest
public with sharing class BATCH014_UnrelAccsLastInteractionTest
{
    private static final Datetime aDATETIME = Datetime.newInstance(2021, 06, 30, 19, 0, 0);
    @TestSetup
    private static void setup()
    {
        Account aAccount = new Account(
                BusinessDevelopmentRegion__c = 'BP_FR',
                BillingCountryCode = 'FR',
                Name = 'Test Account without Contact'
        );
        insert aAccount;

        Test.setCreatedDate(aAccount.Id, aDATETIME);
    }

    @IsTest
    public static void testBehavior()
    {
        String query =  'SELECT '+
                'Id, '+
                'CreatedDate, '+
                'Last_interaction_with_contact__c '+
                'FROM '+
                'Account '+
                'WHERE '+
                'Id NOT IN (SELECT AccountId FROM Contact)';

        BATCH014_UnrelatedAccsLastInteraction batch = new BATCH014_UnrelatedAccsLastInteraction(query);

        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();

        System.assertEquals(1, [SELECT Id FROM Account WHERE Last_interaction_with_contact__c != NULL].size());
        System.assertEquals(
                aDATETIME,
                [SELECT Id, CreatedDate FROM Account WHERE Last_interaction_with_contact__c != NULL].CreatedDate
        );
    }
}