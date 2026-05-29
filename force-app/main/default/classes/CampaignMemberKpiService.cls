public with sharing class CampaignMemberKpiService {

    private static final String EVENT_RECORDTYPE_DEVELOPER_NAME = 'Event_and_Meeting';
    private static final String NEWSLETTER_RECORDTYPE_DEVELOPER_NAME = 'Newsletters';

    private static final Set<String> EVENT_INVITED_STATUSES = new Set<String>{
        'Invited',
        'Confirmed',
        'Declined',
        'Attended',
        'No Show',
        'Cancelled'
    };

    private static final Set<String> NEWSLETTER_RECEIVED_STATUSES = new Set<String>{
        'Ready to be Sent',
        'Opened',
        'Clicked'
    };

    public static void recalculateContacts(Set<Id> contactIds) {
        if (contactIds == null || contactIds.isEmpty()) {
            return;
        }

        Id eventRecordTypeId = getCampaignRecordTypeId(EVENT_RECORDTYPE_DEVELOPER_NAME);
        Id newsletterRecordTypeId = getCampaignRecordTypeId(NEWSLETTER_RECORDTYPE_DEVELOPER_NAME);
        Datetime threshold = System.now().addMonths(-24);

        Map<Id, Integer> participatedCountByContactId = new Map<Id, Integer>();
        Map<Id, Integer> invitedCountByContactId = new Map<Id, Integer>();
        Map<Id, Integer> newsletterReceivedCountByContactId = new Map<Id, Integer>();
        Map<Id, Integer> newsletterClickedCountByContactId = new Map<Id, Integer>();

        if (eventRecordTypeId != null) {
            for (AggregateResult ar : [
                SELECT ContactId contactId, COUNT_DISTINCT(CampaignId) total
                FROM CampaignMember
                WHERE ContactId IN :contactIds
                  AND Status = 'Attended'
                  AND Campaign.RecordTypeId = :eventRecordTypeId
                  AND Campaign.Start_Date_Time__c >= :threshold
                GROUP BY ContactId
            ]) {
                participatedCountByContactId.put(
                    (Id) ar.get('contactId'),
                    (Integer) ar.get('total')
                );
            }

            for (AggregateResult ar : [
                SELECT ContactId contactId, COUNT_DISTINCT(CampaignId) total
                FROM CampaignMember
                WHERE ContactId IN :contactIds
                  AND Status IN :EVENT_INVITED_STATUSES
                  AND Campaign.RecordTypeId = :eventRecordTypeId
                  AND Campaign.Start_Date_Time__c >= :threshold
                GROUP BY ContactId
            ]) {
                invitedCountByContactId.put(
                    (Id) ar.get('contactId'),
                    (Integer) ar.get('total')
                );
            }
        }

        if (newsletterRecordTypeId != null) {
            for (AggregateResult ar : [
                SELECT ContactId contactId, COUNT_DISTINCT(CampaignId) total
                FROM CampaignMember
                WHERE ContactId IN :contactIds
                  AND Status IN :NEWSLETTER_RECEIVED_STATUSES
                  AND Campaign.RecordTypeId = :newsletterRecordTypeId
                  AND Campaign.Start_Date_Time__c >= :threshold
                GROUP BY ContactId
            ]) {
                newsletterReceivedCountByContactId.put(
                    (Id) ar.get('contactId'),
                    (Integer) ar.get('total')
                );
            }

            for (AggregateResult ar : [
                SELECT ContactId contactId, COUNT_DISTINCT(CampaignId) total
                FROM CampaignMember
                WHERE ContactId IN :contactIds
                  AND Status = 'Clicked'
                  AND Campaign.RecordTypeId = :newsletterRecordTypeId
                  AND Campaign.Start_Date_Time__c >= :threshold
                GROUP BY ContactId
            ]) {
                newsletterClickedCountByContactId.put(
                    (Id) ar.get('contactId'),
                    (Integer) ar.get('total')
                );
            }
        }

        List<Contact> contactsToUpdate = new List<Contact>();

        for (Id contactId : contactIds) {
            contactsToUpdate.add(new Contact(
                Id = contactId,
                E_participated_24M__c = participatedCountByContactId.containsKey(contactId)
                    ? participatedCountByContactId.get(contactId)
                    : 0,
                E_invited_24M__c = invitedCountByContactId.containsKey(contactId)
                    ? invitedCountByContactId.get(contactId)
                    : 0,
                N_received_24M__c = newsletterReceivedCountByContactId.containsKey(contactId)
                    ? newsletterReceivedCountByContactId.get(contactId)
                    : 0,
                N_clicked_24M__c = newsletterClickedCountByContactId.containsKey(contactId)
                    ? newsletterClickedCountByContactId.get(contactId)
                    : 0
            ));
        }

        if (!contactsToUpdate.isEmpty()) {
            Database.update(contactsToUpdate, false);
        }
    }

    public static void recalculateLeads(Set<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return;
        }

        Id eventRecordTypeId = getCampaignRecordTypeId(EVENT_RECORDTYPE_DEVELOPER_NAME);
        Id newsletterRecordTypeId = getCampaignRecordTypeId(NEWSLETTER_RECORDTYPE_DEVELOPER_NAME);
        Datetime threshold = System.now().addMonths(-24);

        Map<Id, Integer> participatedCountByLeadId = new Map<Id, Integer>();
        Map<Id, Integer> invitedCountByLeadId = new Map<Id, Integer>();
        Map<Id, Integer> newsletterReceivedCountByLeadId = new Map<Id, Integer>();
        Map<Id, Integer> newsletterClickedCountByLeadId = new Map<Id, Integer>();

        if (eventRecordTypeId != null) {
            for (AggregateResult ar : [
                SELECT LeadId leadId, COUNT_DISTINCT(CampaignId) total
                FROM CampaignMember
                WHERE LeadId IN :leadIds
                  AND Status = 'Attended'
                  AND Campaign.RecordTypeId = :eventRecordTypeId
                  AND Campaign.Start_Date_Time__c >= :threshold
                GROUP BY LeadId
            ]) {
                participatedCountByLeadId.put(
                    (Id) ar.get('leadId'),
                    (Integer) ar.get('total')
                );
            }

            for (AggregateResult ar : [
                SELECT LeadId leadId, COUNT_DISTINCT(CampaignId) total
                FROM CampaignMember
                WHERE LeadId IN :leadIds
                  AND Status IN :EVENT_INVITED_STATUSES
                  AND Campaign.RecordTypeId = :eventRecordTypeId
                  AND Campaign.Start_Date_Time__c >= :threshold
                GROUP BY LeadId
            ]) {
                invitedCountByLeadId.put(
                    (Id) ar.get('leadId'),
                    (Integer) ar.get('total')
                );
            }
        }

        if (newsletterRecordTypeId != null) {
            for (AggregateResult ar : [
                SELECT LeadId leadId, COUNT_DISTINCT(CampaignId) total
                FROM CampaignMember
                WHERE LeadId IN :leadIds
                  AND Status IN :NEWSLETTER_RECEIVED_STATUSES
                  AND Campaign.RecordTypeId = :newsletterRecordTypeId
                  AND Campaign.Start_Date_Time__c >= :threshold
                GROUP BY LeadId
            ]) {
                newsletterReceivedCountByLeadId.put(
                    (Id) ar.get('leadId'),
                    (Integer) ar.get('total')
                );
            }

            for (AggregateResult ar : [
                SELECT LeadId leadId, COUNT_DISTINCT(CampaignId) total
                FROM CampaignMember
                WHERE LeadId IN :leadIds
                  AND Status = 'Clicked'
                  AND Campaign.RecordTypeId = :newsletterRecordTypeId
                  AND Campaign.Start_Date_Time__c >= :threshold
                GROUP BY LeadId
            ]) {
                newsletterClickedCountByLeadId.put(
                    (Id) ar.get('leadId'),
                    (Integer) ar.get('total')
                );
            }
        }

        List<Lead> leadsToUpdate = new List<Lead>();

        for (Id leadId : leadIds) {
            leadsToUpdate.add(new Lead(
                Id = leadId,
                E_participated_24M__c = participatedCountByLeadId.containsKey(leadId)
                    ? participatedCountByLeadId.get(leadId)
                    : 0,
                E_invited_24M__c = invitedCountByLeadId.containsKey(leadId)
                    ? invitedCountByLeadId.get(leadId)
                    : 0,
                N_received_24M__c = newsletterReceivedCountByLeadId.containsKey(leadId)
                    ? newsletterReceivedCountByLeadId.get(leadId)
                    : 0,
                N_clicked_24M__c = newsletterClickedCountByLeadId.containsKey(leadId)
                    ? newsletterClickedCountByLeadId.get(leadId)
                    : 0
            ));
        }

        if (!leadsToUpdate.isEmpty()) {
            Database.update(leadsToUpdate, false);
        }
    }

    private static Id getCampaignRecordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> rtByDevName =
            Schema.SObjectType.Campaign.getRecordTypeInfosByDeveloperName();

        if (rtByDevName != null && rtByDevName.containsKey(developerName)) {
            return rtByDevName.get(developerName).getRecordTypeId();
        }

        return null;
    }
}