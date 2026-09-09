/** ──────────────────────────────────────
 * @description IApprovalAction implementation for the GridAmendment approval process
 *              (InitialSubmission). Sets the parent Agreement's (Convention__c) Status__c
 *              to Pending Renewal / Change Requested / Change Renewal based on whether the
 *              previous active grid had ended, and if so, whether the new grid's detail
 *              lines match the previous grid's detail lines. Only applies when the Agreement
 *              is currently Signed - any other status is left untouched.
 * @author Charles EID
 ────────────────────────────────────── */
public without sharing class GridAmendmentAgreementStatusAction implements IApprovalAction {

    private static final String STATUS_SIGNED           = 'Signed';
    private static final String STATUS_CHANGE_REQUESTED = 'Change Requested';
    private static final String STATUS_PENDING_RENEWAL  = 'Pending Renewal';
    private static final String STATUS_CHANGE_RENEWAL   = 'Change Renewal';

    public void execute(Id targetRecordId, Id currentUserId, Map<String, Object> context) {
        List<Grid__c> grids = [SELECT Id, Agreement__c FROM Grid__c WHERE Id = :targetRecordId LIMIT 1];
        if (grids.isEmpty() || grids[0].Agreement__c == null) return;

        List<Convention__c> agreements = [SELECT Id, Grid__c, Status__c FROM Convention__c WHERE Id = :grids[0].Agreement__c LIMIT 1];
        if (agreements.isEmpty()) return;
        Convention__c agreement = agreements[0];
        if (agreement.Status__c != STATUS_SIGNED) return;

        Id previousGridId = agreement.Grid__c;
        if (previousGridId == null) return;

        if (!isMostRecentGrid(agreement.Id, targetRecordId)) return;

        List<Grid__c> previousGrids = [SELECT EndDate__c FROM Grid__c WHERE Id = :previousGridId LIMIT 1];
        if (previousGrids.isEmpty()) return;

        String newStatus;
        if (previousGrids[0].EndDate__c == null) {
            newStatus = STATUS_CHANGE_REQUESTED;
        } else {
            newStatus = haveSameGridDetails(previousGridId, targetRecordId) ? STATUS_PENDING_RENEWAL : STATUS_CHANGE_RENEWAL;
        }

        update new Convention__c(Id = agreement.Id, Status__c = newStatus);
    }

    private Boolean isMostRecentGrid(Id agreementId, Id submittedGridId) {
        List<AgreementGridTimeline__c> latest = [SELECT Grid__c
                                                  FROM AgreementGridTimeline__c
                                                  WHERE Agreement__c = :agreementId AND GridStartDate__c != null
                                                  ORDER BY GridStartDate__c DESC
                                                  LIMIT 1];
        return latest.isEmpty() || latest[0].Grid__c == submittedGridId;
    }

    private Boolean haveSameGridDetails(Id previousGridId, Id newGridId) {
        GridComparisonController.ComparisonData comparison = GridComparisonController.getComparisonData(previousGridId, newGridId);

        Set<Id> previousDetailIds = new Set<Id>();
        for (GridDetailTableController.GridDetailRow row : comparison.current.rows) {
            previousDetailIds.add(row.standardGridDetailId);
        }

        Set<Id> newDetailIds = new Set<Id>();
        for (GridDetailTableController.GridDetailRow row : comparison.selected.rows) {
            newDetailIds.add(row.standardGridDetailId);
        }

        return previousDetailIds.equals(newDetailIds);
    }
}