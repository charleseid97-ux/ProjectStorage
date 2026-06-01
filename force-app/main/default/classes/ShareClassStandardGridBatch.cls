/** ──────────────────────────────────────
 * @description Batch triggered on Share_Class__c AfterInsert.
 *              Runs the moteur de calcul (GridDetailBuilder.buildForGrids) for all Standard Grids
 *              so that newly inserted share classes get their StandardGridDetail__c records.
 *              Chains ShareClassCustomGridBatch in finish() to ensure standard details exist
 *              before custom grid evaluation begins.
 * @author Charles EID
 ────────────────────────────────────── */
public class ShareClassStandardGridBatch implements Database.Batchable<SObject> {

    private Set<Id> newShareClassIds;

    public ShareClassStandardGridBatch(Set<Id> newShareClassIds) {
        this.newShareClassIds = newShareClassIds;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id FROM Grid__c
            WHERE RecordType.DeveloperName = 'StandardGrid'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Grid__c> scope) {
        Set<Id> scopeIds = new Set<Id>();
        for (Grid__c g : scope) {
            scopeIds.add(g.Id);
        }
        GridDetailBuilder.buildForGrids(scopeIds);
    }

    public void finish(Database.BatchableContext bc) {
        Database.executeBatch(new ShareClassCustomGridBatch(newShareClassIds), 50);
    }
}