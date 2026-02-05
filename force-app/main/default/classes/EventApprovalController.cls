public with sharing class EventApprovalController {

    // Flow used to apply approve/reject on an ApprovalWorkItem
    private static final String APPROVAL_ACTION_FLOW_API_NAME =
        'Approve_ApprovalWorkItem_Flow';

    // URL parameters
    public String awid { get; set; }        // ApprovalWorkItem.Id
    public String eid { get; set; }         // Related record Id
    public String actionParam { get; set; } // approve | reject
    public String comments { get; set; }    // Optional comments

    // Visualforce outputs
    public Boolean showResult { get; private set; }
    public String resultTitle { get; private set; }
    public String resultMessage { get; private set; }
    public String recordUrl { get; private set; }

    /**
     * Initializes parameters from the current VF page.
     * Supports both 'eid' and 'id' for the related record.
     */
    public EventApprovalController() {
        awid = ApexPages.currentPage().getParameters().get('awid');

        eid = ApexPages.currentPage().getParameters().get('eid');
        if (String.isBlank(eid)) {
            eid = ApexPages.currentPage().getParameters().get('id');
        }

        actionParam = ApexPages.currentPage().getParameters().get('action');
        comments    = ApexPages.currentPage().getParameters().get('comments');

        showResult    = false;
        resultTitle   = '';
        resultMessage = '';
        recordUrl     = '';
    }

    /**
     * Main action executed by the VF page.
     * Validates input, checks security and calls the Flow.
     */
    public PageReference run() {
        try {
            // Validate action parameter
            if (String.isBlank(actionParam)) {
                setResult(false, 'Action non fournie',
                    'Le paramètre "action" est requis.');
                return null;
            }

            String normalizedAction = actionParam.toLowerCase().trim();
            if (normalizedAction != 'approve' && normalizedAction != 'reject') {
                setResult(false, 'Action invalide',
                    'Action attendue : approve ou reject.');
                return null;
            }

            String decision =
                (normalizedAction == 'approve') ? 'Approve' : 'Reject';

            // Retrieve the ApprovalWorkItem
            ApprovalWorkItem awi = findApprovalWorkItem();
            if (awi == null) {
                setResult(false, 'Work item introuvable',
                    'Aucun work item accessible.');
                return null;
            }

            // Prevent double processing
            if (awi.Status != 'Assigned') {
                recordUrl = awi.RelatedRecordId != null
                    ? '/' + awi.RelatedRecordId
                    : '';
                setResult(true, 'Déjà traité',
                    'Ce work item a déjà été traité.');
                return null;
            }

            // Check that the current user can act
            if (!isUserAllowedToAct(UserInfo.getUserId(), awi.AssignedToId)) {
                recordUrl = awi.RelatedRecordId != null
                    ? '/' + awi.RelatedRecordId
                    : '';
                setResult(false, 'Accès refusé',
                    'Utilisateur non autorisé.');
                return null;
            }

            // Default comment if none provided
            String finalComments = !String.isBlank(comments)
                ? comments
                : (decision == 'Approve'
                    ? 'Approuvé via Visualforce.'
                    : 'Rejeté via Visualforce.');

            // Call the autolaunched Flow
            Flow.Interview interview = Flow.Interview.createInterview(
                APPROVAL_ACTION_FLOW_API_NAME,
                new Map<String, Object>{
                    'approvalWorkItemId' => awi.Id,
                    'decision'           => decision,
                    'comments'           => finalComments
                }
            );
            interview.start();

            recordUrl = awi.RelatedRecordId != null
                ? '/' + awi.RelatedRecordId
                : '';
            setResult(true, 'Succès',
                'La demande a été traitée avec succès.');

        } catch (Exception ex) {
            setResult(false, 'Erreur',
                'Une erreur est survenue : ' + ex.getMessage());
        }

        return null;
    }

    /**
     * Finds the ApprovalWorkItem either by Id or by
     * related record + user/group assignment.
     */
    private ApprovalWorkItem findApprovalWorkItem() {
        if (!String.isBlank(awid)) {
            List<ApprovalWorkItem> byId = [
                SELECT Id, Status, AssignedToId, RelatedRecordId
                FROM ApprovalWorkItem
                WHERE Id = :awid
                LIMIT 1
            ];
            return byId.isEmpty() ? null : byId[0];
        }

        if (String.isBlank(eid)) {
            return null;
        }

        Set<Id> actorIds = buildActorIds(UserInfo.getUserId());

        List<ApprovalWorkItem> awis = [
            SELECT Id, Status, AssignedToId, RelatedRecordId
            FROM ApprovalWorkItem
            WHERE RelatedRecordId = :eid
              AND Status = 'Assigned'
              AND AssignedToId IN :actorIds
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        return awis.isEmpty() ? null : awis[0];
    }

    /**
     * Checks if the user is directly assigned or
     * member of the assigned group.
     */
    private Boolean isUserAllowedToAct(Id userId, Id assignedToId) {
        if (assignedToId == null) return false;
        if (assignedToId == userId) return true;

        return buildActorIds(userId).contains(assignedToId);
    }

    /**
     * Builds the set of user and all related groups
     * (including nested groups).
     */
    private Set<Id> buildActorIds(Id userId) {
        Set<Id> actorIds = new Set<Id>{ userId };
        Set<Id> toExpand = new Set<Id>{ userId };

        Integer safety = 0;
        while (!toExpand.isEmpty() && safety < 10) {
            safety++;

            Set<Id> next = new Set<Id>();
            for (GroupMember gm : [
                SELECT GroupId
                FROM GroupMember
                WHERE UserOrGroupId IN :toExpand
            ]) {
                if (!actorIds.contains(gm.GroupId)) {
                    actorIds.add(gm.GroupId);
                    next.add(gm.GroupId);
                }
            }
            toExpand = next;
        }

        return actorIds;
    }

    /**
     * Centralizes result display logic for the VF page.
     */
    private void setResult(Boolean success, String title, String message) {
        showResult    = true;
        resultTitle   = title;
        resultMessage = message;

        if (!success && String.isBlank(recordUrl) && !String.isBlank(eid)) {
            recordUrl = '/' + eid;
        }
    }
}
