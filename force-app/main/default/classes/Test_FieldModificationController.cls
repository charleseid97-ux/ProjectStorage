@IsTest
public class Test_FieldModificationController {

    private static final Id fundModificationRtId = Schema.SObjectType.ProjectProduct__c
        .getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();
    static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();  

    @IsTest(SeeAllData=true)
    static void test_getFieldsToModify() {
        System.debug('[DEBUG TEST FieldModificationController]');
		Strategy__c s0 = new Strategy__c(Name='S0', AssetClass__c='Equity', SubAssetClass__c='Global', Code__c = 'S01');
        insert s0;
        
        Product__c p0 = new Product__c(Name='P0', FundStrategy__c=s0.Id, Product_Name__c='Product Zero', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=true, LegalForm__c='SICAV',VehicleType__c='Funds');
        insert p0;
        
        Share_Class__c sc0 = new Share_Class__c(Name='ShareClass0 A USD', CurrencyIsoCode='USD', Country__c='AT;BE;FR;DE;GB;XI;IT;LU;ES;SE;CH;NL', Type__c='A', Fund_Code__c='P0', Fund__c=p0.Id, Validity__c=true);
        insert sc0;
        
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundModificationRtId);
        proj.Product__c = p0.Id;
        proj.TECH_FieldsToModify__c = 'ForeseenEUCategory__c;NAVFrequency__c;PricingMethod__c;RecommendedHoldingPeriod__c';
        update proj;
        List<ProjectProductChild__c> childs = [SELECT Id,ProjectProductParent__c FROM ProjectProductChild__c where ProjectProductParent__c=:proj.Id];
        system.debug(proj.ProjectStartDate__c);
        
        ProjectShareclass__c shareClass = PMTTestFactoryData.createProjectShareclass(proj.Id, 'DividendFrequency__c;Type__c;DividendPolicy__c;InvestmentStatusInvestors__c');
        shareClass.Tech_ShareClass__c = sc0.Id;
        update shareClass;
        List<ProjectChildJunction__c> junctionsToInsert = new List<ProjectChildJunction__c>();
            for (ProjectProductChild__c sibling : childs) {
                        junctionsToInsert.add(new ProjectChildJunction__c(
                            ProjectProductChild__c = sibling.Id,
                            ProjectShareclass__c = shareClass.Id
                        ));
                
            }
        insert junctionsToInsert;
        List<ProjectShareclassChild__c> scchilds = [Select Id From ProjectShareclassChild__c where ProjectShareclasses__c = :shareClass.Id];
        
        List<ProjectChildJunction__c> junctions = [SELECT Id FROM ProjectChildJunction__c WHERE ProjectShareclass__c =:shareClass.Id ];
        Test.startTest();
		List<Map<String, String>> productsList = FieldModificationController.getFieldsToModify(proj.Id, 'Product__c');
        List<Map<String, String>> scList = FieldModificationController.getFieldsToModify(proj.Id, 'Share_Class__c');
        system.assertNotEquals(0, productsList.size());
        system.assertNotEquals(0, scList.size());
        Test.stopTest();
        
    }
    
    @IsTest
    static void test_updateFieldValue(){
        Product__c p = new Product__c(Name='P0', Product_Name__c='Product Zero', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=true, LegalForm__c='SICAV',VehicleType__c='Funds');
        insert p;
        Test.startTest();
        FieldModificationController.updateFieldValue('Product__c', p.Id, 'Product_Name__c', 'New Name');
        Test.stopTest();
        Product__c modifiedProduct = [SELECT Id,Product_Name__c FROM Product__c WHERE Id =: p.Id];
        system.assertEquals('New Name' , modifiedProduct.Product_Name__c);
    }
    
    @IsTest
    static void test_updateFieldVal(){
        Product__c p = new Product__c(Name='P0', Product_Name__c='Product Zero', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=true, LegalForm__c='SICAV',VehicleType__c='Funds');
        insert p;
        Test.startTest();
        FieldModificationController.updateFieldVal('Product__c', p.Id, 'Product_Name__c', 'New Name');
        Test.stopTest();
        Product__c modifiedProduct = [SELECT Id,Product_Name__c FROM Product__c WHERE Id =: p.Id];
        system.assertEquals('New Name' , modifiedProduct.Product_Name__c);
    }
    
    @IsTest
    static void test_updateMultipleFields(){
        Product__c p = new Product__c(Name='P0', Product_Name__c='Product Zero', Record_Type_Name__c = 'Fund', RecordTypeId=fundRecordTypeId, Validity__c=true, LegalForm__c='SICAV',VehicleType__c='Funds');
        insert p;
        List<FieldModificationController.FieldUpdate> fields = new List<FieldModificationController.FieldUpdate>();
		FieldModificationController.FieldUpdate fieldUpdate = new FieldModificationController.FieldUpdate();
        fieldUpdate.recordId = p.Id;
        fieldUpdate.objectApiName = 'Product__c';
        fieldUpdate.fieldApiName = 'Product_Name__c';
        fieldUpdate.newValue = 'New Name';
        fields.add(fieldUpdate);
        Test.startTest();
        FieldModificationController.updateMultipleFields(fields);
        Test.stopTest();
        Product__c modifiedProduct = [SELECT Id,Product_Name__c FROM Product__c WHERE Id =: p.Id];
        system.assertEquals('New Name' , modifiedProduct.Product_Name__c);
    }
}