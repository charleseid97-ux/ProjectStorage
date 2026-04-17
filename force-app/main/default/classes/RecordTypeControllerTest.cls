/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 07-15-2024
 * @last modified by  : SILA Nicolas
**/
@isTest
public class RecordTypeControllerTest {
    @isTest
    static void testGetRecordTypes() {
        // Get existing record types for Case
        List<RecordType> existingRTs = [SELECT Id, Name, DeveloperName 
                                        FROM RecordType 
                                        WHERE SObjectType = 'Case' 
                                        AND IsActive = true 
                                        AND Name != 'Master' 
                                        AND DeveloperName != 'Sub_Publication_Request' 
                                        AND DeveloperName != 'Sub_Translation_Request'];

        Test.startTest();
        List<RecordTypeController.RecordTypeWrapper> result = RecordTypeController.getRecordTypes();
        Test.stopTest();
        
        // Assertions
        system.debug(existingRTs.size());
        System.assertEquals(existingRTs.size(), result.size(), 'Number of returned record types should match existing ones');
        
        for(RecordTypeController.RecordTypeWrapper rtw : result) {
            Boolean found = false;
            for(RecordType rt : existingRTs) {
                if(rt.Id == rtw.id) {
                    found = true;
                    break;
                }
            }
            System.assert(found, 'Each returned record type should exist in the org');
            
            if(rtw.Name == 'Translation Request') {
                System.assertEquals('/lightning/n/TranslationRequests', rtw.url, 'Incorrect URL for TranslationRequest');
            }else if(rtw.Name == 'Marketing Feedback'){
                System.assertEquals('/lightning/n/Content_Feedback', rtw.url, 'Incorrect URL for Marketing Feedback');
            } else {
                System.assert(rtw.url.startsWith('/lightning/o/Case/new?backgroundContext=lightning/o/Case/list?filterName=__Recent&recordTypeId='), 'Incorrect URL format for non-TranslationRequest record type');
            }
        }
    }
    
    @isTest
    static void testRecordTypeWrapper() {
        String testId = '012000000000000AAA';
        String testName = 'Test Record Type';
        String testDescription = 'This is a test record type';
        String testUrl = '/test/url';
        
        Test.startTest();
        RecordTypeController.RecordTypeWrapper wrapper = new RecordTypeController.RecordTypeWrapper(testId, testName, testDescription, testUrl);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(testId, wrapper.id, 'Id mismatch');
        System.assertEquals(testName, wrapper.name, 'Name mismatch');
        System.assertEquals(testDescription, wrapper.description, 'Description mismatch');
        System.assertEquals(testUrl, wrapper.url, 'URL mismatch');
    }
}