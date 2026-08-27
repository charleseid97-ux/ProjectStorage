/** ──────────────────────────────────────
 * @description Resolves the HOC (Head of Coverage) approver queue for a given Business Region.
 *              Reads Queue_Business_Region__mdt to find the regional HOC queue, then returns
 *              its Group Id. Shared by every object-specific resolver (GridHOCApproverResolver,
 *              AgreementHOCApproverResolver, ...) so the region-to-queue lookup lives in one place.
 * @author Charles EID
────────────────────────────────────── */
public with sharing class HOCApproverResolver {

    public static List<Id> resolve(String businessRegion) {
        if (String.isBlank(businessRegion)) return new List<Id>();

        List<Queue_Business_Region__mdt> mdts = [SELECT HOCQueue__c FROM Queue_Business_Region__mdt WHERE Business_region__c = :businessRegion LIMIT 1];
        if (mdts.isEmpty() || String.isBlank(mdts[0].HOCQueue__c)) return new List<Id>();

        List<Group> queues = [SELECT Id FROM Group WHERE DeveloperName = :mdts[0].HOCQueue__c AND Type = 'Queue' LIMIT 1];
        return queues.isEmpty() ? new List<Id>() : new List<Id>{ queues[0].Id };
    }
}