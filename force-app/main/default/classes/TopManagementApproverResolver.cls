/** ──────────────────────────────────────
 * @description Resolves the Top Management approver queue for a given Carmignac Legal Entity
 *              (CGF -> CGF_Top_Management, CGL -> CGL_Top_Management). Shared by every
 *              object-specific resolver (GridTopManagementApproverResolver,
 *              AgreementTopManagementApproverResolver, ...) so the legal-entity-to-queue
 *              lookup lives in one place.
 * @author Charles EID
────────────────────────────────────── */
public with sharing class TopManagementApproverResolver {

    private static final Map<String, String> QUEUE_BY_LEGAL_ENTITY = new Map<String, String>{
        'CGF' => 'CGF_Top_Management',
        'CGL' => 'CGL_Top_Management'
    };

    public static List<Id> resolve(String legalEntity) {
        if (!QUEUE_BY_LEGAL_ENTITY.containsKey(legalEntity)) return new List<Id>();

        String queueDeveloperName = QUEUE_BY_LEGAL_ENTITY.get(legalEntity);
        List<Group> queues = [SELECT Id FROM Group WHERE DeveloperName = :queueDeveloperName AND Type = 'Queue' LIMIT 1];
        return queues.isEmpty() ? new List<Id>() : new List<Id>{ queues[0].Id };
    }
}
