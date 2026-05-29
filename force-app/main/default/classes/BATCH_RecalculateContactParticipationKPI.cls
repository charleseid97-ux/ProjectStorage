public with sharing class BATCH_RecalculateContactParticipationKPI
    implements Database.Batchable<SObject> {

    private static final String EVENT_RECORDTYPE_DEVELOPER_NAME = 'Event_and_Meeting';
    private static final String NEWSLETTER_RECORDTYPE_DEVELOPER_NAME = 'Newsletters';

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Id eventRecordTypeId = getCampaignRecordTypeId(EVENT_RECORDTYPE_DEVELOPER_NAME);
        Id newsletterRecordTypeId = getCampaignRecordTypeId(NEWSLETTER_RECORDTYPE_DEVELOPER_NAME);
        Datetime threshold = System.now().addMonths(-24);

        List<Id> recordTypeIds = new List<Id>();
        if (eventRecordTypeId != null) {
            recordTypeIds.add(eventRecordTypeId);
        }
        if (newsletterRecordTypeId != null) {
            recordTypeIds.add(newsletterRecordTypeId);
        }

        if (recordTypeIds.isEmpty()) {
            return Database.getQueryLocator([
                SELECT Id
                FROM Contact
                WHERE Id = null
            ]);
        }

        return Database.getQueryLocator([
            SELECT Id
            FROM Contact
            WHERE Id IN (
                SELECT ContactId
                FROM CampaignMember
                WHERE ContactId != null
                  AND Campaign.RecordTypeId IN :recordTypeIds
                  AND Campaign.Start_Date_Time__c >= :threshold
            )
           
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Contact> scope) {
        Set<Id> contactIds = new Set<Id>();

        for (Contact c : scope) {
            contactIds.add(c.Id);
        }

        CampaignMemberKpiService.recalculateContacts(contactIds);
    }

    public void finish(Database.BatchableContext bc) {
        Database.executeBatch(new BATCH_RecalculateLeadParticipationKPI(), 200);
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