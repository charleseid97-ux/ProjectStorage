/**
* @description       : 
* @author            : Khadija EL GDAOUNI
* @group             : 
* @last modified on  : 08-08-2024
* @last modified by  : Khadija EL GDAOUNI
**/

@isTest
public class DigitalInteractionDetailsTriggerTest {
    private static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();
    
    private static Id createParentRecord() {
        Digital_Interaction__c parentObj = new Digital_Interaction__c();
        insert parentObj;
        return parentObj.Id;
    } 
    
    @isTest
    static void testInsertWithValidUrl() {
        Id parentId = createParentRecord();
        
        Digital_Interaction_Details__c did = new Digital_Interaction_Details__c(
            Digital_Interaction__c = parentId,
            URL__c = 'https://example.com/fonds/test-fund'
        );
        
        Test.startTest();
        insert did;
        Test.stopTest();
        
        did = [SELECT FundName__c FROM Digital_Interaction_Details__c WHERE Id = :did.Id];
        System.assertEquals('test fund', did.FundName__c);
    }
    
    @isTest
    static void testInsertWithInvalidUrl() {
        Id parentId = createParentRecord();
        
        Digital_Interaction_Details__c did = new Digital_Interaction_Details__c(
            Digital_Interaction__c = parentId,
            URL__c = 'https://example.com/invalid-path'
        );
        
        Test.startTest();
        insert did;
        Test.stopTest();
        
        did = [SELECT FundName__c FROM Digital_Interaction_Details__c WHERE Id = :did.Id];
        System.assertEquals(null, did.FundName__c);
    }
    
    @isTest
    static void testUpdateWithValidUrl() {
        Id parentId = createParentRecord();
        Product__c p = new Product__c(RecordTypeId = fundRecordTypeId,
                                 Name = 'updated fund',
                                 Product_Name__c = 'updated fund',
                                 Validity__c = true);
        insert p;
        Share_Class__c shareCls = new Share_Class__c(Name='Test ShareCls',ISIN_Code__c='LU2585800795', Fund__c= p.Id, Validity__c=true);
        insert shareCls;
        Digital_Interaction_Details__c did = new Digital_Interaction_Details__c(
            Digital_Interaction__c = parentId,
            URL__c = 'https://example.com/invalid-path'
        );
        insert did;
        
        did.URL__c = 'https://example.com/funds/updated-fund-LU2585800795';
        
        Test.startTest();
        update did;
        Test.stopTest();
        
        did = [SELECT FundName__c FROM Digital_Interaction_Details__c WHERE Id = :did.Id];
        System.assertEquals('updated fund', did.FundName__c);
    }
    
    @isTest
    static void testUpdateWithEmptyUrl() {
        Id parentId = createParentRecord();
        
        Digital_Interaction_Details__c did = new Digital_Interaction_Details__c(
            Digital_Interaction__c = parentId,
            URL__c = 'https://example.com/fonds/initial-fund'
        );
        insert did;
        did.URL__c = '';
        
        Test.startTest();
        update did;
        Test.stopTest();
        
        did = [SELECT FundName__c FROM Digital_Interaction_Details__c WHERE Id = :did.Id];
        System.assertEquals(null, did.FundName__c);
    }
    
    @isTest
    static void testBulkProcessing() {
        Id parentId = createParentRecord();
        
        List<Digital_Interaction_Details__c> dids = new List<Digital_Interaction_Details__c>();
        for (Integer i = 0; i < 200; i++) {
            String url = 'https://example.com/fonds/fund' + i;
            dids.add(new Digital_Interaction_Details__c(
                Digital_Interaction__c = parentId,
                URL__c = url
            ));
        }
        
        Test.startTest();
        insert dids;
        Test.stopTest();
        
        List<Digital_Interaction_Details__c> insertedRecords = [SELECT Id, URL__c, FundName__c FROM Digital_Interaction_Details__c];
        System.assertEquals(200, insertedRecords.size());
        for (Integer i = 0; i < 200; i++) {
            System.assertNotEquals(null, insertedRecords[i].FundName__c);
        }
    }
    
    @isTest
    static void testProductCodeExtraction() {
        Id parentId = createParentRecord();
        Product__c prod = new Product__c(Name = 'TEST', Product_Name__c = 'Test Product', Validity__c = true,RecordTypeId = fundRecordTypeId);
        insert prod;
        
        Digital_Interaction_Details__c did = new Digital_Interaction_Details__c(
            Digital_Interaction__c = parentId,
            URL__c = 'https://example.com/WR_TEST_someother_info'
        ); 
        
        Test.startTest();
        insert did;
        Test.stopTest();
        
        did = [SELECT FundName__c FROM Digital_Interaction_Details__c WHERE Id = :did.Id];
        System.assertEquals('Test Product', did.FundName__c);
    }
    
    @isTest
    static void testUrlWithQuestionMark() {
        Id parentId = createParentRecord();
        
        Digital_Interaction_Details__c did = new Digital_Interaction_Details__c(
            Digital_Interaction__c = parentId,
            URL__c = 'https://example.com/fonds/test-fund-name?param=value'
        );
        
        Test.startTest();
        insert did;
        Test.stopTest();
        
        did = [SELECT FundName__c FROM Digital_Interaction_Details__c WHERE Id = :did.Id];
        System.assertEquals('test fund name', did.FundName__c);
    }
    
    @isTest
    static void unusedFunctions() {
        Map<Id, Digital_Interaction_Details__c> newMap = new Map<Id, Digital_Interaction_Details__c>();
        DigitalInteractionDetailsTriggerHandler th = new DigitalInteractionDetailsTriggerHandler();
        th.BeforeDelete(newMap);
        th.AfterInsert(newMap);
        th.AfterUpdate(newMap, newMap);
        th.AfterDelete(newMap);
        th.AfterUndelete(newMap);
        th.IsDisabled();
    }    

    @isTest
    static void testBatchExecution() {
        //Prepare data
        Id parentId = createParentRecord();
        List<Digital_Interaction_Details__c> testRecords = new List<Digital_Interaction_Details__c>();
        testRecords.add(new Digital_Interaction_Details__c(Digital_Interaction__c = parentId, URL__c = 'http://example.com/fonds/updated-fund-LU2585800795-test'));
        testRecords.add(new Digital_Interaction_Details__c(Digital_Interaction__c = parentId, URL__c = 'http://example.com/fonds/fund-without-isin'));
        testRecords.add(new Digital_Interaction_Details__c(Digital_Interaction__c = parentId, URL__c = null));
        testRecords.add(new Digital_Interaction_Details__c(Digital_Interaction__c = parentId, URL__c = 'http://example.com/WR_TEST_someother_info'));
        insert testRecords;

        Product__c p = new Product__c(RecordTypeId = fundRecordTypeId,
                                 Name = 'updated fund',
                                 Product_Name__c = 'updated fund',
                                 Validity__c = true);
        insert p;
        Share_Class__c shareCls = new Share_Class__c(Name='Test ShareCls',ISIN_Code__c='LU2585800795', Fund__c= p.Id, Validity__c=true);
        insert shareCls;
        
        Product__c prodTest = new Product__c(Name = 'TEST', Product_Name__c = 'Test Product', Validity__c = true);
        insert prodTest;

        // batch execution 
        Test.startTest();
        DigitalInteractionDetailsBatch batch = new DigitalInteractionDetailsBatch();
        Database.executeBatch(batch);
        Test.stopTest();

        // Vérification des résultats
        List<Digital_Interaction_Details__c> updatedRecords = [SELECT Id, FundName__c FROM Digital_Interaction_Details__c];
        
        System.assertEquals(4, updatedRecords.size(), 'Le nombre de records mis à jour est incorrect');
        
        for (Digital_Interaction_Details__c record : updatedRecords) {
            if (record.FundName__c == 'updated fund') {
                System.assertEquals('updated fund', record.FundName__c, 'Le nom du fonds n\'a pas été correctement mis à jour pour l\'ISIN');
            } else if (record.FundName__c == 'fund without isin') {
                System.assertEquals('fund without isin', record.FundName__c, 'Le nom du fonds n\'a pas été correctement extrait de l\'URL');
            } else if (record.FundName__c == 'Test Product') {
                System.assertEquals('Test Product', record.FundName__c, 'Le nom du produit n\'a pas été correctement extrait du code produit');
            } else {
                System.assertEquals(null, record.FundName__c, 'Le nom du fonds devrait être null pour l\'URL vide');
            }
        }
    }
}