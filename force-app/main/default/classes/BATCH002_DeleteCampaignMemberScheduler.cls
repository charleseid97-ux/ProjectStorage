/**
* @author: Noor Goolamnabee
* @date : 24/03/2020
* @description : This batch is used to delete unused campaign member
*
*                System.schedule('BATCH002_DeleteCampaignMemberScheduler', '0 0 23 * * ? *', new BATCH001_CreateSubscriber_Scheduler());
*
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 24-MAR-2020  JLC
*
*/
public with sharing class BATCH002_DeleteCampaignMemberScheduler implements Schedulable{

    public void execute(SchedulableContext sc) {

        string query = 'SELECT Id FROM CampaignMember ' +
                'WHERE Campaign.Status NOT IN (\'Closed\',  \'Cancelled\', \'Archived\') ' +
                'AND LastModifiedbyId <>  \'00558000002Fj0BAAS\' '+
                'AND ((Contact.ContactStatus__c = \'false\' OR Contact.Subscriber__c = true) ' +
                'OR (Lead.IsConverted = false AND (Lead.Status = \'Disqualified\' OR Lead.HasOptedOutOfEmail = true))  )';

        BATCH002_DeleteCampaignMember job = new BATCH002_DeleteCampaignMember(query);

        Database.executebatch(job, 2000);

    }
}