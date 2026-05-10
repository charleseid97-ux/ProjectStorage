public without sharing class EventMeetingNoteQuickActionCTRL {


    public class Payload {
        @AuraEnabled public Id eventId;
        @AuraEnabled public Id standardEventId;
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

    // Récupère les données nécessaires à l'écran
    @AuraEnabled(cacheable=false)
    public static Payload getPayload(Id eventId) {
        if (eventId == null) return new Payload();

        Event__c ev = [
            SELECT Id, Name, company__c, startDate__c, meetingNote__c, parentEvent__c,
                   meetingNote__r.Id, meetingNote__r.Name, meetingNote__r.Date__c,
                   meetingNote__r.Meeting_Type__c, meetingNote__r.Note__c,meetingNote__r.Raw_Note__c
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
        p.standardEventId = getStandardEventId(ev.meetingNote__c);

        if (p.hasMeetingNote && ev.meetingNote__r != null) {
            p.meetingNoteName = ev.meetingNote__r.Name;
            p.meetingNoteDate = ev.meetingNote__r.Date__c;
            p.meetingType = ev.meetingNote__r.Meeting_Type__c;
            p.noteHtml = ev.meetingNote__r.Raw_Note__c;
        } else {
            p.meetingNoteName = ev.Name;
            p.meetingNoteDate = ev.startDate__c;
            p.meetingType = getMeetingType(ev);
            p.noteHtml = '';
        }

        return p;
    }

    public class SaveResult {
        @AuraEnabled public Id meetingNoteId;
        @AuraEnabled public Boolean created;
    }

    // Sauvegarde ou crée la Meeting Note
    @AuraEnabled
    public static SaveResult save(Id eventId, String noteHtml) {
        if (eventId == null) {
            throw new AuraHandledException('Missing Event Id.');
        }

        Event__c ev = getEventForUpdate(eventId);

        if (ev.RecordType.DeveloperName != 'Meeting') {
            throw new AuraHandledException('Creation allowed only for one to one meetings.');
        }

        if (String.isBlank(noteHtml)) {
            noteHtml = '';
        }

        SaveResult res = new SaveResult();

        if (ev.meetingNote__c != null) {
            Meeting_Note__c mn = updateMeetingNote(ev.meetingNote__c, noteHtml);
            Id standardEventId = getStandardEventId(ev.meetingNote__c);

            if (standardEventId != null) {
                deleteExistingContacts(standardEventId);
                linkContacts(standardEventId, ev.Id);
            }
           
            res.meetingNoteId = mn.Id;
            res.created = false;
            return res;
        }

        Meeting_Note__c mnNew = createMeetingNote(ev, noteHtml);

        ev.meetingNote__c = mnNew.Id;
        update ev;

        Event stdEvent = createStandardEvent(ev, mnNew.Id);
        linkContacts(stdEvent.Id, ev.Id);
        res.meetingNoteId = mnNew.Id;
        res.created = true;
        return res;
    }

    // Récupère l'Event__c verrouillé pour update
    private static Event__c getEventForUpdate(Id eventId) {
        return [
            SELECT Id, Name, company__c, startDate__c, meetingNote__c, parentEvent__c, RecordType.DeveloperName
            FROM Event__c
            WHERE Id = :eventId
            LIMIT 1
            FOR UPDATE
        ];
    }

    // Met à jour une Meeting Note existante
    private static Meeting_Note__c updateMeetingNote(Id meetingNoteId, String noteHtml) {
        Meeting_Note__c mn = [
            SELECT Id, Note__c,Raw_Note__c
            FROM Meeting_Note__c
            WHERE Id = :meetingNoteId
            LIMIT 1
            FOR UPDATE
        ];

       // mn.Note__c = noteHtml;
        mn.Raw_Note__c =noteHtml;
        update mn;

        return mn;
    }

   

    // Crée la Meeting Note depuis l'Event__c
    private static Meeting_Note__c createMeetingNote(Event__c ev, String noteHtml) {
        Meeting_Note__c mn = new Meeting_Note__c();
        mn.Name = ev.Name;
        mn.Company__c = ev.company__c;
        mn.Date__c = ev.startDate__c;
        mn.Meeting_Type__c = getMeetingType(ev);
        //mn.Note__c = noteHtml;
        mn.Raw_Note__c= noteHtml;
        mn.SalesPresentation__c = true;
        insert mn;
        return mn;
    }

    // Détermine le type de Meeting Note selon le parent
    private static String getMeetingType(Event__c ev) {
        return (ev.parentEvent__c != null) ? 'Meeting day(s)' : 'Meeting';
    }

    // Crée l'Event standard lié à la Meeting Note et au compte
    private static Event createStandardEvent(Event__c ev, Id meetingNoteId) {
        Event e = new Event();
        e.Subject = ev.Name;
        e.WhatId = ev.company__c;
        e.Meeting_Note__c = meetingNoteId;
        e.StartDateTime = DateTime.newInstance(ev.startDate__c, Time.newInstance(9, 0, 0, 0));
        e.EndDateTime = DateTime.newInstance(ev.startDate__c, Time.newInstance(10, 0, 0, 0));

        insert e;
        return e;
    }

    // Lie les contacts de l'Event__c à l'Event standard
    private static void linkContacts(Id standardEventId, Id eventId) {
        List<EventRelation> relations = new List<EventRelation>();
        System.debug('======linkContacts=eventId : '+eventId);

        for (EventAttendee__c att : [
            SELECT Contact__c
            FROM EventAttendee__c
            WHERE Event__c = :eventId
        ]) {
            System.debug('====att : '+att);
            if (att.Contact__c != null) {
                EventRelation rel = new EventRelation();
                rel.EventId = standardEventId;
                rel.RelationId = att.Contact__c;
                rel.IsInvitee = true;
                rel.IsParent = true;
                relations.add(rel);
            }
        }
        System.debug('====relations : '+relations);

        if (!relations.isEmpty()) {
            insert relations;
        }
    }

 


   

   
    // Récupère l'Event standard lié à la Meeting Note
    private static Id getStandardEventId(Id meetingNoteId) {
        if (meetingNoteId == null) {
            return null;
        }

        List<Event> events = [
            SELECT Id
            FROM Event
            WHERE Meeting_Note__c = :meetingNoteId
            LIMIT 1
        ];

        return events.isEmpty() ? null : events[0].Id;
    }
    // Supprime les EventRelation existants liés aux contacts
    private static void deleteExistingContacts(Id standardEventId) {
        List<EventRelation> relations = [
            SELECT Id
            FROM EventRelation
            WHERE EventId = :standardEventId
            AND RelationId != null
        ];

        if (!relations.isEmpty()) {
            delete relations;
        }
    }
}