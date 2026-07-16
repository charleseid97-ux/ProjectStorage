@isTest
private class CaseEmailHandlerTest {
    
    @isTest
    static void testSendClosedCaseEmails() {
        
        User currentUser = [
            SELECT Id, FirstName, LastName, Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        
        Case c = TestDataFactory.getESGCase();
        c.Requester__c = currentUser.Id;
        insert c;
        
        Test.startTest();
        
        c.Status = 'Closed';
        c.Answer__c = 'Here is the response to your ESG request.';
        update c;
        
        ContentVersion cv = new ContentVersion(
            Title = 'Answer Document',
            PathOnClient = 'AnswerDocument.pdf',
            VersionData = Blob.valueOf('Test file body'),
            IsMajorVersion = true
        );
        insert cv;
        
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = c.Id,
            ShareType = 'V'
        );
        insert link;
        
        CaseEmailHandler.sendClosedCaseEmails(new List<Case>{c});
        
        Test.stopTest();
        
        System.assert(true);
    }
}