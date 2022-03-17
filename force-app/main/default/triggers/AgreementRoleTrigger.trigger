/**
 * Created by noorgoolamnabee on 17/12/2021.
 */

trigger AgreementRoleTrigger on Agreement_Role__c (before insert, before update, after insert, after update, after delete,before delete, after undelete) {
  TriggerDispatcher.run(new AgreementRoleTriggerHandler());
}