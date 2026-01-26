public with sharing class customEventAttendeeHandler implements ITriggerHandler {

    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {}
    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {}
    public void BeforeDelete(Map<Id, SObject> oldItems) {}

    public void AfterInsert(Map<Id, SObject> newItems) {
        customEventAttendeeService.copyAddressToEventsFromAttendees(
            (List<EventAttendee__c>) newItems.values()
        );
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {}
    public void AfterDelete(Map<Id, SObject> oldItems) {}
    public void AfterUndelete(Map<Id, SObject> oldItems) {}

    public Boolean isDisabled() {
        if (PAD.canTrigger('customEventAttendeeHandler')) { return triggerDisabled; }
        else { return true; }
    }
}