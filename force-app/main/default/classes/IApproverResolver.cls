/** ──────────────────────────────────────
 * @description Interface for dynamic approver resolution used by the Custom Approval History LWC.
 *              Implement this interface in a class and reference it via ApprovalStepConfig__mdt.ApproverResolverClass__c
 *              to dynamically resolve the next approver(s) for an approval step based on the record being approved.
 * @author Charles EID
────────────────────────────────────── */
public interface IApproverResolver {
    /**
     * @description Resolves the list of approver Ids (User or Queue) for the given record.
     * @param recordId The Id of the SObject record being processed through the approval.
     * @return List of User or Queue Ids to set as next approvers. Return empty list if resolution fails.
     */
    List<Id> resolve(Id recordId);
}