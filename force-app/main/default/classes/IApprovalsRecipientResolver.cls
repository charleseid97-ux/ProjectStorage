/** ──────────────────────────────────────
 * @description Interface for the Approvals Reminder recipient resolution extension point.
 *              Implement this interface to override per-bundle recipient splitting in ApprovalsReminderBatch.
 *              Register the implementing class name in ApprovalsReminder__mdt.RecipientResolverClass__c.
 *              The resolve() method receives the full list of overdue items and returns one EmailBundle
 *                  per logical destination (e.g. one per business region). The batch merges the base
 *                  TO/CC/BCC addresses (from RecipientQueues__c etc.) into every bundle before sending.
 * @author Charles EID
 ────────────────────────────────────── */
public interface IApprovalsRecipientResolver {
    List<ApprovalsReminderBatch.EmailBundle> resolve(List<CustomApprovalInboxController.ItemToApprove> overdueItems);
}