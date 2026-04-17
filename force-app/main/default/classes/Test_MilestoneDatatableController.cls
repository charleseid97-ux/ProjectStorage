@isTest
private class Test_MilestoneDatatableController {
    @isTest
    static void testMilestoneMethods() {
        
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        
        Milestone__c m = PMTTestFactoryData.createMilestone(proj.Id, 'Test Milestone', Date.today());
 
        Test.startTest();
        List<Milestone__c> result = MilestoneDatatableController.getMilestones(proj.Id);
 
        List<String> status = MilestoneDatatableController.getStatusPicklistValues();
 
        m.Status__c = status.isEmpty() ? null : status[0];
        List<Milestone__c> updated = MilestoneDatatableController.updateMilestones(new List<Milestone__c>{ m });
        Test.stopTest();
    }
}