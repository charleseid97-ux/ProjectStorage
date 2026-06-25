/** ──────────────────────────────────────
 * @description Refreshes denormalized fields on active Custom GridDetails, chained from ShareClassCustomGridBatch.finish().
 *              Runs after the nightly custom grid reconciliation to keep FlowsYTD__c and TotalAUMEur__c in sync.
 *              Processes records in chunks of BATCH_SIZE_GRID_DETAIL_REFRESH, using aggregate queries to avoid DML/queries in loops.
 * @author Charles EID
 * @testClass GridDetailRefreshBatchTest
 ────────────────────────────────────── */
public class GridDetailRefreshBatch implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, ShareClass__c, Grid__r.Agreement__c
                                         FROM GridDetail__c
                                         WHERE IsCurrentGridDetail__c = true
                                         AND Grid__r.RecordType.DeveloperName = :GridBuilderHelper.RT_CUSTOM_GRID
                                         ORDER BY Grid__r.Agreement__c, ShareClass__c]);
    }

    public void execute(Database.BatchableContext bc, List<GridDetail__c> scope) {
        Set<Id> shareClassIds = new Set<Id>();
        Set<Id> agreementIds  = new Set<Id>();
        for (GridDetail__c gd : scope) {
            if (gd.ShareClass__c != null)        shareClassIds.add(gd.ShareClass__c);
            if (gd.Grid__r.Agreement__c != null) agreementIds.add(gd.Grid__r.Agreement__c);
        }
        if (shareClassIds.isEmpty() || agreementIds.isEmpty()) return;

        Map<String, Decimal> flowByKey = new Map<String, Decimal>();
        for (AggregateResult ar : [SELECT Agreement__c, ShareClass__c, SUM(AmountEUR__c) totalAmount
                                   FROM Flow__c
                                   WHERE Agreement__c IN :agreementIds
                                   AND ShareClass__c IN :shareClassIds
                                   AND ValueDate__c = THIS_YEAR
                                   GROUP BY Agreement__c, ShareClass__c]) {
            flowByKey.put(String.valueOf(ar.get('Agreement__c')) + ':' + String.valueOf(ar.get('ShareClass__c')), (Decimal) ar.get('totalAmount'));
        }

        Map<String, Decimal> aumByKey = new Map<String, Decimal>();
        for (AggregateResult ar : [SELECT Convention__c, ShareClass__c, SUM(AmountEUR__c) totalAmount
                                   FROM AUM__c
                                   WHERE Convention__c IN :agreementIds
                                   AND ShareClass__c IN :shareClassIds
                                   AND Last_AUM__c = true
                                   GROUP BY Convention__c, ShareClass__c]) {
            aumByKey.put(String.valueOf(ar.get('Convention__c')) + ':' + String.valueOf(ar.get('ShareClass__c')), (Decimal) ar.get('totalAmount'));
        }

        List<GridDetail__c> toUpdate = new List<GridDetail__c>();
        String key;
        Decimal flow, aum;
        for (GridDetail__c gd : scope) {
            key  = String.valueOf(gd.Grid__r.Agreement__c) + ':' + String.valueOf(gd.ShareClass__c);
            flow = flowByKey.containsKey(key) ? flowByKey.get(key) : 0;
            aum  = aumByKey.containsKey(key) ? aumByKey.get(key) : 0;
            toUpdate.add(new GridDetail__c(Id = gd.Id, FlowsYTD__c = flow, TotalAUMEur__c = aum));
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    public void finish(Database.BatchableContext bc) {}
}