/**
* @author: Saad Lozzi
* @date : 19/04/2021
* @description : This apex batch verifies the accuracy
* of the last interaction dateTime in Account and the 
* Last Meeting & Call and Last Event Attendance in contact
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
*/
global class BATCH012_LastInteraction implements Database.Batchable<SObject>
{
    private static final String QUERY_LEAD = '' +
            'SELECT ' +
            '   Id, ' +
            '   CreatedDate, ' +
            '   Last_Interaction__c ' +
            ' FROM ' +
            '       Lead';

    private class DateType
    {
        Datetime lastDate;
        String type;
    }

    private class AccountInfos
    {
        String fullName;
        String corporateTitle;
        Datetime lastInteraction;
    }

    String query;

    public BATCH012_LastInteraction(String aQuery)
    {
        query = aQuery;
    }

    public Database.QueryLocator start(Database.BatchableContext BC)
    {
        Database.QueryLocator queryLocator = Database.getQueryLocator(query);

        return queryLocator;
    }

    public void execute(Database.BatchableContext BC, List<Contact> scope)
    {
        // Create a set of contact Ids
        Set<Id> contactIds = getSet(scope);

        // Meeting & Call max date
        Map<Id, DateType> contactToEventMaxDate = eventMaxDate(contactIds);

        // Meeting Link max date
        Map<Id, DateType> contactToMLMaxDate = meetingLinkMaxDate(contactIds);

        // Last Event Attendance max date
        Map<Id, DateType> contactToCampaignMaxDate = campaignMaxDate(contactIds);

        Map<Id, DateType> contactToNewsletterSent = newsletterSentMaxDate(contactIds);

        Map<Id, DateType> contactToNewsletterOpened = newsletterOpenedMaxDate(contactIds);

        List<Contact> contactsToUpdate = contactsToUpdate(scope,
                contactToEventMaxDate,
                contactToCampaignMaxDate,
                contactToMLMaxDate,
                contactToNewsletterSent,
                contactToNewsletterOpened); 

        Database.update(contactsToUpdate, false);
    }

    public void finish(Database.BatchableContext BC)
    {
        String query =  'SELECT '+
                            'Id, '+
                            'CreatedDate, '+
                            'Last_interaction_with_contact__c '+
                        'FROM '+
                            'Account '+
                        'WHERE '+
                            'Id NOT IN (SELECT AccountId FROM Contact)';

        BATCH014_UnrelatedAccsLastInteraction batch = new BATCH014_UnrelatedAccsLastInteraction(query);
        Database.executeBatch(batch);
    }

    // this method return contact Id => his last event and type
    private Map<Id, DateType> eventMaxDate(Set<Id> contactIds)
    {
        Map<Id, DateType> contactToEventMaxDate = new Map<Id, DateType>();
        // gets the events related to selected contacts
        List<Event> relatedEvents =
        [
                SELECT
                        Id,
                        CreatedDate,
                        EndDateTime,
                        WhatId,
                        WhoId,
                        Type
                FROM
                        Event
                WHERE
                        WhoId IN :contactIds
                ORDER BY
                        EndDateTime DESC
        ];
        // calculates the last event date
        for (Event aEvent : relatedEvents)
        {
            DateType dateType = new DateType();
            dateType.lastDate = aEvent.EndDateTime;
            dateType.type = aEvent.Type;

            if (!contactToEventMaxDate.containsKey(aEvent.WhoId))
            {
                contactToEventMaxDate.put(aEvent.WhoId, dateType);
            }
        }
        return contactToEventMaxDate;
    }

    // this method return contact Id => his last meeting Link
    private Map<Id, DateType> meetingLinkMaxDate(Set<Id> contactIds)
    {
        Map<Id, DateType> contactToMLMaxDate = new Map<Id, DateType>();
        // gets the events related to selected contacts
        List<Meeting_Link__c> relatedMeetingLinks =
        [
                SELECT
                        Id,
                        Date__c,
                        Contact__c,
                        CreatedDate
                FROM
                        Meeting_Link__c
                WHERE
                        Contact__c IN :contactIds
                ORDER BY
                        Date__c DESC
        ];

        // calculates the last event date
        for (Meeting_Link__c meetingLink : relatedMeetingLinks)
        {
            DateType dateType = new DateType();
            dateType.lastDate = meetingLink.Date__c;

            if (!contactToMLMaxDate.containsKey(meetingLink.Contact__c))
            {
                contactToMLMaxDate.put(meetingLink.Contact__c, dateType);
            }
        }
        return contactToMLMaxDate;
    }

    // this method return contact Id => Last Campaign where he attended
    private Map<Id, DateType> campaignMaxDate(Set<Id> contactIds)
    {
        Map<Id, DateType> contactToCampaignMaxDate = new Map<Id, DateType>();
        // gets all the campaignMembers related to the contacts
        List<CampaignMember> relatedCampaignMembers =
        [
                SELECT
                        Id,
                        ContactId,
                        CreatedDate,
                        Campaign.End_Date_Time__c,
                        Campaign.Type,
                        Status,
                        Type
                FROM
                        CampaignMember
                WHERE
                        ContactId IN :contactIds
                AND
                        Status = 'Attended'
                ORDER BY
                        Campaign.End_Date_Time__c DESC
        ];


        // calculates the last campaign date (where attended)
        for (CampaignMember aCampaignMember : relatedCampaignMembers)
        {
            DateType dateType = new DateType();
            dateType.lastDate = aCampaignMember.Campaign.End_Date_Time__c;
            dateType.type = aCampaignMember.Campaign.Type;

            if (!contactToCampaignMaxDate.containsKey(aCampaignMember.ContactId))
            {
                contactToCampaignMaxDate.put(aCampaignMember.ContactId, dateType);
            }
        }
        return contactToCampaignMaxDate;
    }

    // this method return contact Id => Last Newsletter received date
    private Map<Id, DateType> newsletterSentMaxDate(Set<Id> contactIds)
    {
        Map<Id, DateType> contactToNewsletterSent = new Map<Id, DateType>();
        // gets all the campaignMembers related to the contacts
        List<CampaignMember> relatedCampaignMembers =
        [
                SELECT
                        Id,
                        ContactId,
                        CreatedDate,
                        LastModifiedDate,
                        Campaign.End_Date_Time__c,
                        Campaign.Type,
                        Status,
                        Type
                FROM
                        CampaignMember
                WHERE
                    ContactId IN :contactIds
                AND
                    Status IN ('Sent', 'Clicked')
                AND
                    Campaign.RecordType.DeveloperName = 'Newsletters'
                ORDER BY
                    LastModifiedDate DESC
        ];


        // calculates the last newsletter sent
        for (CampaignMember aCampaignMember : relatedCampaignMembers)
        {
            DateType dateType = new DateType();
            dateType.lastDate = aCampaignMember.LastModifiedDate;
            dateType.type = aCampaignMember.Campaign.Type;

            if (!contactToNewsletterSent.containsKey(aCampaignMember.ContactId))
            {
                contactToNewsletterSent.put(aCampaignMember.ContactId, dateType);
            }
        }
        return contactToNewsletterSent;
    }

    // this method return contact Id => Last Newsletter received date
    private Map<Id, DateType> newsletterOpenedMaxDate(Set<Id> contactIds)
    {
        Map<Id, DateType> contactToNewsletterOpened = new Map<Id, DateType>();
        // gets all the campaignMembers related to the contacts
        List<CampaignMember> relatedCampaignMembers =
        [
                SELECT
                        Id,
                        ContactId,
                        CreatedDate,
                        LastModifiedDate,
                        Campaign.End_Date_Time__c,
                        Campaign.Type,
                        Status,
                        Type
                FROM
                        CampaignMember
                WHERE
                    ContactId IN :contactIds
                AND
                    Status = 'Opened'
                AND
                    Campaign.RecordType.DeveloperName = 'Newsletters'
                ORDER BY
                    LastModifiedDate DESC
        ];


        // calculates the last newsletter sent
        for (CampaignMember aCampaignMember : relatedCampaignMembers)
        {
            DateType dateType = new DateType();
            dateType.lastDate = aCampaignMember.LastModifiedDate;
            dateType.type = aCampaignMember.Campaign.Type;

            if (!contactToNewsletterOpened.containsKey(aCampaignMember.ContactId))
            {
                contactToNewsletterOpened.put(aCampaignMember.ContactId, dateType);
            }
        }
        return contactToNewsletterOpened;
    }


    private Set<Id> getSet(List<SObject> input)
    {
        Set<Id> output = new Set<Id>();

        for (SObject anObject : input)
        {
            output.add(anObject.Id);
        }

        return output;
    }

    private List<Contact> contactsToUpdate(List<Contact> contacts,
            Map<Id, DateType> contactToEventMaxDate,
            Map<Id, DateType> contactToCampaignMaxDate,
            Map<Id, DateType> contactToMLMaxDate,
            Map<Id, DateType> contactToNewsletterSent,
            Map<Id, DateType> contactToNewsletterOpened
    )
    {
        List<Contact> contactsToUpdate = new List<Contact>();

        for (Contact aContact : contacts)
        {
            Boolean toAdd = false;

            if (aContact.Last_Meeting_Call__c != contactToMLMaxDate.get(aContact.Id)?.lastDate || aContact.Last_Meeting_Call__c == null)
            {
                aContact.Last_Meeting_Call__c = contactToMLMaxDate.get(aContact.Id)?.lastDate;
                toAdd = true;
            }

            System.debug('SLI > ' +  aContact.Last_Meeting_Call__c);
            System.debug('SLI > ' +  contactToEventMaxDate);
            System.debug('SLI > ' +  contactToEventMaxDate.get(aContact.Id)?.lastDate);

            if (aContact.Last_Meeting_Call__c < contactToEventMaxDate.get(aContact.Id)?.lastDate || aContact.Last_Meeting_Call__c == null)
            {
                aContact.Last_Meeting_Call__c = contactToEventMaxDate.get(aContact.Id)?.lastDate;
                aContact.Last_Meeting_Call_type__c = contactToEventMaxDate.get(aContact.Id)?.type;
                toAdd = true;
            }

            if (aContact.Last_Event_attendance__c != contactToCampaignMaxDate.get(aContact.Id)?.lastDate || aContact.Last_Event_attendance__c == null)
            {
                aContact.Last_Event_attendance__c = contactToCampaignMaxDate.get(aContact.Id)?.lastDate;
                aContact.Last_Event_attendance_Type__c = contactToCampaignMaxDate.get(aContact.Id)?.type;
                toAdd = true;
            }

            if (aContact.Last_Newsletter_sent__c != contactToNewsletterSent.get(aContact.Id)?.lastDate || aContact.Last_Newsletter_sent__c == null)
            {
                aContact.Last_Newsletter_sent__c = contactToNewsletterSent.get(aContact.Id)?.lastDate;
                aContact.Last_Newsletter_Sent_Type__c = contactToNewsletterSent.get(aContact.Id)?.type;
                toAdd = true;
            }

            if (aContact.Last_Newsletter_Opened__c != contactToNewsletterOpened.get(aContact.Id)?.lastDate || aContact.Last_Newsletter_Opened__c == null)
            {
                aContact.Last_Newsletter_Opened__c = contactToNewsletterOpened.get(aContact.Id)?.lastDate;
                toAdd = true;
            }

            if(aContact.Last_Meeting_Call__c > System.now())
            {
                aContact.Last_Meeting_Call__c = System.now();
            }
            if(aContact.Last_Event_attendance__c > System.now())
            {
                aContact.Last_Event_attendance__c = System.now();
            }
            if (toAdd)contactsToUpdate.add(aContact);
        }
        return contactsToUpdate;
    }
}