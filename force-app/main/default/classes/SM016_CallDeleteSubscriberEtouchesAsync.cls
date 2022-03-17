/**
* @author: Noor Goolamnabee
* @date : 12/07/2019
* @description : This allows to make create Campaign in eTouches asynchronously by bunch
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 12-JUL-2019  JLC         1.1    #17135 Implement queueable interface to be able to process campaign in batch
* NOOR : To be deleted
*/
public with sharing class SM016_CallDeleteSubscriberEtouchesAsync extends AsyncQueueableDeleteImplementation implements Database.AllowsCallouts{

    public SM016_CallDeleteSubscriberEtouchesAsync(List<String> sObjects, Integer index, Integer batchSize) {

        super(sObjects, index, batchSize);

    }

    /*public override void processRecordList(List<String> processList) {

        //SM016_CampaignMemberService.callDeleteSubscriber((List<String>) processList);

    }


    * Execute the new bunch of list

    public override void executeNext(List<String> sObjects, Integer nextIndex, Integer batchSize){

        System.enqueueJob(new SM016_CallDeleteSubscriberEtouchesAsync(sObjects, nextIndex, batchSize));
    } */

}