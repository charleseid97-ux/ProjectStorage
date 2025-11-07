@isTest
public class Test_FieldSelectorController {
    
    @isTest static void test_getDependentFields() {
        
        Test.startTest();
        List<Map<String, String>> dependentFields = FieldSelectorController.getDependentFields('Product__c');
        Test.stopTest();
        system.assertNotEquals(0, dependentFields.size());
    }
    
    
    @isTest static void test_getSelectedFields_ProductProduct() {
        
        // Création de la matrice nécessaire
        PMTTestFactoryData.createMatrice(
            'Proposal', 'Risk',
            'RiskAssociated__c;ProjectStatus__c',
            'CurrencyIsoCode;Type__c'
        );
        
        // Création d'un ProjectProduct complet
        Id prodRT = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        PMTTestFactoryData.createProjectProductWithAllFields(prodRT);
        
        // Création d’un ProjectShareclass lié
        ProjectProduct__c proj = [SELECT Id FROM ProjectProduct__c LIMIT 1];
        PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode;Type__c');
        
        
        Test.startTest();
        List<Map<String, String>> fields = FieldSelectorController.getSelectedFields(proj.Id, 'ProjectProduct__c');
        Test.stopTest();
        
    }
    
    @isTest(SeeAllData=true) static void test_getSelectedFields_ProductProduct2() {
        
        Test.startTest();
        FieldSelectorController.getMetadataFields('Parent_Share_Class__c');
        Test.stopTest();
        
    }
    
    @isTest static void test_updateSelectedFields_ProductProduct() {
        
        // Création de la matrice nécessaire
        PMTTestFactoryData.createMatrice(
            'Proposal', 'Risk',
            'RiskAssociated__c;ProjectStatus__c',
            'CurrencyIsoCode;Type__c'
        );
        
        // Création d'un ProjectProduct complet
        Id prodRT = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj  = PMTTestFactoryData.createProjectProductWithAllFields(prodRT);
        
        // Création d’un ProjectShareclass lié
        
        PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode;Type__c');
        
        
        Test.startTest();
        FieldSelectorController.updateSelectedFields(proj.Id, new List<String>{'Name'}, 'ProjectProduct__c');
        Test.stopTest();
        proj = [SELECT TECH_FieldsToModify__c FROM ProjectProduct__c WHERE Id = :proj.Id];
        
    }
    
    @isTest static void test_getAndUpdate_ParentShareclass() {
        
        // Création de la matrice nécessaire
        PMTTestFactoryData.createMatrice(
            'Proposal', 'Risk',
            'RiskAssociated__c;ProjectStatus__c',
            'CurrencyIsoCode;Type__c'
        );
        
        // Création d'un ProjectProduct complet
        Id prodRT = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj  = PMTTestFactoryData.createProjectProductWithAllFields(prodRT);
        
        // Création d’un ProjectShareclass lié
        
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode;Type__c');
        
        
        Test.startTest();
        List<Map<String, String>> fields = FieldSelectorController.getSelectedFields(shc.Id, 'Parent_Share_Class__c');
        FieldSelectorController.updateSelectedFields(shc.Id, new List<String>{'CurrencyIsoCode'}, 'Parent_Share_Class__c');
        shc = [SELECT TECH_FieldsToModify__c FROM ProjectShareclass__c WHERE Id = :shc.Id];
        Test.stopTest();
        
        
        
    }
    
    @isTest static void test_getAndUpdate_ShareclassChild() {
        
        // Création de la matrice nécessaire
        PMTTestFactoryData.createMatrice(
            'Proposal', 'Risk',
            'RiskAssociated__c;ProjectStatus__c',
            'CurrencyIsoCode;Type__c'
        );
        
        // Création d'un ProjectProduct complet
        Id prodRT = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        PMTTestFactoryData.createProjectProductWithAllFields(prodRT);
        
        // Création d’un ProjectShareclass lié
        ProjectProduct__c proj = [SELECT Id FROM ProjectProduct__c LIMIT 1];
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode;Type__c');
        
        
        ProjectShareclassChild__c shcChild = [SELECT Id, ProjectShareclasses__c FROM ProjectShareclassChild__c LIMIT 1];
        Test.startTest();
        List<Map<String, String>> fields = FieldSelectorController.getSelectedFields(shcChild.Id, 'Share_Class__c');
        FieldSelectorController.updateSelectedFields(shcChild.Id, new List<String>{'DividendPolicy__c'}, 'Share_Class__c');
        Test.stopTest();
        
        
        
    }
}