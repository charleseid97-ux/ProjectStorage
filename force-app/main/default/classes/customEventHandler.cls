public without sharing class customEventHandler implements ITriggerHandler {

    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {
        List<Event__c> newEvents = (List<Event__c>) newItems;
        List<Event__c> eventsToProcess = filterAutomatedEvents(newEvents);

        if (eventsToProcess.isEmpty()) return;

        customEventService.validateEvents(eventsToProcess, null);
        customEventService.setEventName(eventsToProcess, true);       
        customEventService.setDigitalLocation(eventsToProcess, null);
        customEventService.copyCompanyBillingAddressToEvent(eventsToProcess, null);    
        //should come after the address is set 
        customEventService.setTimeZone(eventsToProcess);       

    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, Event__c> newEvents = (Map<Id, Event__c>) newItems;
        Map<Id, Event__c> oldEvents = (Map<Id, Event__c>) oldItems;

        Map<Id, Event__c> newEventsToProcess = filterAutomatedEventsMap(newEvents);
        Map<Id, Event__c> oldEventsToProcess = filterOldMap(oldEvents, newEventsToProcess.keySet());

        if (newEventsToProcess.isEmpty()) return;

        customEventService.validateEvents(newEventsToProcess.values(), oldEventsToProcess);
        customEventService.setDigitalLocation(newEventsToProcess.values(), oldEventsToProcess);
        customEventService.updateName(oldEventsToProcess, newEventsToProcess);
        customEventService.copyCompanyBillingAddressToEvent(newEventsToProcess.values(), oldEventsToProcess);
        customEventSpeakerApprovalService.prepareSpeakerHTMLforNotifications(newEventsToProcess, oldEventsToProcess);    
        customEventSpeakerApprovalService.markEventFullyApprovedIfNoSSP(newEventsToProcess, oldEventsToProcess);
        EventSpeakerApprovalsService.triggerRollupFromEventBeforeUpdate(newEventsToProcess, oldEventsToProcess);
        // We submit on update, not on insert, because speakers are linked after creation.
        // That later update lets us rebuild the final event Name and then move the record
        // from Draft to SubmittedToEventTeam. The actual Approval.process call is done in after update.
        customEventService.setReadyForApprovalProcess(newEventsToProcess.values(), oldEventsToProcess);
    }

    public void BeforeDelete(Map<Id, SObject> oldItems) {}

    public void AfterInsert(Map<Id, SObject> newItems) {
        Map<Id, Event__c> newEvents = (Map<Id, Event__c>) newItems;
        Map<Id, Event__c> newEventsToProcess = filterAutomatedEventsMap(newEvents);

        if (newEventsToProcess.isEmpty()) return;

        customEventSpeakerApprovalService.createOrUpdateSpeakerApprovals(
            newEventsToProcess,
            null
        );
        /*customEventNotificationManager.notifyOneToOneMeetingDaysCreated(
            new List<Event__c>(newEventsToProcess.values())
        );*/
        BooklyMeetingInvitationService.enqueueInvitationsOnApproval(newEventsToProcess.values(), null);
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, Event__c> newEvents = (Map<Id, Event__c>) newItems;
        Map<Id, Event__c> oldEvents = (Map<Id, Event__c>) oldItems;

        Map<Id, Event__c> newEventsToProcess = filterAutomatedEventsMap(newEvents);
        Map<Id, Event__c> oldEventsToProcess = filterOldMap(oldEvents, newEventsToProcess.keySet());

        if (newEventsToProcess.isEmpty()) return;

        customEventSpeakerApprovalService.createOrUpdateSpeakerApprovals(newEventsToProcess, oldEventsToProcess);
        sessionSpeakerProductService.requestRequiredPresentationsForWaitingEvents(newEventsToProcess, oldEventsToProcess);
        // Send approval notification email if status changes to SubmittedToEventTeam
        //customEventNotificationService.manageNotifications(newEventsToProcess, oldEventsToProcess);
        
        // Create Campaign when Event is fully approved
        customEventService.createCampaign(new List<Event__c>(newEventsToProcess.values()), oldEventsToProcess);
        customEventService.startEventTeamApprovalAfterUpdate(newEventsToProcess.values(), oldEventsToProcess);
        customEventService.submitOrganizerApproval(newEventsToProcess.values(), oldEventsToProcess);
        // Send generic event status notification \ it send also the creation email because events are created as draft and updated post creation
        customEventNotificationManager.notifyEventStatusChange( oldEventsToProcess,newEventsToProcess);
        customEventService.notifyProductTeam(newEventsToProcess, oldEventsToProcess);

        BooklyMeetingInvitationService.enqueueInvitationsOnApproval(newEventsToProcess.values(), oldEventsToProcess);

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

    private static List<Event__c> filterAutomatedEvents(List<Event__c> events) {
        List<Event__c> result = new List<Event__c>();
        for (Event__c e : events) {
            if (e.noAutomations__c != true) {
                result.add(e);
            }
        }
        return result;
    }

    private static Map<Id, Event__c> filterAutomatedEventsMap(Map<Id, Event__c> events) {
        Map<Id, Event__c> result = new Map<Id, Event__c>();
        for (Id eventId : events.keySet()) {
            if (events.get(eventId).noAutomations__c != true) {
                result.put(eventId, events.get(eventId));
            }
        }
        return result;
    }

    private static Map<Id, Event__c> filterOldMap(Map<Id, Event__c> oldEvents, Set<Id> idsToKeep) {
        Map<Id, Event__c> result = new Map<Id, Event__c>();
        for (Id eventId : idsToKeep) {
            if (oldEvents.containsKey(eventId)) {
                result.put(eventId, oldEvents.get(eventId));
            }
        }
        return result;
    }
}