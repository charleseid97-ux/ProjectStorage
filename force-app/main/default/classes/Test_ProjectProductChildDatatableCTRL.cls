/** ──────────────────────────────────────
 * @description Tests of the projectProductChildDatatable LWC controller: reading the phases of a project and the Status values, saving and deleting a phase.
 *                  FIX-20270: the component might not be used (see ProjectProductChildDatatableController); this test goes with it if it is deleted.
 * @covers ProjectProductChildDatatableController   100%   [19-10-26]
 * @lastModifiedBy Charles EID   [19-10-26]
 ────────────────────────────────────── */
@isTest
private class Test_ProjectProductChildDatatableCTRL {

    @isTest
    static void testProjectProductChildMethods() {
        ProjectProduct__c project = PMTTestFactoryData.createProjectProduct(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(project.Id, 'Proposal', 'ProductStrategy');

        Test.startTest();

        List<ProjectProductChild__c> children = ProjectProductChildDatatableController.getChildren(project.Id);
        List<String> statuses = ProjectProductChildDatatableController.getStatusPicklistValues();
        List<ProjectProductChild__c> updated = ProjectProductChildDatatableController.updateChildren(new List<ProjectProductChild__c>{ new ProjectProductChild__c(Id = child.Id, Status__c = 'On track') });
        ProjectProductChildDatatableController.deleteChild(child.Id);

        Test.stopTest();

        System.assertEquals(6, children.size(), 'The 5 phases created with the project and the test phase');
        System.assert(statuses.contains('Completed') && statuses.contains('On track') && statuses.contains('Not Started'));
        System.assertEquals('On track', updated[0].Status__c);
        System.assertEquals(0, [SELECT COUNT() FROM ProjectProductChild__c WHERE Id = :child.Id], 'The phase is deleted');
    }
}