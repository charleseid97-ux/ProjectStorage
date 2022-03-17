/**
* @author: Noor Goolamnabee
* @date : 12/07/2019
* @description : This allows to make create Campaign in eTouches asynchronously by bunch
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 12-JUL-2019  JLC         1.1    #17135 Implement queueable interface to be able to process campaign in batch
*  NOOR : To be deleted
*/
public with sharing class CallCreateCampaignEtouchesAsync extends AsyncQueueableImplementation implements Database.AllowsCallouts{


    public CallCreateCampaignEtouchesAsync(List<SObject> sObjects, Integer index, Integer batchSize) {

        super(sObjects, index, batchSize);
    }
    /*
       public override void processRecordList(List<SObject> processList) {
           //Noor Decommissioning Aventri Date : 02/03/2021
          //SM014_CampaignTriggerHandler.callCreateAllCampaigneTouches((List<Campaign>) processList);

       }


       * Execute the new bunch of list

       public override void executeNext(List<SObject> sObjects, Integer nextIndex, Integer batchSize){

           //System.enqueueJob(new CallCreateCampaignEtouchesAsync(sObjects, nextIndex, batchSize));
       }*/

}