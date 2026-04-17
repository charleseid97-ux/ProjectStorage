@isTest
private class Test_RoadToMarketDatatableController {
    @isTest
    static void testRoadToMarketMethods() {


         RoadToMarket__c taskbefore = new RoadToMarket__c(
            Name = 'Test Task',
            Team__c = 'Legal',
            Deadline__c = Date.today(),
            Status__c = 'To Be Started'
        );

        insert taskBefore;

 
        RoadToMarket__c task = new RoadToMarket__c(
            Name = 'Test Task',
            RoadToMarket__c = taskBefore.Id,
            Team__c = 'Legal',
            Deadline__c = Date.today(),
            Status__c = 'To Be Started'
        );
        insert task;
 
        Test.startTest();
        List<RoadToMarket__c> tasks = RoadToMarketDatatableController.getTasks(taskBefore.Id, null);
 
        List<String> teams = RoadToMarketDatatableController.getTeamPicklistValues();
        List<String> statuses = RoadToMarketDatatableController.getStatusPicklistValues();
 
        task.Description__c = 'Updated desc';
        List<RoadToMarket__c> updated = RoadToMarketDatatableController.updateTasks(new List<RoadToMarket__c>{ task });
 
        RoadToMarketDatatableController.deleteTask(task.Id);
        Test.stopTest();
    }
}