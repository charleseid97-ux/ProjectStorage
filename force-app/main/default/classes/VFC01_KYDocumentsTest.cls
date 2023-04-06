/**
*@author GLC
*@Date Creation 11/5/2021
*@Date modification 
*@description test class to update document status from controller VPC01_KYDDocuments
*/
@isTest 
public class VFC01_KYDocumentsTest
{
    public static testMethod void testVFC01_KYDocuments() 
    {
        List<KYD_Document__c> docList = new List<KYD_Document__c>();
        User u = TestFactory.getCarmignacUserTestApex();

        System.runAs(u) {
            //create test data
            SingleRequestMock fakeUMEResp = new SingleRequestMock(200, 'OK', 'jsonUMEStr', null);
            Test.setMock(HttpCalloutMock.class, fakeUMEResp);
            
            Legal_Entity__c testLegalEnity =TestFactory.getLegalEntity();
            insert testLegalEnity;
    
            Account testAcc =TestFactory.getSimpleAccount();
            testAcc.recordtypeId = ObjectUtil.getRecordTypeId('Account', 'Distributor');
            testAcc.LegalEntity__c = testLegalEnity.id;
            insert testAcc;
            
            KYD_Due_Diligence_Oversight__c testCheckList =TestFactory.getKYCheckList(testLegalEnity.Id);
            insert testCheckList;
            
            KYD_Document__c testDoc =TestFactory.getKYDocument(testCheckList.Id);
            testDoc.ExternalId__c = Integer.valueof((Math.random() * 9999999)) + 'test';
            docList.add(testDoc);
            insert docList;

            testDoc.Status__c = Label.KYCDocStatus;
            update testDoc;
            // test save method
            Test.StartTest(); 

                PageReference pageRef = Page.VFP01_KYDocuments;
                Test.setCurrentPage(pageRef);
                pageRef.getParameters().put('id',testDoc.id);
                ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(docList);
                VFC01_KYDocuments controllerKYDoc = new VFC01_KYDocuments(stdSetController);
                PageReference resultDoSave =controllerKYDoc.updateStatus();
                PageReference resultDoSavePending =controllerKYDoc.updateStatusToPending();
                PageReference resultDoSaveReceived =controllerKYDoc.updateStatusToReceived();

                
            Test.StopTest();
        }
    }
}