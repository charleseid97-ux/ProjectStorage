/** ──────────────────────────────────────
 * @description Utility class for AgreementGridTimeline__c DML operations.
 *              Classification of which agreements belong to which transition bucket is done
 *              by GridUtility, which calls updateTimelines() with pre-classified data.
 * @author Charles EID
 * @testClass GridLifecycleTest
 * @coverage 100%   [19-03-26]
────────────────────────────────────── */
public with sharing class AgreementGridTimelineUtility {

    public static final String AGT_DRAFT           = 'Draft';
    public static final String AGT_PENDINGAPPROVAL = 'Pending Approval';
    public static final String AGT_ACTIVE          = 'Active';
    public static final String AGT_APPROVED        = 'Approved';
    public static final String AGT_INACTIVE        = 'Inactive';
    public static final String AGT_REJECTED        = 'Rejected';

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
        for(AgreementGridTimeline__c agt : [SELECT Id, Status__c, Agreement__c, Grid__c, GridStartDate__c, GridEndDate__c
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

    /** ── On Grid__c AfterInsert / AfterUpdate: upsert a Draft AGT for every eligible Custom Grid.
     *     Pass oldGrids on update to skip grids where no relevant field changed. ── */
    public static void handleGridUpsert(List<Grid__c> newGrids, Map<Id, Grid__c> oldGrids) {
        Id customGridRtId = Schema.SObjectType.Grid__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID).getRecordTypeId();
        Set<Id> agreementIds = new Set<Id>();
        Set<Id> gridIds      = new Set<Id>();
        List<Grid__c> eligible = new List<Grid__c>();

        for (Grid__c g : newGrids) {
            if (g.RecordTypeId != customGridRtId || g.Agreement__c == null) continue;
            if (oldGrids != null) {
                Grid__c old = oldGrids.get(g.Id);
                if (g.Agreement__c == old.Agreement__c && g.StartDate__c == old.StartDate__c && g.EndDate__c == old.EndDate__c) continue;
            }
            eligible.add(g);
            agreementIds.add(g.Agreement__c);
            gridIds.add(g.Id);
        }
        if (eligible.isEmpty()) return;

        Map<Id, Convention__c> agreements = new Map<Id, Convention__c>([SELECT Id, Name FROM Convention__c WHERE Id IN :agreementIds]);

        Map<Id, Id> agtIdByGrid = new Map<Id, Id>();
        for (AgreementGridTimeline__c agt : [SELECT Id, Grid__c FROM AgreementGridTimeline__c WHERE Grid__c IN :gridIds AND Status__c = :AGT_DRAFT]) {
            agtIdByGrid.put(agt.Grid__c, agt.Id);
        }

        List<AgreementGridTimeline__c> toUpsert = new List<AgreementGridTimeline__c>();
        for (Grid__c g : eligible) {
            Convention__c agr = agreements.get(g.Agreement__c);
            if (agr == null) continue;
            AgreementGridTimeline__c agt = createAgreementGridTimeline(agr, g, g.StartDate__c, g.EndDate__c, AGT_DRAFT);
            if (agtIdByGrid.containsKey(g.Id)) agt.Id = agtIdByGrid.get(g.Id);
            toUpsert.add(agt);
        }
        if (!toUpsert.isEmpty()) upsert toUpsert;
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
            agt.GridEndDate__c = requestStartDateByAgreement.get(agt.Agreement__c).addDays(-1);
        }
        else if((agt.Status__c == AGT_DRAFT || agt.Status__c == AGT_PENDINGAPPROVAL) && gridIds.contains(agt.Grid__c)) {
            agt.Status__c = (agt.GridStartDate__c != null && agt.GridStartDate__c > Date.today()) ? AGT_APPROVED : AGT_ACTIVE;
        }
        return agt;
    }

    private static Set<Id> flattenGridIds(Map<Id, List<Id>> agrToGridIds) {
        Set<Id> gridIds = new Set<Id>();
        for (List<Id> ids : agrToGridIds.values()) gridIds.addAll(ids);
        return gridIds;
    }
}