public without sharing class BooklyMeetingInvitationService {
    private static final String APPROVED_STATUS = 'FullyApproved';
    private static final String SUBJECT_PREFIX = '[Bookly] - ';
    private static final String DEFAULT_TIME_ZONE = 'Europe/Paris';

    public static void enqueueInvitationsOnApproval(
        List<Event__c> newEvents,
        Map<Id, Event__c> oldMap
    ) {
        Set<Id> approvedEventIds = new Set<Id>();

        for (Event__c eventRecord : newEvents) {
            Event__c oldEvent = oldMap != null ? oldMap.get(eventRecord.Id) : null;

            Boolean becameFullyApproved =
                eventRecord.Status__c == APPROVED_STATUS &&
                (oldEvent == null || oldEvent.Status__c != APPROVED_STATUS);

            if (becameFullyApproved) {
                approvedEventIds.add(eventRecord.Id);
            }
        }

        if (!approvedEventIds.isEmpty()) {
            System.enqueueJob(new BooklyMeetingInvitationQueueable(approvedEventIds));
        }
    }

    // Lance la mise à jour Microsoft Graph si un champ impactant le meeting change.
    public static void enqueueInvitationUpdatesOnEventChange(
        List<Event__c> newEvents,
        Map<Id, Event__c> oldMap
    ) {
        Set<Id> eventIdsToUpdate = new Set<Id>();

        for (Event__c eventRecord : newEvents) {
            Event__c oldEvent = oldMap != null ? oldMap.get(eventRecord.Id) : null;

            // Ignore les créations et les events sans invitation Microsoft Graph.
            if (oldEvent == null || String.isBlank(eventRecord.MicrosoftEventId__c)) {
                continue;
            }

            Boolean meetingChanged =
                eventRecord.StartDate__c != oldEvent.StartDate__c ||
                eventRecord.StartTime__c != oldEvent.StartTime__c ||
                eventRecord.EndDate__c != oldEvent.EndDate__c ||
                eventRecord.EndTime__c != oldEvent.EndTime__c ||
                eventRecord.TimeZone__c != oldEvent.TimeZone__c ||
                eventRecord.City__c != oldEvent.City__c;

            Boolean becameCancelled =
                eventRecord.Status__c == 'Cancelled' &&
                oldEvent.Status__c != 'Cancelled';

            if (meetingChanged || becameCancelled) {
                eventIdsToUpdate.add(eventRecord.Id);
            }
        }

        if (!eventIdsToUpdate.isEmpty()) {
            System.enqueueJob(new BooklyMeetingInvitationQueueable(eventIdsToUpdate, true));
        }
    }
    
}