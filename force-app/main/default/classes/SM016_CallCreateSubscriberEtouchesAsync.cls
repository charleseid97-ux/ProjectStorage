/**
* @author: Noor Goolamnabee
* @date : 12/07/2019
* @description : This allows to make create Campaign in eTouches asynchronously by bunch
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 12-JUL-2019  JLC         1.1    #17135 Implement queueable interface to be able to process campaign in batch
*  Noor TO be deleted
*/
public with sharing class SM016_CallCreateSubscriberEtouchesAsync extends AsyncQueueableImplementation implements Database.AllowsCallouts{

    Map<Id,String> eventIdByCMMap ;
    Map<Id,String> mailingListIdByCMMap;

    public SM016_CallCreateSubscriberEtouchesAsync(List<SObject> sObjects, Integer index, Integer batchSize) {

        super(sObjects, index, batchSize);

        //this.eventIdByCMMap = eventIdByCMMap;
        //this.mailingListIdByCMMap = mailingListIdByCMMap;
    }
/*
    public override void processRecordList(List<SObject> processList) {

       //SM016_CampaignMemberService.callCreateSubscribereTouches((List<CampaignMember>) processList);

    }


    * Execute the new bunch of list

    public override void executeNext(List<SObject> sObjects, Integer nextIndex, Integer batchSize){

        System.enqueueJob(new SM016_CallCreateSubscriberEtouchesAsync(sObjects, nextIndex, batchSize));
    }*/

}