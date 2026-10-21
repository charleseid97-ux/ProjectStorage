/** ──────────────────────────────────────
 * @description Tests of statusNavigatorController: project, steps, parent record, current step and matching Proposal stage, read from a
 *                  stage and from a Shareclass Child of a Fund creation project.
 * @covers statusNavigatorController   88%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_StatusNavigatorController {

    @isTest
    static void test_navigation() {
        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(parent.Id, 'CurrencyIsoCode');
        ProjectShareclassChild__c shChild = PMTTestFactoryData.createShareclassChild(shc.Id, 'Proposal');
        PMTTestFactoryData.createJunction(child.Id, shc.Id);

        Test.startTest();

        Id matchingStageId = statusNavigatorController.getMatchingProjectProductChild(shChild.Id);
        Id proposalStepId = statusNavigatorController.getProposalStep(shChild.Id);
        ProjectProduct__c project = statusNavigatorController.getProjectProduct(child.Id);
        List<Map<String, Object>> stageSteps = statusNavigatorController.getSteps(child.Id, 'ProjectProductChild__c');
        List<Map<String, Object>> shareclassChildSteps = statusNavigatorController.getSteps(shChild.Id, 'ProjectShareclassChild__c');
        Id stageParentId = statusNavigatorController.getParentRecord(child.Id, 'ProjectProductChild__c');
        Id shareclassChildParentId = statusNavigatorController.getParentRecord(shChild.Id, 'ProjectShareclassChild__c');
        String stageCurrentStep = statusNavigatorController.getCurrentStep(child.Id, 'ProjectProductChild__c');
        String shareclassChildCurrentStep = statusNavigatorController.getCurrentStep(shChild.Id, 'ProjectShareclassChild__c');

        Test.stopTest();

        System.assertEquals(child.Id, matchingStageId, 'Stage matching the Shareclass Child');
        System.assertEquals(child.Id, proposalStepId, 'Proposal stage of the Shareclass Child');
        System.assertEquals(parent.Id, project.Id, 'Project of the stage');
        System.assert(!stageSteps.isEmpty(), 'Steps from a stage');
        System.assert(!shareclassChildSteps.isEmpty(), 'Steps from a Shareclass Child');
        System.assertEquals(parent.Id, stageParentId, 'Parent of a stage');
        System.assertEquals(child.Id, shareclassChildParentId, 'Parent of a Shareclass Child');
        System.assertEquals('DesignAndProposal', stageCurrentStep, 'Current step of a stage');
        System.assertEquals('DesignAndProposal', shareclassChildCurrentStep, 'Current step of a Shareclass Child');
    }
}