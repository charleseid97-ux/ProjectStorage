global with sharing class ProjectProductBatchScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        ProjectProductBatch batch = new ProjectProductBatch();
        Database.executeBatch(batch, 200);
    }
}