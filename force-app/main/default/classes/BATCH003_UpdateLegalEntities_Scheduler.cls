/**
* @author Abderrahmane TRIA
* @date Creation 19/04/2020
* @group Scheduler
* @description Scheduler BATCH to update Legal Entities From GLEIF
*/
public with sharing class BATCH003_UpdateLegalEntities_Scheduler implements Schedulable{
    
    public void execute(SchedulableContext sc) {
        
        BATCH003_UpdateLegalEntities job = new BATCH003_UpdateLegalEntities();
        if(!isRunning()){
            ObjectUtil.debugLog('BATCH003_UpdateLegalEntities_Scheduler', 'execute', ' [isRunning]' );
            Database.executebatch(job, 100);
        }
        
    }
    
   /*
    * Method to check if the corresponding batch is currently running.
    */
    public Boolean isRunning(){
        
        List<AsyncApexJob> jobs =  [Select Id, ApexClass.Name from AsyncApexJob where ApexClass.Name LIKE 'BATCH003_UpdateLegalEntities%'
                                    AND JobType = 'BatchApex' AND Status NOT IN :new Set<String> {'Aborted', 'Completed', 'Failed'} ];
        
        return (jobs != null && jobs.size() > 1 );
    }
}