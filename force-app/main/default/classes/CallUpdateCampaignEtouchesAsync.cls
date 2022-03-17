/**
* @author: Noor Goolamnabee
* @date : 12/07/2019
* @description : This allows to make update Campaign in eTouches asynchronously by bunch
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 12-JUL-2019  JLC         1.1    #17135 Implement queueable interface to be able to process campaign in batch
* Noor TO BE DELETED
*/
public with sharing class CallUpdateCampaignEtouchesAsync extends AsyncQueueableImplementation implements Database.AllowsCallouts {


    public CallUpdateCampaignEtouchesAsync(List<SObject> sObjects, Integer index, Integer batchSize) {

        super(sObjects, index, batchSize);
    }

    /*public override void processRecordList(List<SObject> processList) {
        //Noor Decommissioning Aventri Date : 02/03/2021
        //SM014_CampaignTriggerHandler.callUpdateEtouchesEventandMailinglist((List<Campaign>) processList);

    }


     * Execute the new bunch of list

    public override void executeNext(List<SObject> sObjects, Integer nextIndex, Integer batchSize){

        //System.enqueueJob(new CallUpdateCampaignEtouchesAsync(sObjects, nextIndex, batchSize));
    } */
}