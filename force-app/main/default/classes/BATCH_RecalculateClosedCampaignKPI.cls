// TO DELETE
// For Historique : Campaign already closed
public with sharing class BATCH_RecalculateClosedCampaignKPI
    implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Campaign
            WHERE Status = 'Closed'
              AND LyytiId__c != null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Campaign> scope) {
        Set<Id> campaignIds = new Set<Id>();

        for (Campaign c : scope) {
            campaignIds.add(c.Id);
        }

        Map<Id, Campaign> updates =
            CampaignCloseKpiService.buildCampaignUpdates(campaignIds);

        if (!updates.isEmpty()) {
            Database.update(updates.values(), false);
        }
    }

    public void finish(Database.BatchableContext bc) {
    }
}