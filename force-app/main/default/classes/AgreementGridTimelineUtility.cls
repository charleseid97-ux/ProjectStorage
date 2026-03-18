/** ──────────────────────────────────────
 * @description Utility class for AgreementGridTimeline__c lifecycle transitions.
 *              Handles the three amendment status transitions that affect timeline records:
 *              A) Submitted → Draft timeline becomes Pending Approval
 *              B) Approved  → Pending Approval becomes Active; Active becomes Inactive; agreement fields swapped
 *              C) Rejected  → Draft/Pending Approval timeline becomes Rejected
 *              Called from SM034_AgreementService.handleBeforeUpdate().
 * @author Charles EID
────────────────────────────────────── */
public without sharing class AgreementGridTimelineUtility {

    public static void handleTimelineTransitions(List<Convention__c> newAgreements, Map<Id, Convention__c> oldAgreements) {

        // ── Collect agreement Ids by transition type ──
        Set<Id> submittedAgreementIds = new Set<Id>();                   // Draft → Pending Approval
        Set<Id> approvedAgreementIds = new Set<Id>();                    // Pending Approval → Active
        Set<Id> rejectedAgreementIds = new Set<Id>();                    // Draft/Pending Approval → Rejected
        Map<Id, Id> approvedGridByAgreement = new Map<Id, Id>();         // agr.Id → Grid_Request__c (becoming active)
        Map<Id, Date> requestStartDateByAgreement = new Map<Id, Date>(); // agr.Id → Grid_Request_Start_Date__c (end date of old active timeline)

        for (Convention__c agr : newAgreements) {
            Convention__c oldAgr = oldAgreements.get(agr.Id);
            String oldStatus = oldAgr.Amendment_Approval_Status__c;
            String newStatus = agr.Amendment_Approval_Status__c;

            // Branch A: Amendment submitted — status transitions from blank/'Need Submission' to any active approval stage
            if ((String.isEmpty(oldStatus) || oldStatus == 'Need Submission') && String.isNotEmpty(newStatus) && newStatus != 'Need Submission' && newStatus != 'Approval Rejected' && newStatus != 'Approved' && agr.Grid_Request__c != null) {
                submittedAgreementIds.add(agr.Id);
            }

            // Branch B: Amendment approved — update existing timeline records instead of creating a new one
            if (newStatus == 'Approved' && agr.Grid_Request_Approved__c) {
                approvedAgreementIds.add(agr.Id);
                approvedGridByAgreement.put(agr.Id, agr.Grid_Request__c);
                requestStartDateByAgreement.put(agr.Id, agr.Grid_Request_Start_Date__c); // captured before field swap clears it
                // Existing field swaps — unchanged
                agr.Grid__c = agr.Grid_Request__c;
                agr.Grid_Request__c = null;
                agr.Grid_Start_Date__c = agr.Grid_Request_Start_Date__c;
                agr.Grid_Request_Start_Date__c = null;
                agr.Amendment_Approval_Status__c = '';
                agr.Grid_Request_Approved__c = false;
            }

            // Branch C: Amendment rejected
            if (newStatus == 'Approval Rejected' && oldStatus != 'Approval Rejected' && agr.Grid_Request__c != null) {
                rejectedAgreementIds.add(agr.Id);
            }
        }

        // ── Post-loop: query and update AgreementGridTimeline__c and Grid__c records ──
        List<AgreementGridTimeline__c> timelinesToUpdate = new List<AgreementGridTimeline__c>();
        List<Grid__c> gridsToUpdate = new List<Grid__c>();
        String agtQuery = 'SELECT Id, Status__c, Grid__c, Agreement__c FROM AgreementGridTimeline__c ';

        if (!submittedAgreementIds.isEmpty()) {
            for (AgreementGridTimeline__c agt : Database.query(agtQuery + ' WHERE Agreement__c IN :submittedAgreementIds AND Status__c = \'Draft\'')) {
                agt.Status__c = 'Pending Approval';
                timelinesToUpdate.add(agt);
                gridsToUpdate.add(new Grid__c(Id = agt.Grid__c, ApprovalStatus__c = 'Pending Approval'));
            }
        }

        if (!approvedAgreementIds.isEmpty()) {
            for (AgreementGridTimeline__c agt : Database.query(agtQuery + ' WHERE Agreement__c IN :approvedAgreementIds AND Status__c IN (\'Active\', \'Pending Approval\')')){
                if (agt.Status__c == 'Active') {
                    agt.Status__c = 'Inactive';
                    agt.GridEndDate__c = requestStartDateByAgreement.get(agt.Agreement__c);
                } else {
                    agt.Status__c = 'Active';
                    gridsToUpdate.add(new Grid__c(Id = approvedGridByAgreement.get(agt.Agreement__c), ApprovalStatus__c = 'Approved'));
                }
                timelinesToUpdate.add(agt);
            }
        }

        if (!rejectedAgreementIds.isEmpty()) {
            for (AgreementGridTimeline__c agt : Database.query(agtQuery + ' WHERE Agreement__c IN :rejectedAgreementIds AND Status__c IN (\'Draft\', \'Pending Approval\')')) {
                agt.Status__c = 'Rejected';
                timelinesToUpdate.add(agt);
                gridsToUpdate.add(new Grid__c(Id = agt.Grid__c, ApprovalStatus__c = 'Rejected'));
            }
        }

        if (!timelinesToUpdate.isEmpty()) update timelinesToUpdate;
        if (!gridsToUpdate.isEmpty()) update gridsToUpdate;
    }

    public static AgreementGridTimeline__c createAgreementGridTimeline(Convention__c agmt, Grid__c grid, Date startDate, String status) {
        String agrGridTimelineName = agmt.Name + ' - ' + grid.Name;
        return new AgreementGridTimeline__c(
            Name = agrGridTimelineName.substring(0, Math.min(80, agrGridTimelineName.length())),
            Agreement__c = agmt.Id,
            Grid__c = grid.Id,
            GridStartDate__c = startDate,
            Status__c = status
        );
    }
}