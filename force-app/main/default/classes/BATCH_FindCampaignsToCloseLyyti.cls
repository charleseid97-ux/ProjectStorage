public with sharing class BATCH_FindCampaignsToCloseLyyti implements Database.Batchable<SObject>, Database.Stateful {

    private Set<Id> campaignIdsToClose = new Set<Id>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String todayStr = formatDate(Date.today());

        return Database.getQueryLocator([
            SELECT Id, Name, Event_Local_End_Time__c, Status
            FROM Campaign
            WHERE Status != 'Closed'
              AND LyytiId__c != null
              AND Event_Local_End_Time__c LIKE :todayStr + '%'
            ORDER BY Event_Local_End_Time__c ASC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Campaign> campaigns) {
        String todayStr = formatDate(Date.today());

        for (Campaign campaign : campaigns) {
            if (String.isBlank(campaign.Event_Local_End_Time__c)) {
                continue;
            }

            String campaignDateStr = campaign.Event_Local_End_Time__c.substringBefore(' ');

            if (campaignDateStr == todayStr) {
                campaignIdsToClose.add(campaign.Id);
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (!campaignIdsToClose.isEmpty()) {
            Database.executeBatch(
                new BATCH_CloseCampaignMembersLyyti(new List<Id>(campaignIdsToClose)),
                200
            );
        }
    }

    private static String formatDate(Date d) {
        String year = String.valueOf(d.year());
        String month = (d.month() < 10 ? '0' : '') + String.valueOf(d.month());
        String day = (d.day() < 10 ? '0' : '') + String.valueOf(d.day());
        return year + '/' + month + '/' + day;
    }
}