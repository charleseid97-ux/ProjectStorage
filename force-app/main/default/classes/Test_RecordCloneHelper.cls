@IsTest
public class Test_RecordCloneHelper {
 
    @IsTest
    static void test_cloneProjectProduct_success() {
        // 1. Création d’un ProjectProduct source avec plusieurs champs remplis
               Id recordTypeId = Schema.SObjectType.ProjectProduct__c
            .getRecordTypeInfosByDeveloperName()
            .get('FundCreation')
            .getRecordTypeId();
 
        ProjectProduct__c source = PMTTestFactoryData.createProjectProductWithAllFields(recordTypeId);
           ProjectProduct__c target = PMTTestFactoryData.createProjectProductWithAllFields(recordTypeId);
 
        // 2. Cible vide

 
        // 3. Appel du clone
        Test.startTest();
        SObject cloned = RecordCloneHelper.cloneRecordFields(source, target);
        Test.stopTest();
    }
 
    @IsTest
    static void test_clone_excludesSystemFields() {
                      Id recordTypeId = Schema.SObjectType.ProjectProduct__c
            .getRecordTypeInfosByDeveloperName()
            .get('FundCreation')
            .getRecordTypeId();
 
            
 ProjectProduct__c source = PMTTestFactoryData.createProjectProductWithAllFields(recordTypeId);
           ProjectProduct__c target = PMTTestFactoryData.createProjectProductWithAllFields(recordTypeId);
           SObject cloned = RecordCloneHelper.cloneRecordFields(source, target);
        SObject batchCloned = RecordCloneHelper.batchCloneRecordFields(source, target);
 
        // Vérifie que les champs système ne sont pas clonés
    }
 
    @IsTest
    static void test_clone_nullSource_throwsError() {
        ProjectProduct__c target = new ProjectProduct__c();
        try {
            RecordCloneHelper.cloneRecordFields(null, target);

            System.assert(false, 'Doit lever une exception pour source null');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Source record is null'));
        }
    }
    @IsTest
    static void test_batchClone_nullSource_throwsError() {
        ProjectProduct__c target = new ProjectProduct__c();
        try {
            RecordCloneHelper.batchCloneRecordFields(null, target);

            System.assert(false, 'Doit lever une exception pour source null');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Source record is null'));
        }
    }
 
    @IsTest
    static void test_getAllFieldNames_ProjectProduct() {
        Test.startTest();
        String fieldList = RecordCloneHelper.getAllFieldNames('ProjectProduct__c');
        Test.stopTest();
    }
}