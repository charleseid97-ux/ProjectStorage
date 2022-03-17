/**
 * Created by noorg on 04/06/2021.
 */

trigger KYD_Due_Diligence_OversightTrigger on KYD_Due_Diligence_Oversight__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    TriggerDispatcher.Run(new SM033_KYD_DD_OversightTriggerHandler());
}