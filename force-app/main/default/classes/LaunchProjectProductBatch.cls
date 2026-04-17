public class LaunchProjectProductBatch {
    @AuraEnabled
    public static void launch(List<Id> projectProductIds) {
        if (!projectProductIds.isEmpty()) {
            ProjectProductBatch batchJob = new ProjectProductBatch();
            Id batchJobId = Database.executeBatch(batchJob, 200);
            AsyncApexJob aaj = [SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors FROM AsyncApexJob WHERE ID =: batchJobId ];
            System.debug('Job Id: ' + batchJobid + ' Status: ' + aaj.Status);
        }
    }
}