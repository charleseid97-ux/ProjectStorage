/**
* @author Abderrahmane TRIA
* @date Creation 28/05/2020
* @group Scheduler
* @description Scheduler BATCH to update Lead created by BrightTALK
*/
public with sharing class BATCH005_Lead_BrightTALK_Scheduler implements Schedulable{
    
    public void execute(SchedulableContext sc) {
        
        BATCH005_Lead_BrightTALK job = new BATCH005_Lead_BrightTALK();
        if(!isRunning()){
            ObjectUtil.debugLog('BATCH005_Lead_BrightTALK_Scheduler', 'execute', ' [isRunning]' );
            Database.executebatch(job, 200);
        }
        
    }
    
   /*
    * Method to check if the corresponding batch is currently running.
    */
    public Boolean isRunning(){
        
        List<AsyncApexJob> jobs =  [Select Id, ApexClass.Name from AsyncApexJob where ApexClass.Name LIKE 'BATCH005_Lead_BrightTALK%'
                                    AND JobType = 'BatchApex' AND Status NOT IN :new Set<String> {'Aborted', 'Completed', 'Failed'} ];
        
        return (jobs != null && jobs.size() > 1 );
    }
}