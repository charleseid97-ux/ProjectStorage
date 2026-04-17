/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 12-05-2024
 * @last modified by  : SILA Nicolas
**/
global class FlowAumMergerBatchScheduler implements Schedulable {
    
    global void execute(SchedulableContext SC) {
        FlowAumMergerBatch batchJob = new FlowAumMergerBatch();
        Database.executeBatch(batchJob, 10000);
     }
}