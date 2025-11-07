/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 02-13-2024
 * @last modified by  : SILA Nicolas
**/
global class SCH_LastInteraction_Delta implements Schedulable
{
        global void execute(SchedulableContext sc)
        {
            String query = 
            'SELECT ' +
            '   Id, ' + 
            '   AccountId, CreatedDate, ' +
            '   CorporateTitle__c, ' +
            '   First_Last_name__c, ' +
            '   Last_Meeting_Call__c, ' +
            '   Last_Newsletter_sent__c, ' +
            '   Last_Newsletter_Sent_Type__c,' +
            '   Last_Newsletter_Opened__c, ' +
            '   Last_Event_attendance__c, ' +
            '   Last_Event_attendance_Type__c, ' +
            '   Last_Newsletter_Clicked__c ' +
            '   FROM ' +
            '       Contact '+
            '   WHERE '+
            '       LastModifiedDate <= TODAY ';
                
            BATCH012_LastInteraction batch = new BATCH012_LastInteraction(query);        
            Database.executeBatch(batch, 200);
        }

}