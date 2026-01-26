public with sharing class EventMeetingNoteQuickActionCTRL {

    public class Payload {
        @AuraEnabled public Id eventId;
        @AuraEnabled public String eventName;
        @AuraEnabled public Id companyId;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Id meetingNoteId;
        @AuraEnabled public String meetingNoteName;
        @AuraEnabled public Date meetingNoteDate;
        @AuraEnabled public String meetingType;
        @AuraEnabled public String noteHtml;
        @AuraEnabled public Boolean hasMeetingNote;
    }

    @AuraEnabled(cacheable=false)
    public static Payload getPayload(Id eventId) {
        if (eventId == null) return new Payload();

        Event__c ev = [
            SELECT Id, Name, company__c, startDate__c, meetingNote__c,
                   meetingNote__r.Id, meetingNote__r.Name, meetingNote__r.Date__c,
                   meetingNote__r.Meeting_Type__c, meetingNote__r.Note__c
            FROM Event__c
            WHERE Id = :eventId
            LIMIT 1
        ];

        Payload p = new Payload();
        p.eventId = ev.Id;
        p.eventName = ev.Name;
        p.companyId = ev.company__c;
        p.startDate = ev.startDate__c;

        p.meetingNoteId = ev.meetingNote__c;
        p.hasMeetingNote = (ev.meetingNote__c != null);

        if (p.hasMeetingNote && ev.meetingNote__r != null) {
            p.meetingNoteName = ev.meetingNote__r.Name;
            p.meetingNoteDate = ev.meetingNote__r.Date__c;
            p.meetingType = ev.meetingNote__r.Meeting_Type__c;
            p.noteHtml = ev.meetingNote__r.Note__c;
        } else {
            p.meetingNoteName = ev.Name;
            p.meetingNoteDate = ev.startDate__c;
            p.meetingType = 'Meeting day(s)';
            p.noteHtml = '';
        }

        return p;
    }

    public class SaveResult {
        @AuraEnabled public Id meetingNoteId;
        @AuraEnabled public Boolean created;
    }

    @AuraEnabled
    public static SaveResult save(Id eventId, String noteHtml) {
        if (eventId == null) {
            throw new AuraHandledException('Missing Event Id.');
        }

        Event__c ev = [
            SELECT Id, Name, company__c, startDate__c, meetingNote__c
            FROM Event__c
            WHERE Id = :eventId
            LIMIT 1
            FOR UPDATE
        ];

        if (String.isBlank(noteHtml)) {
            noteHtml = '';
        }

        SaveResult res = new SaveResult();

        if (ev.meetingNote__c != null) {
            Meeting_Note__c mn = [
                SELECT Id, Note__c
                FROM Meeting_Note__c
                WHERE Id = :ev.meetingNote__c
                LIMIT 1
                FOR UPDATE
            ];
            mn.Note__c = noteHtml;
            update mn;

            res.meetingNoteId = mn.Id;
            res.created = false;
            return res;
        }

        Meeting_Note__c mnNew = new Meeting_Note__c();
        mnNew.Name = ev.Name;
        mnNew.Company__c = ev.company__c;
        mnNew.Date__c = ev.startDate__c;
        mnNew.Meeting_Type__c = 'Meeting day(s)';
        mnNew.Note__c = noteHtml;

        insert mnNew;

        ev.meetingNote__c = mnNew.Id;
        update ev;

        res.meetingNoteId = mnNew.Id;
        res.created = true;
        return res;
    }
}