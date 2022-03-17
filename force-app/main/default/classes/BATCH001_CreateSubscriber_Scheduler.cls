/**
* @author: Noor Goolamnabee
* @date : 12/02/2020
* @description : This batch is used to cater for the new limitation of Aventri.
*                The limitation that Aventri can accept only 400 calls per minute.
*                The batch is scheduled every 5 mins and treat each campaign member where TECH_AsyncAction = Create
*
*                System.schedule('BATCH001_CreateSubscriber__00', '0 00 * * * ?', new BATCH001_CreateSubscriber_Scheduler());
*                System.schedule('BATCH001_CreateSubscriber__05', '0 05 * * * ?', new BATCH001_CreateSubscriber_Scheduler());
*                System.schedule('BATCH001_CreateSubscriber__10', '0 10 * * * ?', new BATCH001_CreateSubscriber_Scheduler());
*                System.schedule('BATCH001_CreateSubscriber__15', '0 15 * * * ?', new BATCH001_CreateSubscriber_Scheduler());
*                System.schedule('BATCH001_CreateSubscriber__20', '0 20 * * * ?', new BATCH001_CreateSubscriber_Scheduler());
*                System.schedule('BATCH001_CreateSubscriber__25', '0 25 * * * ?', new BATCH001_CreateSubscriber_Scheduler());
*                System.schedule('BATCH001_CreateSubscriber__30', '0 30 * * * ?', new BATCH001_CreateSubscriber_Scheduler());
*                System.schedule('BATCH001_CreateSubscriber__35', '0 35 * * * ?', new BATCH001_CreateSubscriber_Scheduler());
*                System.schedule('BATCH001_CreateSubscriber__40', '0 40 * * * ?', new BATCH001_CreateSubscriber_Scheduler());
*                System.schedule('BATCH001_CreateSubscriber__45', '0 45 * * * ?', new BATCH001_CreateSubscriber_Scheduler());
*                System.schedule('BATCH001_CreateSubscriber__50', '0 50 * * * ?', new BATCH001_CreateSubscriber_Scheduler());
*                System.schedule('BATCH001_CreateSubscriber__55', '0 55 * * * ?', new BATCH001_CreateSubscriber_Scheduler());
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 12-JUL-2019  JLC
*
*/


public with sharing class BATCH001_CreateSubscriber_Scheduler implements Schedulable{

    public void execute(SchedulableContext sc) {

        //Custom  object that store the status of the batch
        // If the value isRunning for the the record BATCH001 is true, the batch is running else  the batch can be launched
        Batch_Setting__c batchSetting = [SELECT id, isRunning__c, BatchSize__c, Limit__c FROM Batch_Setting__c WHERE Name='BATCH001'];

        string query = 'SELECT Id,TECH_AsyncAction__c, Subscriber__c, Category_Event_lookup__c, Event_Email__c, FirstName, ' +
                'LastName, Salutation, Job_Title__c, Company_T__c, Address_Line_1__c, City__c, Country__c, Zip__c, ' +
                'Phone__c, Mobile__c, Language__c, Contact_Owner__c, Owner_email__c, Last_Etouches_action_synchronized__c, TECH_ID_Subscriber__c, ' +
                'campaign.Event_code_Etouches__c, campaign.TECH_Mailing_List_ID_Etouches__c,  campaign.Status ' +
                'FROM CampaignMember WHERE TECH_ID_Subscriber__c = \'\' AND (TECH_AsyncAction__c = \'Create\' OR  TECH_AsyncAction__c like \'Retry%\')  limit '+batchSetting.Limit__c;

        BATCH001_CreateSubscriber job = new BATCH001_CreateSubscriber(query);
        if(!batchSetting.isRunning__c){
            updateBatchFlagToRunning(batchSetting);
            ObjectUtil.debugLog('BATCH001_CreateSubscriber_Scheduler', 'execute', ' [isRunning]' );
            Database.executebatch(job, Integer.valueOf(batchSetting.BatchSize__c));
        }
    }

    /*
  * Method to check if the corresponding batch is currently running.
  */
    public void updateBatchFlagToRunning(Batch_Setting__c batchSetting){
        batchSetting.isRunning__c = true;
        update batchSetting;
    }


    /*
  * Method to check if the corresponding batch is currently running.

   public Boolean isRunning(Id_Tech_Sun_Legacy__c setting){

       List<AsyncApexJob> jobs =  [Select Id, ApexClass.Name from AsyncApexJob where ApexClass.Name LIKE 'BATCH001_CreateSubscriber%'
                                   AND JobType = 'BatchApex' AND Status NOT IN :new Set<String> {'Aborted', 'Completed', 'Failed'} ];
       return (jobs != null && jobs.size() > 1 );

   }*/
}