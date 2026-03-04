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
        Map<Id, Event__c> newEvents = (Map<Id, Event__c>) newItems;
        Map<Id, Event__c> oldEvents = (Map<Id, Event__c>) oldItems;
        customEventSpeakerApprovalService.markEventFullyApprovedIfNoSSP(newEvents, oldEvents);
        customEventService.setEventName(newEvents.values(), oldEvents);
        customEventService.copyCompanyBillingAddressToEvent(newEvents.values(), oldEvents);
        customEventSpeakerApprovalService.prepareSpeakerHTMLforNotifications(newEvents, oldEvents);    
    }

    public void BeforeDelete(Map<Id, SObject> oldItems) {}

    public void AfterInsert(Map<Id, SObject> newItems) {
        Map<Id, Event__c> newEvents = (Map<Id, Event__c>) newItems;

        customEventSpeakerApprovalService.createOrUpdateSpeakerApprovals(
            newEvents,
            null
        );

        customEventService.startEventTeamApprovalAfterInsert(newEvents.values());
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, Event__c> newEvents = (Map<Id, Event__c>) newItems;
        Map<Id, Event__c> oldEvents = (Map<Id, Event__c>) oldItems;

        customEventSpeakerApprovalService.createOrUpdateSpeakerApprovals(
            newEvents,
            oldEvents
        );

        // Send approval notification email if status changes to SubmittedToEventTeam
        customEventNotificationService.manageNotifications(
            newEvents,
            oldEvents
        );
        // Create Campaign when Event is fully approved
        customEventService.createCampaign(
            new List<Event__c>(newEvents.values()),
            oldEvents
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