/**
* @author: Noor Goolamnabee
* @date : 12/02/2020
* @description : This batch is used to cater for the new limitation of Aventri.
*                The limitation that Aventri can accept only 400 calls per minute.
*                The batch is scheduled every 5 mins and treat each campaign member where TECH_AsyncAction = Create
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 12-JUL-2019  JLC
* Noor To be deleted
*/

public with sharing class BATCH001_CreateSubscriber implements Database.Batchable<sObject>, Database.AllowsCallouts{

    String query;

    public  BATCH001_CreateSubscriber(String aQuery) {
        query = aQuery;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        Database.QueryLocator qloc = Database.getQueryLocator(query);
        return qloc;
    }

    public void execute(Database.BatchableContext BC, List<CampaignMember> campaignMembers) {

        ObjectUtil.debugLog('BATCH001_CreateSubscriber', 'execute', ' [campaignMembers] : ' + campaignMembers);
        //SM016_CampaignMemberService.callCreateSubscribereTouches(campaignMembers);
        for(CampaignMember member : campaignMembers){
            if(member.TECH_AsyncAction__c.equalsIgnoreCase('Create'))  member.TECH_AsyncAction__c = 'Error - Internal';
        }
        update campaignMembers;

    }

    public void finish(Database.BatchableContext param1) {

        Batch_Setting__c batchSetting = [SELECT id, isRunning__c FROM Batch_Setting__c WHERE Name='BATCH001'];
        batchSetting.isRunning__c = false;
        update batchSetting;

    }

}