/**
 * Created by Saad on 28/02/2022.
 */

@IsTest
private class BATCH_KYDSendDocsTest
{
    @IsTest
    static void testBehavior()
    {
        Legal_Entity__c legalE = new Legal_Entity__c();
        insert legalE;

        KYD_Due_Diligence_Oversight__c kyd = new KYD_Due_Diligence_Oversight__c();
        kyd.LegalEntity__c = legalE.Id;
        insert kyd;

        ContentVersion testContentInsert =new ContentVersion();
        testContentInsert.ContentUrl='"https://www.google.com/';
        testContentInsert.Title ='Google.com';
        insert testContentInsert;

        KYD_Document__c doc = new KYD_Document__c(
                Name = 'Test',
                External_Repository_Id__c = 'Google.com',
                KYD_Due_Diligence_Oversight__c = kyd.Id,
                ExternalId__c = 'Test',
                LegalEntity__c = legalE.Id
        );
        insert doc;

        Test.startTest();
        BATCH_KYDSendDocs batch = new BATCH_KYDSendDocs();
        Database.executeBatch(batch, 1);
        Test.stopTest();
    }
}