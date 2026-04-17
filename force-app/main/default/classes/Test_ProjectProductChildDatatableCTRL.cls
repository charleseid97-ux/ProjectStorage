@isTest
private class Test_ProjectProductChildDatatableCTRL {
    @isTest
    static void testProjectProductChildMethods() {
        Id recordTypeId = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation');
        ProjectProduct__c pp = PMTTestFactoryData.createProjectProduct(recordTypeId);
 
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(pp.Id, 'Proposal', 'ProductStrategy');
 
        Test.startTest();
        List<ProjectProductChild__c> children = ProjectProductChildDatatableController.getChildren(pp.Id);
 
        List<String> status = ProjectProductChildDatatableController.getStatusPicklistValues();
 
        child.Status__c = status.isEmpty() ? null : status[0];
        List<ProjectProductChild__c> updated = ProjectProductChildDatatableController.updateChildren(new List<ProjectProductChild__c>{ child });
 
        ProjectProductChildDatatableController.deleteChild(child.Id);
        Test.stopTest();
    }
}