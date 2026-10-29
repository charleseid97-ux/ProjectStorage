/** ──────────────────────────────────────
 * @description Tests of RoadToMarketFormController: Road To Market record of a project, and its steps with their milestones.
 * @covers RoadToMarketFormController   100%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_RoadToMarketFormController {

    @isTest
    static void test_roadToMarketForm() {
        ProjectProduct__c parentProject = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));
        PMTTestFactoryData.createProjectProductChild(parentProject.Id, 'Proposal', null);
        PMTTestFactoryData.createMilestone(parentProject.Id, 'Initial Review', Date.today());
        insert new RoadToMarket__c(Parent_Project__c = parentProject.Id);

        Test.startTest();

        RoadToMarket__c result = RoadToMarketFormController.getRoadToMarketrecordById(parentProject.Id);
        List<Map<String, Object>> steps = RoadToMarketFormController.getStepsWithMilestones(parentProject.Id);

        Test.stopTest();

        System.assertEquals(parentProject.Id, result.Parent_Project__c, 'Le Parent_Project doit correspondre');
        System.assert(!steps.isEmpty(), 'La liste des étapes ne doit pas être vide');
        System.assert(steps[0].containsKey('milestones'), 'L\'étape doit contenir des milestones');
        System.assert(!((List<Object>) steps[0].get('milestones')).isEmpty(), 'Il doit y avoir au moins un milestone');
    }
}