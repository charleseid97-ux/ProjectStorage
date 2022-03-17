/**
* @author Abderrahmane TRIA
* @date Creation 16/11/2020
* @group BATCH
* @description Schedulable Snapshots BUY List
*/
global class BATCH011_SnapshotBUYList_Schedulable implements Schedulable {

    global void execute(SchedulableContext ctx) {
        BATCH011_SnapshotBUYList obj= new BATCH011_SnapshotBUYList();
        //Batch size is 200, records will be split into batches
        Database.ExecuteBatch(obj, 200);
    }
}