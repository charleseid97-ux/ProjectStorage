/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 06-18-2024
 * @last modified by  : SILA Nicolas
**/
@isTest
private class FileUploadMultiControllerTest {
   
   @isTest
   static void testUploadNewFile() {
       // Create test data
       List<FileUploadMultiController.FileDataWP> fileDataList = new List<FileUploadMultiController.FileDataWP>();
       FileUploadMultiController.FileDataWP fileData1 = new FileUploadMultiController.FileDataWP();
       fileData1.fileName = 'Test_File_1.txt';
       fileData1.contentVersionId = createContentVersion(fileData1.fileName).Id;
       fileDataList.add(fileData1);
       
       FileUploadMultiController.FileDataWP fileData2 = new FileUploadMultiController.FileDataWP();
       fileData2.fileName = 'Test_File_2.pdf';
       fileData2.contentVersionId = createContentVersion(fileData2.fileName).Id;
       fileDataList.add(fileData2);
       
       String recordId = createRecord().Id;
       String fileData = JSON.serialize(fileDataList);
       String filePrefix = 'Test_';
       
       Test.startTest();
       String result = FileUploadMultiController.uploadNewFile(recordId, fileData, filePrefix, true, false);
       Test.stopTest();
       
       System.assertNotEquals(null, result, 'The method should return a non-null value');
       System.assertEquals('success', result, 'The method should return "success" for successful execution');
       
       List<ContentDocumentLink> cdLinks = [SELECT Id, LinkedEntityId, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :recordId];
       System.assertNotEquals(0, cdLinks.size(), 'ContentDocumentLinks should be created');
   }
   
   // Helper method to create a test record
   private static Case createRecord() {
        Case parentCase = new Case(
            Subject = 'Parent Case',target_languages__c='Italian;English',Translation_Request_Type__c = 'Translation Only',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Translation Request').getRecordTypeId()
        );
        insert parentCase;
        return parentCase;
   }
   
   // Helper method to create a test ContentVersion
   private static ContentVersion createContentVersion(String fileName) {
       ContentVersion cv = new ContentVersion(
           Title = fileName,
           PathOnClient = fileName,
           VersionData = Blob.valueOf('Test Content'),
           IsMajorVersion = true
       );
       insert cv;
       return cv;
   }
}