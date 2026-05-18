public with sharing class BATCH_CloseCampaignMembersLyyti implements Database.Batchable<SObject>, Database.Stateful {

    private Set<Id> campaignIdsToClose;

    public BATCH_CloseCampaignMembersLyyti(List<Id> campaignIds) {
        this.campaignIdsToClose = new Set<Id>();
        if (campaignIds != null) {
            this.campaignIdsToClose.addAll(campaignIds);
        }
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (campaignIdsToClose == null || campaignIdsToClose.isEmpty()) {
            return Database.getQueryLocator([
                SELECT Id
                FROM CampaignMember
                WHERE Id = null
            ]);
        }

        return Database.getQueryLocator([
            SELECT Id, CampaignId, Status, Cancelled__c
            FROM CampaignMember
            WHERE CampaignId IN :campaignIdsToClose
              AND Cancelled__c = true
              AND Status != 'Cancelled'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<CampaignMember> members) {
        for (CampaignMember member : members) {
            member.Status = 'Cancelled';
        }

        if (!members.isEmpty()) {
            Database.update(members, false);
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (campaignIdsToClose == null || campaignIdsToClose.isEmpty()) {
            return;
        }

        Map<Id, Campaign> campaignUpdates = CampaignCloseKpiService.buildCampaignUpdates(campaignIdsToClose);

        for (Id campaignId : campaignUpdates.keySet()) {
            campaignUpdates.get(campaignId).Status = 'Closed';
        }

        if (!campaignUpdates.isEmpty()) {
            Database.update(campaignUpdates.values(), false);
        }
    }
}