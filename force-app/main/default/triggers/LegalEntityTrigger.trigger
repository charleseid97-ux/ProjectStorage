/**
* Created by TRIA A on 06/04/2020.
*/
trigger LegalEntityTrigger on Legal_Entity__c (before insert, after insert, before update) {
    TriggerDispatcher.Run(new LegalEntityTriggerHandler());
}