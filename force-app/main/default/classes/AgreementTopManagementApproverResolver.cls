/** ──────────────────────────────────────
 * @description Resolves the Top Management approver queue for a Convention__c record.
 *              Reads Carmignac_Legal_Entity__c directly off the record and delegates the
 *              legal-entity-to-queue lookup to TopManagementApproverResolver.
 * @author Charles EID
 * @implements IApproverResolver
────────────────────────────────────── */
public with sharing class AgreementTopManagementApproverResolver implements IApproverResolver {

    public List<Id> resolve(Id recordId) {
        List<Convention__c> conventions = [SELECT Carmignac_Legal_Entity__c FROM Convention__c WHERE Id = :recordId LIMIT 1];
        if (conventions.isEmpty()) return new List<Id>();

        return TopManagementApproverResolver.resolve(conventions[0].Carmignac_Legal_Entity__c);
    }
}