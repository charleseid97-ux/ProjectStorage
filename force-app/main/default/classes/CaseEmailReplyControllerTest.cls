/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 06-01-2025
 * @last modified by  : Khadija EL GDAOUNI
**/
@isTest
public class CaseEmailReplyControllerTest {
    private static final Id translationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Translation Request').getRecordTypeId();
    private static final Id subTranslationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Sub Translation Request').getRecordTypeId();
    private static final Id subPublicationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Sub Publication Request').getRecordTypeId();
   
    @TestSetup
    static void testSetup() {
        // Create a Case record
        Case wtp = new Case(
            Subject = 'Parent Case',
            RecordTypeId = translationRecordTypeId,
            target_languages__c = 'English',
            Translation_Request_Type__c = 'Translation Only',
            Document_Type__c = 'Biography',
            Sub_Target_language__c = 'Spanish',
            TargetWebsite__c = 'Spain (ES)',
            Source_Language__c = 'English'
        );
        insert wtp;
       
        // Create a Contact record
        Contact c = new Contact(
            LastName = 'LAST',
            FirstName = 'First',
            email = 'first.last@invalid.com',
            Agency_Translation_language__c = 'Spanish',
            Source__c = 'Business Card'
        );
        insert c;
    }
   
    @isTest
    static void getCaseDetails_Test() {
        // Create a Case record
        Case wtp = [SELECT Id FROM Case LIMIT 1];
       
        Test.startTest();
        CaseEmailReplyController.getCaseDetails(wtp.Id);
        Test.stopTest();
    }
   
    @isTest
    static void getEmailsList_Test() {
        // Create a Case record
        Case wtp = [SELECT Id FROM Case LIMIT 1];
       
        Test.startTest();
        List<String> emails = CaseEmailReplyController.getEmailsList(wtp.Id);
        Test.stopTest();
       
        System.assertNotEquals(0, emails.size());
    }
   
    @isTest
    static void sendEmailReply_Test() {
        // Get the test Case record
        Case wtp = [SELECT Id FROM Case LIMIT 1];
        List<String> emails = CaseEmailReplyController.getEmailsList(wtp.Id);
       
        // Create a test EmailMessage record
        EmailMessage originalEmail = new EmailMessage(
            ParentId = wtp.Id,
            Subject = 'Original Email Subject',
            MessageIdentifier = 'test-message-id',
            ThreadIdentifier = 'test-thread-id',
            CcAddress = 'cc1@test.com;cc2@test.com',
            Incoming = false
        );
        insert originalEmail;
       
        // Create test ContentVersion and ContentDocument
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
       
        // Get ContentDocumentId
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        List<String> fileIds = new List<String>{cv.ContentDocumentId};
       
        Test.startTest();
       
        // Test email send with attachment
        CaseEmailReplyController.sendEmailReply(
            wtp.Id,
            String.join(emails, ';'),
            'This is a test email body with attachment!',
            fileIds
        );
       
        // Test email send without attachment
        CaseEmailReplyController.sendEmailReply(
            wtp.Id,
            String.join(emails, ';'),
            'This is a test email body without attachment!',
            new List<String>()
        );
       
        Test.stopTest();
       
        // Verify EmailMessage records were created
        List<EmailMessage> sentEmails = [
            SELECT Id, Subject, HtmlBody, ToAddress, CcAddress
            FROM EmailMessage
            WHERE ParentId = :wtp.Id
            AND Incoming = false
            ORDER BY CreatedDate DESC
        ];
       
        System.assertEquals(3, sentEmails.size(), 'Expected 3 EmailMessage records (1 original + 2 replies)');
 
       
            }
}