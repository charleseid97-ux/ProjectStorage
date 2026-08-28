/** ──────────────────────────────────────
 * @description Resolves the HOC (Head of Coverage) approver queue for a Grid__c record.
 *              Reads the Agreement's Business_Region__c field and delegates the
 *              region-to-queue lookup to HOCApproverResolver.
 *              Used by CustomApprovalHistoryController when processing the HOCApproval step
 *              of the Grid Amendment Request Approval process.
 * @author Charles EID
 * @implements IApproverResolver
────────────────────────────────────── */
public with sharing class GridHOCApproverResolver implements IApproverResolver {

    public List<Id> resolve(Id recordId) {
        List<Grid__c> grids = [SELECT Agreement__r.Business_Region__c FROM Grid__c WHERE Id = :recordId LIMIT 1];
        if (grids.isEmpty()) return new List<Id>();

        return HOCApproverResolver.resolve(grids[0].Agreement__r?.Business_Region__c);
    }
}