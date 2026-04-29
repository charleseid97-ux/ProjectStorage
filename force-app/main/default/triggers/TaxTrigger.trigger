trigger TaxTrigger on TaxData__c (
    before insert,
    before update,
    after insert,
    after update
) {
    if (Trigger.isBefore && Trigger.isInsert) {
        TaxDataTriggerHandler.handleBeforeInsert(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        TaxDataTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        TaxDataTriggerHandler.handleAfterInsert(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        TaxDataTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}