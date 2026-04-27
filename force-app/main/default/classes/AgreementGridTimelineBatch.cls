/** ──────────────────────────────────────
 * @description Activates AgreementGridTimeline__c records that were deferred at approval time
 *              because their Grid start date was in the future. Runs daily via AgreementGridTimelineScheduler.
 *              For each AGT with Status = 'Approved' and GridStartDate__c <= today:
 *                - Sets AGT Status → Active
 *                - Performs the Agreement field swap (Grid_Request__c → Grid__c)
 * @author Charles EID
────────────────────────────────────── */
public with sharing class AgreementGridTimelineBatch implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date today = Date.today();
        return Database.getQueryLocator([
            SELECT Id, Agreement__c, Grid__c, GridStartDate__c
            FROM AgreementGridTimeline__c
            WHERE Status__c = :AgreementGridTimelineUtility.AGT_APPROVED
            AND GridStartDate__c <= :today
        ]);
    }

    public void execute(Database.BatchableContext bc, List<AgreementGridTimeline__c> scope) {
        Set<Id> agreementIds = new Set<Id>();
        for (AgreementGridTimeline__c agt : scope) agreementIds.add(agt.Agreement__c);

        Map<Id, Convention__c> agreementsById = new Map<Id, Convention__c>([
            SELECT Id, Grid__c, Grid_Request__c, Grid_Request_Start_Date__c,
                   Grid_Start_Date__c, Amendment_Approval_Status__c, Grid_Request_Approved__c
            FROM Convention__c
            WHERE Id IN :agreementIds
        ]);

        List<AgreementGridTimeline__c> agtsToActivate  = new List<AgreementGridTimeline__c>();
        List<Convention__c>           agreementsToUpdate = new List<Convention__c>();
        Set<Id>                       processedAgreements = new Set<Id>();

        for (AgreementGridTimeline__c agt : scope) {
            agt.Status__c = AgreementGridTimelineUtility.AGT_ACTIVE;
            agtsToActivate.add(agt);

            if (processedAgreements.contains(agt.Agreement__c)) continue;
            processedAgreements.add(agt.Agreement__c);

            Convention__c agr = agreementsById.get(agt.Agreement__c);
            if (agr == null || agr.Grid_Request__c == null) continue;
            agr.Grid__c                      = agr.Grid_Request__c;
            agr.Grid_Request__c              = null;
            agr.Grid_Start_Date__c           = agr.Grid_Request_Start_Date__c;
            agr.Grid_Request_Start_Date__c   = null;
            agr.Amendment_Approval_Status__c = '';
            agr.Grid_Request_Approved__c     = false;
            agreementsToUpdate.add(agr);
        }

        if (!agtsToActivate.isEmpty()) update agtsToActivate;
        if (!agreementsToUpdate.isEmpty()) update agreementsToUpdate;
        // Agreement trigger fires on update — isD will not re-fire:
        //   isD requires !oldAgr.Grid_Request_Approved__c, but the old value is already true (transition guard fails)
        //   After swap, Grid_Request__c = null → isC/isE conditions also fail
    }

    public void finish(Database.BatchableContext bc) {}
}
