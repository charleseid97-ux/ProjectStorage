trigger DigitalInteractionTrigger on Digital_Interaction__c (before insert) {

    if(Trigger.isBefore && Trigger.isInsert) {
        DigitalInteractionTriggerHandler.beforeInsert(Trigger.new);
    }
}