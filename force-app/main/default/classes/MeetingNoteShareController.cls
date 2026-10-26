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

    /* ================================
       DTOs pour construire l'email
       ================================ */

    public class EmailDataDTO {
        @AuraEnabled public Boolean isSalesPres;
        @AuraEnabled public String meetingNoteName;

        @AuraEnabled public List<PillDTO> clientPills;
        @AuraEnabled public List<PillDTO> internalPills;

        @AuraEnabled public List<InterestDTO> clientInterest;
        @AuraEnabled public List<TaskDTO> taskObjects;
    }

    public class PillDTO {
        @AuraEnabled public String label;
        public PillDTO() {}
        public PillDTO(String label) { this.label = label; }
    }

    public class InterestDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String pic;
        @AuraEnabled public Integer rating;
    }

    public class TaskDTO {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Subject;
        @AuraEnabled public String Description;
        @AuraEnabled public Date ActivityDate;
        @AuraEnabled public String OwnerLabel;
    }

    /* ==========================================
       Données email pour buildEmail
       ========================================== */

    @AuraEnabled(cacheable=true)
    public static EmailDataDTO getMeetingNoteEmailData(Id meetingNoteId) {
        if (meetingNoteId == null) return null;

        EmailDataDTO dto = new EmailDataDTO();
        dto.clientPills = new List<PillDTO>();
        dto.internalPills = new List<PillDTO>();
        dto.clientInterest = new List<InterestDTO>();
        dto.taskObjects = new List<TaskDTO>();

        // 1) Meeting Note
        Meeting_Note__c mn = [
            SELECT Id, Name, SalesPresentation__c
            FROM Meeting_Note__c
            WHERE Id = :meetingNoteId
            LIMIT 1
        ];
        dto.isSalesPres = mn.SalesPresentation__c;
        dto.meetingNoteName = mn.Name;

        // 2) Event lié à la Meeting Note
        Event evt = [
            SELECT Id
            FROM Event
            WHERE Meeting_Note__c = :meetingNoteId
            LIMIT 1
        ];

        // 3) Attendees via EventRelation (contacts uniquement)
        List<EventRelation> rels = [
            SELECT RelationId
            FROM EventRelation
            WHERE EventId = :evt.Id
        ];

        Set<Id> contactIds = new Set<Id>();
        for (EventRelation r : rels) {
            if (r.RelationId != null && r.RelationId.getSObjectType() == Contact.SObjectType) {
                contactIds.add(r.RelationId);
            }
        }

        if (!contactIds.isEmpty()) {
            for (Contact c : [
                SELECT Id, Name, Account.Name
                FROM Contact
                WHERE Id IN :contactIds
            ]) {
                if (c.Account != null && c.Account.Name == 'CARMIGNAC') {
                    dto.internalPills.add(new PillDTO(c.Name));
                } else {
                    dto.clientPills.add(new PillDTO(c.Name));
                }
            }
        }

        // 4) ClientInterest__c
        if (dto.isSalesPres) {
            for (ClientInterest__c ci : [
                SELECT Id, Interest__c, Strategy__r.Name
                FROM ClientInterest__c
                WHERE MeetingNote__c = :meetingNoteId
            ]) {
                InterestDTO idto = new InterestDTO();
                idto.label = (ci.Strategy__r != null) ? ci.Strategy__r.Name : '';
                idto.rating = (ci.Interest__c == null) ? 0 : Integer.valueOf(ci.Interest__c);

                if (idto.rating == 1) idto.pic = 'stars_100';
                else if (idto.rating == 2) idto.pic = 'stars_200';
                else if (idto.rating == 3) idto.pic = 'stars_300';
                else if (idto.rating == 4) idto.pic = 'stars_400';
                else if (idto.rating == 5) idto.pic = 'stars_500';
                else idto.pic = 'stars_000';

                dto.clientInterest.add(idto);
            }

            // 5) Tasks : WhatId = MeetingNote OR Meeting_Note__c = MeetingNote (Action Plans)
            for (Task t : [
                SELECT Id, Subject, ActivityDate, Owner.Name, Description__c
                FROM Task
                WHERE  (WhatId = :meetingNoteId Or Meeting_Note__c = :meetingNoteId) AND Description__c != null
            ]) {
                TaskDTO td = new TaskDTO();
                td.Id = t.Id;
                td.Subject = t.Subject;
                td.ActivityDate = t.ActivityDate;
                td.OwnerLabel = (t.Owner != null) ? t.Owner.Name : '';
                td.Description = t.Description__c;
                dto.taskObjects.add(td);
            }
        }

        return dto;
    }
}
