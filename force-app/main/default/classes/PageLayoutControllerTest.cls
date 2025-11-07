@isTest
public class PageLayoutControllerTest {
    
    @testSetup
    static void setupTestData() {
        
        
        // Create a ProductProjectSettings__c record
        ProductProjectSettings__c  prodSettings1 = new ProductProjectSettings__c (
            Team__c = 'Legal',
            Stage__c = 'Design',
            ProjectType__c = 'Creation'
        );
        insert prodSettings1;
         ProductProjectSettings__c  prodSettings2 = new ProductProjectSettings__c (
            Team__c = 'Legal',
            Stage__c = 'Proposal',
            ProjectType__c = 'Creation'
        );
        insert prodSettings2;
    }
    
     @isTest
    static void test_getAllFieldsByRecordId() {
        
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundShareClassModification');
        
        Id fundRecordTypeId = Schema.SObjectType.Product__c
            .getRecordTypeInfosByName().get('Fund').getRecordTypeId();
        
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        Share_Class__c share = new Share_Class__c(Name = 'Test Share', Fund__c = product.Id);
        insert share;
        
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        proj.Product__c = product.Id;
        update proj;
        
 
        
        ProjectProductChild__c child = [SELECT Id FROM ProjectProductChild__c WHERE ProjectProductParent__c = :proj.Id LIMIT 1];
        ShareclassNavigatorController.createAndLinkShareclass(
            child.Id, 'A', 'EUR', 'Accumulating', 'Annually', 'False'
        );
        
        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        child.TECH_TeamValidation__c ='ProductStrategy';
        update child;
        ProjectShareclassChild__c scChild = [SELECT Id FROM ProjectShareclassChild__c LIMIT 1];
        Test.startTest();
        PageLayoutController.getAllFieldsByRecordId(child.Id);
        PageLayoutController.getAllFieldsByRecordId(scChild.Id);
        Test.stopTest();
    }
    
    
    
    @isTest
    static void testGetUserPermissionSet() {
        
        Test.startTest();
        
        Boolean hasPermissionSet = PageLayoutController.getUserPermissionSet('PRPProductStrategy');
        
        Test.stopTest(); 
    }
    
    @isTest
    static void testGetFieldsForProjectProductChild() {
        ProductProjectSettings__c  prodSettings1 = new ProductProjectSettings__c (
            Team__c = 'Legal',
            Stage__c = 'Design',
            ProjectType__c = 'Creation',
            RequiredFields__c = 'AssetClass__c;ISIN__c',
            RequiredFieldsShareClass__c = 'IsValid__c;LegalType__c'
        );
        insert prodSettings1;
        Test.startTest();
        List<String> fields = PageLayoutController.getFields('ProjectProductChild__c', null);
        
        System.assertNotEquals(null, fields, 'Fields list should not be null');
        System.assert(fields.contains('AssetClass__c'), 'Field1 should be in the list');
        System.assert(fields.contains('ISIN__c'), 'Field2 should be in the list');
        Test.stopTest();
    }
    
    @isTest
    static void testGetFieldsForProjectShareclassChild() {
        ProductProjectSettings__c  prodSettings1 = new ProductProjectSettings__c (
            Team__c = 'Legal',
            Stage__c = 'Design',
            ProjectType__c = 'Creation',
            RequiredFields__c = 'AssetClass__c;ISIN__c',
            RequiredFieldsShareClass__c = 'IsValid__c;LegalType__c'
        );
        insert prodSettings1;
        
        Test.startTest();
        List<String> fields = PageLayoutController.getFields('ProjectShareclassChild__c', null);
        
        System.assertNotEquals(null, fields, 'Fields list should not be null');
        System.assert(fields.contains('IsValid__c'), 'FieldA should be in the list');
        System.assert(fields.contains('LegalType__c'), 'FieldB should be in the list');
        Test.stopTest();
    }
    
    @isTest
    static void testGetFieldsNoData() {
        ProductProjectSettings__c  prodSettings1 = new ProductProjectSettings__c (
            Team__c = 'Legal',
            Stage__c = 'Design',
            ProjectType__c = 'Creation',
            RequiredFields__c = 'AssetClass__c;ISIN__c',
            RequiredFieldsShareClass__c = 'IsValid__c;LegalType__c'
        );
        insert prodSettings1;
        
        Test.startTest();
        delete [SELECT Id FROM ProductProjectSettings__c];
        
        try {
            PageLayoutController.getFields('ProjectProductChild__c', null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            // System.assert(e.getMessage().contains('Aucun champ trouvé pour la Permission Set'), 'Exception message should match expected text');
        }
        Test.stopTest();
    }
    
    @isTest
    static void test_getEditableFieldsWithViewALL() {
        
        List<User> testUsers = new List<User>();
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User u = new User(
            FirstName = 'Test',
            LastName = 'User' ,
            Email = 'testuser@test.com',
            Username = 'testuser@test.com.' + System.currentTimeMillis(),
            Alias = 'test' ,
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'fr_FR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'fr',
            ProfileId = p.Id
        );
        
        insert u;
        
        PermissionSet psMin = [SELECT Id FROM PermissionSet WHERE Name = 'PRPMinimumAccess'];
        PermissionSet psPS = [SELECT Id FROM PermissionSet WHERE Name = 'PRPProductStrategy'];
        
        // 3. Associer le Permission Set à l’utilisateur
        PermissionSetAssignment psaMin = new PermissionSetAssignment(
            AssigneeId = u.Id,
            PermissionSetId = psMin.Id
        );
        insert psaMin;
        PermissionSetAssignment psaPS = new PermissionSetAssignment(
            AssigneeId = u.Id,
            PermissionSetId = psPS.Id
        );
        insert psaPS; 
        System.runAs(u) {
            Test.startTest();
            Map<String, Boolean> fieldPermissions = PageLayoutController.getEditableFields('ProjectShareclass__c', 'PRPProductStrategy', true);
            
            System.assertNotEquals(0, fieldPermissions.size());
            Test.stopTest();
        }
    }
    
    @isTest
    static void test_getEditableFieldsWithoutViewALL() {
        
        List<User> testUsers = new List<User>();
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User u = new User(
            FirstName = 'Test',
            LastName = 'User' ,
            Email = 'testuser@test.com',
            Username = 'testuser@test.com.' + System.currentTimeMillis(),
            Alias = 'test' ,
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'fr_FR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'fr',
            ProfileId = p.Id
        );
        
        insert u;
        
        PermissionSet psMin = [SELECT Id FROM PermissionSet WHERE Name = 'PRPMinimumAccess'];
        PermissionSet psPS = [SELECT Id FROM PermissionSet WHERE Name = 'PRPProductStrategy'];
        
        // 3. Associer le Permission Set à l’utilisateur
        PermissionSetAssignment psaMin = new PermissionSetAssignment(
            AssigneeId = u.Id,
            PermissionSetId = psMin.Id
        );
        insert psaMin;
        PermissionSetAssignment psaPS = new PermissionSetAssignment(
            AssigneeId = u.Id,
            PermissionSetId = psPS.Id
        );
        insert psaPS; 
        System.runAs(u) {
            Test.startTest();
            Map<String, Boolean> fieldPermissions = PageLayoutController.getEditableFields('ProjectShareclass__c', 'PRPProductStrategy', false);
            
            System.assertNotEquals(0, fieldPermissions.size());
            Test.stopTest();
        }
    }
    
    @isTest
    static void test_checkEditableConidtions() {
        
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundShareClassModification');
        
        Id fundRecordTypeId = Schema.SObjectType.Product__c
            .getRecordTypeInfosByName().get('Fund').getRecordTypeId();
        
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        Share_Class__c share = new Share_Class__c(Name = 'Test Share', Fund__c = product.Id);
        insert share;
        
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        proj.Product__c = product.Id;
        update proj;
        
 
        
        ProjectProductChild__c child = [SELECT Id FROM ProjectProductChild__c WHERE ProjectProductParent__c = :proj.Id LIMIT 1];
        ShareclassNavigatorController.createAndLinkShareclass(
            child.Id, 'A', 'EUR', 'Accumulating', 'Annually', 'False'
        );
        
        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        child.TECH_TeamValidation__c ='ProductStrategy';
        update child;
        ProjectShareclassChild__c scChild = [SELECT Id FROM ProjectShareclassChild__c LIMIT 1];
        Test.startTest();
        PageLayoutController.checkEditableConidtions(child.Id, 'ProjectProductChild__c');
        PageLayoutController.checkEditableConidtions(scChild.Id, 'ProjectShareclassChild__c');
        Test.stopTest();
    }
    
    @isTest
    static void test_getRecordTypeId(){
        Id fundRecordTypeId = Schema.SObjectType.Product__c
            .getRecordTypeInfosByName().get('Fund').getRecordTypeId();
        
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        PageLayoutController.getRecordTypeId('Product__c', product.Id);
    }
    
     @isTest
    static void test_checkModificationConidtions() {
        
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundShareClassModification');
        
        Id fundRecordTypeId = Schema.SObjectType.Product__c
            .getRecordTypeInfosByName().get('Fund').getRecordTypeId();
        
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        Share_Class__c share = new Share_Class__c(Name = 'Test Share', Fund__c = product.Id);
        insert share;
        
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        proj.Product__c = product.Id;
        update proj;
        
 
        
        ProjectProductChild__c child = [SELECT Id FROM ProjectProductChild__c WHERE ProjectProductParent__c = :proj.Id LIMIT 1];
        ShareclassNavigatorController.createAndLinkShareclass(
            child.Id, 'A', 'EUR', 'Accumulating', 'Annually', 'False'
        );
        
        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        child.TECH_TeamValidation__c ='ProductStrategy';
        update child;
        ProjectShareclassChild__c scChild = [SELECT Id FROM ProjectShareclassChild__c LIMIT 1];
        Test.startTest();
        PageLayoutController.checkModificationConidtions(child.Id, 'ProjectProductChild__c');
        PageLayoutController.checkModificationConidtions(scChild.Id, 'ProjectShareclassChild__c');
        Test.stopTest();
    }
    
    @isTest
    static void test_getEditableFieldsFromSourceField() {
        
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundShareClassModification');
        
        Id fundRecordTypeId = Schema.SObjectType.Product__c
            .getRecordTypeInfosByName().get('Fund').getRecordTypeId();
        
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        Share_Class__c share = new Share_Class__c(Name = 'Test Share', Fund__c = product.Id);
        insert share;
        
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        proj.Product__c = product.Id;
        update proj;
        
 
        
        ProjectProductChild__c child = [SELECT Id FROM ProjectProductChild__c WHERE ProjectProductParent__c = :proj.Id LIMIT 1];
        ShareclassNavigatorController.createAndLinkShareclass(
            child.Id, 'A', 'EUR', 'Accumulating', 'Annually', 'False'
        );
        
        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        child.TECH_TeamValidation__c ='ProductStrategy';
        update child;
        ProjectShareclassChild__c scChild = [SELECT Id FROM ProjectShareclassChild__c LIMIT 1];
        Test.startTest();
        PageLayoutController.getEditableFieldsFromSourceField('ISIN__c,ProjectProductParent__r.Name', 'ProjectProductChild__c', child.Id);
        //PageLayoutController.getEditableFieldsFromSourceField(scChild.Id, 'ProjectShareclassChild__c');
        Test.stopTest();
    }
     
    
}