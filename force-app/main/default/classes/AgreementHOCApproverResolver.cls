/** ──────────────────────────────────────
 * @description Resolves the HOC (Head of Coverage) approver queue for a Convention__c record.
 *              Reads Business_Region__c directly off the record (Convention__c is itself
 *              the Agreement, unlike Grid__c which traverses Agreement__r) and delegates the
 *              region-to-queue lookup to HOCApproverResolver.
 * @author Charles EID
 * @implements IApproverResolver
────────────────────────────────────── */
public with sharing class AgreementHOCApproverResolver implements IApproverResolver {

    public List<Id> resolve(Id recordId) {
        List<Convention__c> conventions = [SELECT Business_Region__c FROM Convention__c WHERE Id = :recordId LIMIT 1];
        if (conventions.isEmpty()) return new List<Id>();

        return HOCApproverResolver.resolve(conventions[0].Business_Region__c);
    }
}