/** ──────────────────────────────────────
 * @description Scheduled daily batch that runs the moteur de calcul (GridDetailBuilder.buildForGrids)
 *              for all Standard Grids, 50 grids per chunk, then unconditionally chains
 *              ShareClassCustomGridBatch to reconcile Custom Grid Details.
 *
 *              Chaining is unconditional because StandardGridDetails can also be created by the Grid Import
 *              Excel module between scheduled runs — gating the custom batch on "something was created here"
 *              would silently miss those cases.
 *
 *              Schedule: System.schedule('Grid Reconciliation', '0 0 1 * * ?', new ShareClassStandardGridBatch());
 *
 * @author Charles EID
 * @testClass ShareClassGridBatchTest
 ────────────────────────────────────── */
public class ShareClassStandardGridBatch implements Database.Batchable<SObject>, Schedulable {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new ShareClassStandardGridBatch(), 50);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id FROM Grid__c WHERE RecordType.DeveloperName = 'StandardGrid']);
    }

    public void execute(Database.BatchableContext bc, List<Grid__c> scope) {
        Set<Id> scopeIds = new Set<Id>();
        for (Grid__c g : scope) scopeIds.add(g.Id);
        GridDetailBuilder.buildForGrids(scopeIds);
    }

    public void finish(Database.BatchableContext bc) {
        Database.executeBatch(new ShareClassCustomGridBatch(), 1);
    }
}