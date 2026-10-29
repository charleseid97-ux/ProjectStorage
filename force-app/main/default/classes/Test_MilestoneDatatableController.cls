/** ──────────────────────────────────────
 * @description Tests of the milestone datatable controller: milestones of a project, Status values, and the milestones saved.
 * @covers MilestoneDatatableController   63%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
private class Test_MilestoneDatatableController {

    @isTest
    static void test_milestones() {
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));
        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'Test Milestone', Date.today());

        Test.startTest();

        List<Milestone__c> milestones = MilestoneDatatableController.getMilestones(proj.Id);
        List<String> statuses = MilestoneDatatableController.getStatusPicklistValues();
        milestone.Status__c = statuses.isEmpty() ? null : statuses[0];
        List<Milestone__c> updated = MilestoneDatatableController.updateMilestones(new List<Milestone__c>{ milestone });

        Test.stopTest();

        Set<Id> milestoneIds = new Map<Id, Milestone__c>(milestones).keySet();
        System.assert(milestoneIds.contains(milestone.Id), 'Milestones of the project');
        System.assert(!statuses.isEmpty(), 'Status values');
        System.assertEquals(milestone.Status__c, updated[0].Status__c, 'Saved milestone');
    }
}