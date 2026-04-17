/**
 * Created by Saad on 30/05/2022.
 */

@IsTest
private class OpportunityAP01Test
{
    @IsTest
    static void testBehavior()
    {
        CommonTestData.getData();

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Case newCase = new Case
            (
                    Type = 'Data Solution',
                    Status = 'New',
                    Origin = 'Email',
                    Due_date__c = Date.today() + 22,
                    Report_frequency__c = 'Weekly',
                    Please_add_Carmignac_Product__c = true,
                    Opportunity__c = opp.Id
            );
        insert newCase;

        Test.startTest();
        opp.Due_Diligence_Feedback__c = 'Test';
        update opp;
        Test.stopTest();
    }
}