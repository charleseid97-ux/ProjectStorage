public with sharing class MeetingNoteShareController {

    @AuraEnabled(cacheable=true)
    public static Id getMeetingNoteIdByEvent(Id eventId) {
        if (eventId == null) {
            return null;
        }

        Event evt = [
            SELECT Meeting_Note__c
            FROM Event
            WHERE Id = :eventId
            LIMIT 1
        ];

        return evt.Meeting_Note__c;
    }
}