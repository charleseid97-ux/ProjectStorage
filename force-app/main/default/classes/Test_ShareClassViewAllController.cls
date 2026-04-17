@isTest
public class Test_ShareClassViewAllController {
 
    @testSetup
    static void setupTestData() {
        // Créer un projet parent
        Id recordTypeId = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c parentProject = PMTTestFactoryData.createProjectProductWithAllFields(recordTypeId);
 
        // Créer un enfant de type "Proposal"
ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parentProject.Id, 'Proposal', null);
 
        // Créer une shareclass liée au parent
ProjectShareclass__c shareclass = PMTTestFactoryData.createProjectShareclass(parentProject.Id, 'EUR');
 
        // Créer un junction entre la shareclass et l'enfant
ProjectChildJunction__c junction = PMTTestFactoryData.createJunction(child.Id, shareclass.Id);
    }
 
    @isTest
    static void test_getProjectShareclasses() {
        // Récupération du parent créé dans le test setup
        ProjectProduct__c parent = [SELECT Id FROM ProjectProduct__c LIMIT 1];
 
        Test.startTest();
        List<ShareClassViewAllController.ShareClassWrapper> result =
        ShareClassViewAllController.getProjectShareclasses(parent.Id);
        Test.stopTest();
 
        System.assertNotEquals(null, result, 'Résultat ne doit pas être null');
        System.assert(result.size() > 0, 'Il doit y avoir au moins une shareclass retournée');
        System.assertNotEquals(null, result[0].fields, 'La liste des champs ne doit pas être vide');
        System.assert(result[0].fields.size() > 0, 'Il doit y avoir des métadonnées de champs');
    }
}