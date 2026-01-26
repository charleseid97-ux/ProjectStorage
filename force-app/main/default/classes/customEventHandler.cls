public with sharing class customEventHandler implements ITriggerHandler {

    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {
        List<Event__c> newEvents = (List<Event__c>) newItems;

        customEventService.setEventName(newEvents, null);
        customEventService.copyCompanyBillingAddressToEvent(newEvents, null);

        // Start Event Team approval logic (temporary forced status)
        customEventService.startEventTeamApproval(newEvents);
    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        List<Event__c> newEvents = (List<Event__c>) newItems.values();
        Map<Id, Event__c> oldEvents = (Map<Id, Event__c>) oldItems;

        customEventService.setEventName(newEvents, oldEvents);
        customEventService.copyCompanyBillingAddressToEvent(newEvents, oldEvents);
    }

    public void BeforeDelete(Map<Id, SObject> oldItems) {}

    public void AfterInsert(Map<Id, SObject> newItems) {
        customEventSpeakerApprovalService.createOrUpdateSpeakerApprovals(
            (Map<Id, Event__c>) newItems,
            null
        );
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        customEventSpeakerApprovalService.createOrUpdateSpeakerApprovals(
            (Map<Id, Event__c>) newItems,
            (Map<Id, Event__c>) oldItems
        );
    }

    public void AfterDelete(Map<Id, SObject> oldItems) {}
    public void AfterUndelete(Map<Id, SObject> oldItems) {}

    public Boolean isDisabled() {
        if (PAD.canTrigger('customEventHandler')) {
            return triggerDisabled;
        } else {
            return true;
        }
    }
}