/** ──────────────────────────────────────
 * @description Resolves the HOC (Head of Coverage) approver queue for a Grid__c record.
 *              Reads the Agreement's Business_Region__c field, looks up the corresponding
 *              HOC queue name from Queue_Business_Region__mdt, then returns the Group (Queue) Id.
 *              Used by CustomApprovalHistoryController when processing the HOCApproval step
 *              of the Grid Amendment Request Approval process.
 * @author Charles EID
 * @implements IApproverResolver
────────────────────────────────────── */
public with sharing class GridHOCApproverResolver implements IApproverResolver {

    public List<Id> resolve(Id recordId) {
        List<Grid__c> grids = [SELECT Agreement__r.Business_Region__c FROM Grid__c WHERE Id = :recordId LIMIT 1];
        if (grids.isEmpty()) {
            return new List<Id>();
        }

        String region = grids[0].Agreement__r?.Business_Region__c;
        if (String.isBlank(region)) {
            return new List<Id>();
        }

        List<Queue_Business_Region__mdt> mdts = [SELECT HOCQueue__c FROM Queue_Business_Region__mdt WHERE Business_region__c = :region LIMIT 1];
        if (mdts.isEmpty() || String.isBlank(mdts[0].HOCQueue__c)) {
            return new List<Id>();
        }

        List<Group> queues = [SELECT Id FROM Group WHERE Name = :mdts[0].HOCQueue__c AND Type = 'Queue' LIMIT 1];
        return queues.isEmpty() ? new List<Id>() : new List<Id>{ queues[0].Id };
    }
}