/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 18-04-2024
 * @last modified by  : Thanina YAYA
**/
global without sharing class BATCH_DeleteAUMs_Scheduler implements Schedulable {
    
    global void execute(SchedulableContext SC) {
        BATCH_DeleteAUMs bAum = new BATCH_DeleteAUMs();
        Database.executebatch(bAum, 50);
     }
}