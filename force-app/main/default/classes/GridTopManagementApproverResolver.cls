/** ──────────────────────────────────────
 * @description Resolves the Top Management approver queue for a Grid__c record.
 *              Reads the Agreement's Carmignac_Legal_Entity__c field and returns
 *              the corresponding queue: CGF_Top_Management or CGL_Top_Management.
 * @author Charles EID
 * @implements IApproverResolver
────────────────────────────────────── */
public with sharing class GridTopManagementApproverResolver implements IApproverResolver {

    private static final Map<String, String> QUEUE_BY_LEGAL_ENTITY = new Map<String, String>{
        'CGF' => 'CGF_Top_Management',
        'CGL' => 'CGL_Top_Management'
    };

    public List<Id> resolve(Id recordId) {
        String queueDeveloperName;
        for (Grid__c grid : [SELECT Agreement__r.Carmignac_Legal_Entity__c FROM Grid__c WHERE Id = :recordId LIMIT 1]) {
            if (QUEUE_BY_LEGAL_ENTITY.containsKey(grid.Agreement__r?.Carmignac_Legal_Entity__c)) {
                queueDeveloperName = QUEUE_BY_LEGAL_ENTITY.get(grid.Agreement__r.Carmignac_Legal_Entity__c);
            }
        }

        if(String.isBlank(queueDeveloperName)) { return new List<Id>(); }

        List<Group> queues = [SELECT Id FROM Group WHERE DeveloperName = :queueDeveloperName AND Type = 'Queue' LIMIT 1];
        return queues.isEmpty() ? new List<Id>() : new List<Id>{ queues[0].Id };
    }
}