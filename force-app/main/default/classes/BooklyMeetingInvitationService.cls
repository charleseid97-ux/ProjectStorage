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
}