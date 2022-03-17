/**
* @author: Noor Goolamnabee
* @date : 12/07/2019
* @description : This allows to make create Campaign in eTouches asynchronously by bunch
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 12-JUL-2019  JLC         1.1    #17135 Implement queueable interface to be able to process campaign in batch
* Noor To be deleted
*/
public with sharing class SM016_CallUpdateSubscriberEtouchesAsync extends AsyncQueueableImplementation implements Database.AllowsCallouts{

    public SM016_CallUpdateSubscriberEtouchesAsync(List<SObject> sObjects, Integer index, Integer batchSize) {

        super(sObjects, index, batchSize);

    }
/*
    public override void processRecordList(List<SObject> processList) {

        //SM016_CampaignMemberService.callSubscriberUpdate((List<CampaignMember>) processList);

    }


    * Execute the new bunch of list

    public override void executeNext(List<SObject> sObjects, Integer nextIndex, Integer batchSize){

        System.enqueueJob(new SM016_CallUpdateSubscriberEtouchesAsync(sObjects, nextIndex, batchSize));
    }*/

}