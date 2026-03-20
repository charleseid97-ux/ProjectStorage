/** ──────────────────────────────────────
 * @description Utility class for AgreementGridTimeline__c DML operations.
 *              Classification of which agreements belong to which transition bucket is done
 *              by GridUtility, which calls updateTimelines() with pre-classified data.
 * @author Charles EID
 * @testClass GridLifecycleTest
 * @coverage 100%   [19-03-26]
────────────────────────────────────── */
public with sharing class AgreementGridTimelineUtility {

    private static final String AGT_DRAFT           = 'DRAFT';
    private static final String AGT_PENDINGAPPROVAL = 'Pending Approval';
    private static final String AGT_ACTIVE          = 'Active';
    private static final String AGT_INACTIVE        = 'Inactive';
    private static final String AGT_REJECTED        = 'Rejected';

    /** ──────────────────────────────────────
     * @description Applies AGT status transitions for pre-classified agreement sets and commits the update.
     *              Called by GridUtility after it has run its own Agreement/Grid field updates.
     ────────────────────────────────────── */
    public static void updateTimelines(Map<Id, List<Id>> submittedAgrToGridIds, Map<Id, List<Id>> approvedAgrToGridIds, Map<Id, List<Id>> rejectedAgrToGridIds, Map<Id, Date> requestStartDateByAgreement) {
        Set<Id> agreementIds = new Set<Id>();
        agreementIds.addAll(submittedAgrToGridIds.keySet());
        agreementIds.addAll(approvedAgrToGridIds.keySet());
        agreementIds.addAll(rejectedAgrToGridIds.keySet());

        Set<Id> gridIds;
        List<AgreementGridTimeline__c> timelinesToUpdate = new List<AgreementGridTimeline__c>();
        for(AgreementGridTimeline__c agt : [SELECT Id, Status__c, Agreement__c, Grid__c, GridEndDate__c
                                            FROM AgreementGridTimeline__c
                                            WHERE Agreement__c IN :agreementIds]) {
            if(submittedAgrToGridIds.containsKey(agt.Agreement__c)) {
                timelinesToUpdate.add(setNewTimelineStatus(submittedAgrToGridIds, agt, new List<String>{AGT_DRAFT}, AGT_PENDINGAPPROVAL));
            }
            else if(rejectedAgrToGridIds.containsKey(agt.Agreement__c)) {
                timelinesToUpdate.add(setNewTimelineStatus(rejectedAgrToGridIds, agt, new List<String>{AGT_DRAFT, AGT_PENDINGAPPROVAL}, AGT_REJECTED));
            }
            else if(approvedAgrToGridIds.containsKey(agt.Agreement__c)) {
                timelinesToUpdate.add(SetNewTimelineStatusApproved(approvedAgrToGridIds, agt, requestStartDateByAgreement));
            }
        }

        if (!timelinesToUpdate.isEmpty()) update timelinesToUpdate;
    }

    public static AgreementGridTimeline__c createAgreementGridTimeline(Convention__c agmt, Grid__c grid, Date startDate, Date endDate, String status) {
        String agrGridTimelineName = agmt.Name + ' - ' + grid.Name;
        return new AgreementGridTimeline__c(
            Name = agrGridTimelineName.substring(0, Math.min(80, agrGridTimelineName.length())),
            Agreement__c = agmt.Id,
            Grid__c = grid.Id,
            GridStartDate__c = startDate,
            GridEndDate__c = endDate,
            Status__c = status
        );
    }

    // ────────────────────────────────────── PRIVATE HELPERS ──────────────────────────────────────
    private static AgreementGridTimeline__c setNewTimelineStatus(Map<Id, List<Id>> agrToGridIds, AgreementGridTimeline__c agt, List<String> agtStatusesToConsider, String agtStatusToApply) {
        Set<Id> gridIds = flattenGridIds(agrToGridIds);
        if(agtStatusesToConsider.contains(agt.Status__c) && gridIds.contains(agt.Grid__c)) {
            agt.Status__c = agtStatusToApply;
        }
        return agt;
    }

    private static AgreementGridTimeline__c SetNewTimelineStatusApproved(Map<Id, List<Id>> agrToGridIds, AgreementGridTimeline__c agt, Map<Id, Date> requestStartDateByAgreement) {
        Set<Id> gridIds = flattenGridIds(agrToGridIds);
        if(agt.Status__c == AGT_ACTIVE && gridIds.contains(agt.Grid__c)) {
            agt.Status__c = AGT_INACTIVE;
            agt.GridEndDate__c = requestStartDateByAgreement.get(agt.Agreement__c);
        }
        else if((agt.Status__c == AGT_DRAFT || agt.Status__c == AGT_PENDINGAPPROVAL) && gridIds.contains(agt.Grid__c)) {
            agt.Status__c = AGT_ACTIVE;
        }
        return agt;
    }

    private static Set<Id> flattenGridIds(Map<Id, List<Id>> agrToGridIds) {
        Set<Id> gridIds = new Set<Id>();
        for (List<Id> ids : agrToGridIds.values()) gridIds.addAll(ids);
        return gridIds;
    }
}