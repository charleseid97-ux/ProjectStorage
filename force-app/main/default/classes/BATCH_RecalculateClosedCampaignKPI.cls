// TO DELETE
// For Historique : Campaign already closed
public with sharing class BATCH_RecalculateClosedCampaignKPI
    implements Database.Batchable<SObject> {

    // Selects Bookly campaigns after the configured delay and keeps the existing rule for other campaigns.
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Integer kpiDelay = Integer.valueOf(Label.BooklyCampaignKPI_Delay);
        Date kpiCalculationDate = Date.today().addDays(-kpiDelay);

        // Bookly campaigns rely on the Event start date, while other campaigns keep the existing conditions.
        return Database.getQueryLocator([
            SELECT Id
            FROM Campaign
            WHERE (Event__c != null
                   AND Event__r.startDate__c <= :kpiCalculationDate)
               OR (Event__c = null
                   AND Status = 'Closed'
                   AND LyytiId__c != null)
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