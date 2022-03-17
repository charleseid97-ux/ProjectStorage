/**
* @author Abderrahmane TRIA
* @date Creation 27/04/2020
* @group Scheduler
* @description Scheduler BATCH to Insert Legal Entities From UME
*/
public class BATCH004_InsertLegalEnitiesUME_Scheduler  implements Schedulable{
    
    public void execute(SchedulableContext sc) {
        
        BATCH009_InsertProfileUME job = new BATCH009_InsertProfileUME();
        if(!isRunning()){
            ObjectUtil.debugLog('BATCH004_InsertLEnitiesUME_Scheduler', 'execute', ' [isRunning]' );
            Database.executebatch(job, 100);
        }
        
    }
    
   /*
    * Method to check if the corresponding batch is currently running.
    */
    public Boolean isRunning(){
        
        List<AsyncApexJob> jobs =  [Select Id, ApexClass.Name from AsyncApexJob where ApexClass.Name LIKE 'BATCH004_InsertLegalEnitiesUME%'
                                    AND JobType = 'BatchApex' AND Status NOT IN :new Set<String> {'Aborted', 'Completed', 'Failed'} ];
        
        return (jobs != null && jobs.size() > 1 );
    }
}