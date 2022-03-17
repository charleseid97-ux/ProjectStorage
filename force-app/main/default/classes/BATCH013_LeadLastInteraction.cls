/**
 * Created by Saad LOZZI on 24/08/2021.
 */

global with sharing class BATCH013_LeadLastInteraction implements Database.Batchable<SObject>, Schedulable
{
    private static final String QUERY_LEAD = '' +
            'SELECT ' +
            '   Id, ' +
            '   CreatedDate, ' +
            '   Last_Interaction__c ' +
            ' FROM ' +
            '       Lead';

    String query;

    private class DateType
    {
        Datetime lastDate;
        String type;
    }

    public BATCH013_LeadLastInteraction()
    {
        query = QUERY_LEAD;
    }

    public BATCH013_LeadLastInteraction(String aQuery)
    {
        query = aQuery;
    }

    global void execute(SchedulableContext SC)
    {
        BATCH013_LeadLastInteraction batch = new BATCH013_LeadLastInteraction(QUERY_LEAD);
        Database.executeBatch(batch);
    }

    public Database.QueryLocator start(Database.BatchableContext BC)
    {
        Database.QueryLocator queryLocator = Database.getQueryLocator(query);

        return queryLocator;
    }

    public void execute(Database.BatchableContext BC, List<Lead> scope)
    {
        Set<Id> leadIds = getSet(scope);

        Map<Id, DateType> contactToEventMaxDate = eventMaxDate(leadIds);
        // Last Event Attendance max date
        Map<Id, DateType> leadToCampaignMaxDate = campaignMaxDate(leadIds);

        List<Lead> leadsToUpdate = leadsToUpdate(scope,
                contactToEventMaxDate,
                leadToCampaignMaxDate
        );

        Database.update(leadsToUpdate, false);
    }

    public void finish(Database.BatchableContext BC) {}

    private Map<Id, DateType> eventMaxDate(Set<Id> leadIds)
    {
        Map<Id, DateType> leadToEventMaxDate = new Map<Id, DateType>();
        // Gets Events related to selected Leads
        List<Event> relatedEvents =
        [
                SELECT
                        Id,
                        EndDateTime,
                        WhatId,
                        WhoId,
                        Type
                FROM
                        Event
                WHERE
                        WhoId IN :leadIds
                ORDER BY
                        EndDateTime DESC
        ];
        // Calculates last Event date
        for (Event aEvent : relatedEvents)
        {
            DateType dateType = new DateType();
            dateType.lastDate = aEvent.EndDateTime;
            dateType.type = aEvent.Type;

            if (!leadToEventMaxDate.containsKey(aEvent.WhoId))
            {
                leadToEventMaxDate.put(aEvent.WhoId, dateType);
            }
        }
        return leadToEventMaxDate;
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

    // this method return contact Id => Last Campaign where he attended
    private Map<Id, DateType> campaignMaxDate(Set<Id> leadIds)
    {
        Map<Id, DateType> leadToCampaignMaxDate = new Map<Id, DateType>();
        // gets all the campaignMembers related to the contacts
        List<CampaignMember> relatedCampaignMembers =
        [
                SELECT
                        Id,
                        LeadId,
                        ContactId,
                        Campaign.End_Date_Time__c,
                        Campaign.Type,
                        Status,
                        Type
                FROM
                        CampaignMember
                WHERE
                    LeadId IN :leadIds
                AND
                    Status IN ('Attended', 'Clicked', 'Opened')
                ORDER BY
                    Campaign.End_Date_Time__c DESC
        ];


        // calculates the last campaign date (where attended)
        for (CampaignMember aCampaignMember : relatedCampaignMembers)
        {
            DateType dateType = new DateType();
            dateType.lastDate = aCampaignMember.Campaign.End_Date_Time__c;
            dateType.type = aCampaignMember.Campaign.Type;

            if (!leadToCampaignMaxDate.containsKey(aCampaignMember.LeadId))
            {
                leadToCampaignMaxDate.put(aCampaignMember.LeadId, dateType);
            }
        }
        return leadToCampaignMaxDate;
    }

    private List<Lead> leadsToUpdate(List<Lead> leads,
            Map<Id, DateType> leadToEventMaxDate,
            Map<Id, DateType> leadToCampaignMaxDate
    )
    {
        List<Lead> leadsToUpdate = new List<Lead>();

        for (Lead aLead : leads)
        {
            Boolean toAdd = false;

            if (aLead.Last_Interaction__c < aLead.CreatedDate
                    || aLead.Last_Interaction__c == null)
            {
                aLead.Last_Interaction__c = aLead.CreatedDate;
                toAdd = true;
            }
            if (aLead.Last_Interaction__c < leadToEventMaxDate.get(aLead.Id)?.lastDate)
            {
                aLead.Last_Interaction__c = leadToEventMaxDate.get(aLead.Id)?.lastDate;
                toAdd = true;
            }

            if (aLead.Last_Interaction__c < leadToCampaignMaxDate.get(aLead.Id)?.lastDate)
            {
                aLead.Last_Interaction__c = leadToCampaignMaxDate.get(aLead.Id)?.lastDate;
                toAdd = true;
            }
            if(aLead.Last_Interaction__c > System.now())
            {
                aLead.Last_Interaction__c = System.now();
            }
            if (toAdd)leadsToUpdate.add(aLead);
        }
        return leadsToUpdate;
    }
}