@isTest
public class Test_RoadToMarketFormController {
 
    @testSetup
    static void setupData() {
        // Créer un ProjectProduct parent
        Id recordTypeId = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c parentProject = PMTTestFactoryData.createProjectProductWithAllFields(recordTypeId);
 
        // Créer une étape (ProjectProductChild)
ProjectProductChild__c childStep = PMTTestFactoryData.createProjectProductChild(parentProject.Id, 'Proposal', null);
 
        // Créer un milestone lié à cette étape
PMTTestFactoryData.createMilestone(parentProject.Id, 'Initial Review', Date.today());
 
        // Créer un enregistrement RoadToMarket
        RoadToMarket__c rtm = new RoadToMarket__c(
Parent_Project__c = parentProject.Id

        );
        insert rtm;
    }
 
    @isTest
    static void test_getRoadToMarketrecordById() {
        ProjectProduct__c parent = [SELECT Id FROM ProjectProduct__c LIMIT 1];
 
        Test.startTest();
RoadToMarket__c result = RoadToMarketFormController.getRoadToMarketrecordById(parent.Id);
        Test.stopTest();
 
        System.assertNotEquals(null, result, 'Le résultat ne doit pas être null');
System.assertEquals(parent.Id, result.Parent_Project__c, 'Le Parent_Project doit correspondre');
    }
 
    @isTest
    static void test_getStepsWithMilestones() {
        ProjectProduct__c parent = [SELECT Id FROM ProjectProduct__c LIMIT 1];
 
        Test.startTest();
List<Map<String, Object>> steps = RoadToMarketFormController.getStepsWithMilestones(parent.Id);
        Test.stopTest();
 
        System.assert(!steps.isEmpty(), 'La liste des étapes ne doit pas être vide');
        Map<String, Object> step = steps[0];
        System.assert(step.containsKey('milestones'), 'L\'étape doit contenir des milestones');
        List<Object> milestones = (List<Object>) step.get('milestones');
        System.assert(!milestones.isEmpty(), 'Il doit y avoir au moins un milestone');
    }
}