/** ──────────────────────────────────────
 * @description Resolves the Top Management approver queue for a Grid__c record.
 *              Reads the Agreement's Carmignac_Legal_Entity__c field and delegates the
 *              legal-entity-to-queue lookup to TopManagementApproverResolver.
 * @author Charles EID
 * @implements IApproverResolver
────────────────────────────────────── */
public with sharing class GridTopManagementApproverResolver implements IApproverResolver {

    public List<Id> resolve(Id recordId) {
        List<Grid__c> grids = [SELECT Agreement__r.Carmignac_Legal_Entity__c FROM Grid__c WHERE Id = :recordId LIMIT 1];
        if (grids.isEmpty()) return new List<Id>();

        return TopManagementApproverResolver.resolve(grids[0].Agreement__r?.Carmignac_Legal_Entity__c);
    }
}