public with sharing class CampaignCloseKpiService {

    private static final String STATUS_INVITED = 'Invited';
    private static final String STATUS_CONFIRMED = 'Confirmed';
    private static final String STATUS_DECLINED = 'Declined';
    private static final String STATUS_ATTENDED = 'Attended';
    private static final String STATUS_NO_SHOW = 'No Show';
    private static final String STATUS_CANCELLED = 'Cancelled';

    private static final String FIELD_INITIALLY_INVITED = 'Initially_invited__c';
    private static final String FIELD_INITIALLY_REGISTERED = 'Initially_registered__c';
    private static final String FIELD_ATTENDED_COUNT = 'Attended_Count__c';
    private static final String FIELD_CANCELLED_COUNT = 'Cancelled_Count__c';
    private static final String FIELD_NO_SHOW_COUNT = 'NoShow_Count__c';

    private static final Set<String> INITIAL_INVITED_STATUSES = new Set<String>{
        STATUS_INVITED,
        STATUS_CONFIRMED,
        STATUS_DECLINED,
        STATUS_ATTENDED,
        STATUS_NO_SHOW,
        STATUS_CANCELLED
    };

    private static final Set<String> INITIAL_REGISTERED_STATUSES = new Set<String>{
        STATUS_CONFIRMED,
        STATUS_ATTENDED,
        STATUS_NO_SHOW,
        STATUS_CANCELLED
    };

    public static Map<Id, Campaign> buildCampaignUpdates(Set<Id> campaignIds) {
        Map<Id, Campaign> campaignsToUpdate = initCampaignMap(campaignIds);

        if (campaignsToUpdate.isEmpty()) {
            return campaignsToUpdate;
        }

        calculateInitiallyInvited(campaignsToUpdate);
        calculateInitiallyRegistered(campaignsToUpdate);
        calculateAttended(campaignsToUpdate);
        calculateCancelled(campaignsToUpdate);
        calculateNoShow(campaignsToUpdate);
        calculateUltimateParentsAttended(campaignsToUpdate);
        calculateNewPersonAttendees3M(campaignsToUpdate);
        calculateAttendeesInvestedCount(campaignsToUpdate);
        calculateAttendeesLoyaltyRate(campaignsToUpdate);
        calculateAttendeesOpenOpportunitiesAmount(campaignsToUpdate);

        return campaignsToUpdate;
    }

    private static Map<Id, Campaign> initCampaignMap(Set<Id> campaignIds) {
        Map<Id, Campaign> result = new Map<Id, Campaign>();

        if (campaignIds == null || campaignIds.isEmpty()) {
            return result;
        }

        for (Id campaignId : campaignIds) {
            result.put(campaignId, new Campaign(Id = campaignId));
        }

        return result;
    }

    private static void calculateInitiallyInvited(Map<Id, Campaign> campaignsToUpdate) {
        aggregateAndAssign(campaignsToUpdate, INITIAL_INVITED_STATUSES, FIELD_INITIALLY_INVITED);
    }

    private static void calculateInitiallyRegistered(Map<Id, Campaign> campaignsToUpdate) {
        aggregateAndAssign(campaignsToUpdate, INITIAL_REGISTERED_STATUSES, FIELD_INITIALLY_REGISTERED);
    }

    private static void calculateAttended(Map<Id, Campaign> campaignsToUpdate) {
        aggregateAndAssign(campaignsToUpdate, new Set<String>{ STATUS_ATTENDED }, FIELD_ATTENDED_COUNT);
    }

    private static void calculateCancelled(Map<Id, Campaign> campaignsToUpdate) {
        aggregateAndAssign(campaignsToUpdate, new Set<String>{ STATUS_CANCELLED }, FIELD_CANCELLED_COUNT);
    }

    private static void calculateNoShow(Map<Id, Campaign> campaignsToUpdate) {
        aggregateAndAssign(campaignsToUpdate, new Set<String>{ STATUS_NO_SHOW }, FIELD_NO_SHOW_COUNT);
    }

    private static void calculateUltimateParentsAttended(Map<Id, Campaign> campaignsToUpdate) {
        Set<Id> campaignIds = campaignsToUpdate.keySet();
        Map<Id, Set<Id>> contactIdsByCampaign = new Map<Id, Set<Id>>();
        Set<Id> allContactIds = new Set<Id>();

        for (CampaignMember cm : [
            SELECT CampaignId, ContactId
            FROM CampaignMember
            WHERE CampaignId IN :campaignIds
              AND Status = :STATUS_ATTENDED
              AND ContactId != null
        ]) {
            if (!contactIdsByCampaign.containsKey(cm.CampaignId)) {
                contactIdsByCampaign.put(cm.CampaignId, new Set<Id>());
            }

            contactIdsByCampaign.get(cm.CampaignId).add(cm.ContactId);
            allContactIds.add(cm.ContactId);
        }

        Map<Id, String> ultimateParentByContactId = new Map<Id, String>();

        if (!allContactIds.isEmpty()) {
            for (Contact c : [
                SELECT Id, Account.Ultimate_Parent_ID__c
                FROM Contact
                WHERE Id IN :allContactIds
            ]) {
                if (c.Account != null && String.isNotBlank(c.Account.Ultimate_Parent_ID__c)) {
                    ultimateParentByContactId.put(c.Id, c.Account.Ultimate_Parent_ID__c);
                }
            }
        }

        for (Id campaignId : campaignIds) {
            Set<String> distinctUltimateParents = new Set<String>();

            if (contactIdsByCampaign.containsKey(campaignId)) {
                for (Id contactId : contactIdsByCampaign.get(campaignId)) {
                    if (ultimateParentByContactId.containsKey(contactId)) {
                        distinctUltimateParents.add(ultimateParentByContactId.get(contactId));
                    }
                }
            }

            campaignsToUpdate.get(campaignId).Ultimate_Parents_Attended__c =
                distinctUltimateParents.size();
        }
    }

    private static void calculateNewPersonAttendees3M(Map<Id, Campaign> campaignsToUpdate) {
        Set<Id> campaignIds = campaignsToUpdate.keySet();

        if (campaignIds.isEmpty()) {
            return;
        }

        Map<Id, Campaign> sourceCampaigns = new Map<Id, Campaign>([
            SELECT Id, Start_Date_Time__c
            FROM Campaign
            WHERE Id IN :campaignIds
        ]);

        List<CampaignMember> attendedMembers = [
            SELECT Id, CampaignId, ContactId, LeadId
            FROM CampaignMember
            WHERE CampaignId IN :campaignIds
              AND Status = :STATUS_ATTENDED
              AND (ContactId != null OR LeadId != null)
        ];

        Set<Id> contactIds = new Set<Id>();
        Set<Id> leadIds = new Set<Id>();

        for (CampaignMember cm : attendedMembers) {
            if (cm.ContactId != null) {
                contactIds.add(cm.ContactId);
            }
            if (cm.LeadId != null) {
                leadIds.add(cm.LeadId);
            }
        }

        Map<Id, Contact> contactsById = contactIds.isEmpty()
            ? new Map<Id, Contact>()
            : new Map<Id, Contact>([
                SELECT Id, CreatedDate
                FROM Contact
                WHERE Id IN :contactIds
            ]);

        Map<Id, Lead> leadsById = leadIds.isEmpty()
            ? new Map<Id, Lead>()
            : new Map<Id, Lead>([
                SELECT Id, CreatedDate
                FROM Lead
                WHERE Id IN :leadIds
            ]);

        Map<Id, Set<String>> distinctNewPersonsByCampaign = new Map<Id, Set<String>>();

        for (CampaignMember cm : attendedMembers) {
            Campaign sourceCampaign = sourceCampaigns.get(cm.CampaignId);

            if (sourceCampaign == null || sourceCampaign.Start_Date_Time__c == null) {
                continue;
            }

            Datetime lowerBound = sourceCampaign.Start_Date_Time__c.addMonths(-3);

            Boolean isNewPerson = false;
            String distinctPersonKey = null;

            if (cm.ContactId != null && contactsById.containsKey(cm.ContactId)) {
                Contact c = contactsById.get(cm.ContactId);
                if (c.CreatedDate >= lowerBound) {
                    isNewPerson = true;
                    distinctPersonKey = 'C_' + String.valueOf(cm.ContactId);
                }
            } else if (cm.LeadId != null && leadsById.containsKey(cm.LeadId)) {
                Lead l = leadsById.get(cm.LeadId);
                if (l.CreatedDate >= lowerBound) {
                    isNewPerson = true;
                    distinctPersonKey = 'L_' + String.valueOf(cm.LeadId);
                }
            }

            if (isNewPerson && distinctPersonKey != null) {
                if (!distinctNewPersonsByCampaign.containsKey(cm.CampaignId)) {
                    distinctNewPersonsByCampaign.put(cm.CampaignId, new Set<String>());
                }

                distinctNewPersonsByCampaign.get(cm.CampaignId).add(distinctPersonKey);
            }
        }

        for (Id campaignId : campaignIds) {
            Integer value = distinctNewPersonsByCampaign.containsKey(campaignId)
                ? distinctNewPersonsByCampaign.get(campaignId).size()
                : 0;

            campaignsToUpdate.get(campaignId).New_Person_Attendees_3M__c = value;
        }
    }

    private static void calculateAttendeesInvestedCount(Map<Id, Campaign> campaignsToUpdate) {
        Set<Id> campaignIds = campaignsToUpdate.keySet();

        Map<Id, Set<Id>> investedContactIdsByCampaign = new Map<Id, Set<Id>>();

        for (CampaignMember cm : [
            SELECT CampaignId, ContactId
            FROM CampaignMember
            WHERE CampaignId IN :campaignIds
              AND Status = :STATUS_ATTENDED
              AND ContactId != null
              AND Contact.Invested__c = true
        ]) {
            if (!investedContactIdsByCampaign.containsKey(cm.CampaignId)) {
                investedContactIdsByCampaign.put(cm.CampaignId, new Set<Id>());
            }

            investedContactIdsByCampaign.get(cm.CampaignId).add(cm.ContactId);
        }

        for (Id campaignId : campaignIds) {
            Integer value = investedContactIdsByCampaign.containsKey(campaignId)
                ? investedContactIdsByCampaign.get(campaignId).size()
                : 0;

            campaignsToUpdate.get(campaignId).Attendees_Invested_Count__c = value;
        }
    }

    private static void calculateAttendeesLoyaltyRate(Map<Id, Campaign> campaignsToUpdate) {
        Set<Id> campaignIds = campaignsToUpdate.keySet();

        if (campaignIds.isEmpty()) {
            return;
        }

        Map<Id, Set<Id>> contactIdsByCampaign = new Map<Id, Set<Id>>();
        Map<Id, Set<Id>> leadIdsByCampaign = new Map<Id, Set<Id>>();
        Set<Id> allContactIds = new Set<Id>();
        Set<Id> allLeadIds = new Set<Id>();

        for (CampaignMember cm : [
            SELECT CampaignId, ContactId, LeadId
            FROM CampaignMember
            WHERE CampaignId IN :campaignIds
              AND Status = :STATUS_ATTENDED
              AND (ContactId != null OR LeadId != null)
        ]) {
            if (cm.ContactId != null) {
                if (!contactIdsByCampaign.containsKey(cm.CampaignId)) {
                    contactIdsByCampaign.put(cm.CampaignId, new Set<Id>());
                }
                contactIdsByCampaign.get(cm.CampaignId).add(cm.ContactId);
                allContactIds.add(cm.ContactId);
            }

            if (cm.LeadId != null) {
                if (!leadIdsByCampaign.containsKey(cm.CampaignId)) {
                    leadIdsByCampaign.put(cm.CampaignId, new Set<Id>());
                }
                leadIdsByCampaign.get(cm.CampaignId).add(cm.LeadId);
                allLeadIds.add(cm.LeadId);
            }
        }

        Map<Id, Decimal> loyaltyByContactId = new Map<Id, Decimal>();
        if (!allContactIds.isEmpty()) {
            for (Contact c : [
                SELECT Id, Loyalty_Score_24M__c
                FROM Contact
                WHERE Id IN :allContactIds
            ]) {
                if (c.Loyalty_Score_24M__c != null) {
                    loyaltyByContactId.put(c.Id, c.Loyalty_Score_24M__c);
                }
            }
        }

        Map<Id, Decimal> loyaltyByLeadId = new Map<Id, Decimal>();
        if (!allLeadIds.isEmpty()) {
            for (Lead l : [
                SELECT Id, Loyalty_Score_24M__c
                FROM Lead
                WHERE Id IN :allLeadIds
            ]) {
                if (l.Loyalty_Score_24M__c != null) {
                    loyaltyByLeadId.put(l.Id, l.Loyalty_Score_24M__c);
                }
            }
        }

        for (Id campaignId : campaignIds) {
            Decimal totalScore = 0;
            Integer scoredAttendeesCount = 0;

            if (contactIdsByCampaign.containsKey(campaignId)) {
                for (Id contactId : contactIdsByCampaign.get(campaignId)) {
                    if (loyaltyByContactId.containsKey(contactId)) {
                        totalScore += loyaltyByContactId.get(contactId);
                        scoredAttendeesCount++;
                    }
                }
            }

            if (leadIdsByCampaign.containsKey(campaignId)) {
                for (Id leadId : leadIdsByCampaign.get(campaignId)) {
                    if (loyaltyByLeadId.containsKey(leadId)) {
                        totalScore += loyaltyByLeadId.get(leadId);
                        scoredAttendeesCount++;
                    }
                }
            }

            campaignsToUpdate.get(campaignId).Attendees_Loyalty_Rate__c =
                scoredAttendeesCount > 0
                    ? (totalScore / scoredAttendeesCount) / 100
                    : null;
        }
    }

    private static void calculateAttendeesOpenOpportunitiesAmount(Map<Id, Campaign> campaignsToUpdate) {
        Set<Id> campaignIds = campaignsToUpdate.keySet();
        Map<Id, Set<Id>> accountIdsByCampaign = new Map<Id, Set<Id>>();

        for (CampaignMember cm : [
            SELECT CampaignId, Contact.AccountId
            FROM CampaignMember
            WHERE CampaignId IN :campaignIds
              AND Status = :STATUS_ATTENDED
              AND ContactId != null
              AND Contact.AccountId != null
        ]) {
            if (!accountIdsByCampaign.containsKey(cm.CampaignId)) {
                accountIdsByCampaign.put(cm.CampaignId, new Set<Id>());
            }

            accountIdsByCampaign.get(cm.CampaignId).add(cm.Contact.AccountId);
        }

        Set<Id> allAccountIds = new Set<Id>();
        for (Set<Id> accountIds : accountIdsByCampaign.values()) {
            allAccountIds.addAll(accountIds);
        }

        Map<Id, Decimal> openOppAmountByAccount = new Map<Id, Decimal>();

        if (!allAccountIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT AccountId accountId, SUM(Amount) total
                FROM Opportunity
                WHERE AccountId IN :allAccountIds
                  AND IsClosed = false
                GROUP BY AccountId
            ]) {
                Decimal totalAmount = (Decimal) ar.get('total');

                openOppAmountByAccount.put(
                    (Id) ar.get('accountId'),
                    totalAmount == null ? 0 : totalAmount
                );
            }
        }

        for (Id campaignId : campaignIds) {
            Decimal total = 0;

            if (accountIdsByCampaign.containsKey(campaignId)) {
                for (Id accountId : accountIdsByCampaign.get(campaignId)) {
                    Decimal amount = openOppAmountByAccount.get(accountId);

                    if (amount != null) {
                        total += amount;
                    }
                }
            }

            campaignsToUpdate.get(campaignId).Attendees_Open_Opportunities_Amount__c = total;
        }
    }

    private static void aggregateAndAssign(
        Map<Id, Campaign> campaignsToUpdate,
        Set<String> statuses,
        String fieldName
    ) {
        Set<Id> campaignIds = campaignsToUpdate.keySet();
        Map<Id, Integer> countsByCampaign = new Map<Id, Integer>();

        for (AggregateResult ar : [
            SELECT CampaignId campaignId, COUNT(Id) total
            FROM CampaignMember
            WHERE CampaignId IN :campaignIds
              AND Status IN :statuses
            GROUP BY CampaignId
        ]) {
            countsByCampaign.put(
                (Id) ar.get('campaignId'),
                (Integer) ar.get('total')
            );
        }

        for (Id campaignId : campaignIds) {
            Integer value = countsByCampaign.containsKey(campaignId)
                ? countsByCampaign.get(campaignId)
                : 0;

            campaignsToUpdate.get(campaignId).put(fieldName, value);
        }
    }
}