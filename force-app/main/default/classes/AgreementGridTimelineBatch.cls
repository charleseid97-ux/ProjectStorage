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
        return Database.getQueryLocator([SELECT Id, Agreement__c
                                         FROM AgreementGridTimeline__c
                                         WHERE Status__c = :AgreementGridTimelineUtility.AGT_APPROVED
                                         AND GridStartDate__c <= :today]);
    }

    public void execute(Database.BatchableContext bc, List<AgreementGridTimeline__c> scope) {
        Set<Id> agreementIds = new Set<Id>();
        for (AgreementGridTimeline__c agt : scope) agreementIds.add(agt.Agreement__c);

        Map<Id, Convention__c> agreementsById = new Map<Id, Convention__c>([SELECT Id, Grid__c, Grid_Request__c, Grid_Request_Start_Date__c
                                                                            FROM Convention__c
                                                                            WHERE Id IN :agreementIds]);

        List<AgreementGridTimeline__c> agtsToActivate = new List<AgreementGridTimeline__c>();
        List<Convention__c> agreementsToUpdate        = new List<Convention__c>();
        Set<Id> oldGridIds                            = new Set<Id>();
        Set<Id> processedAgreements                   = new Set<Id>();

        for (AgreementGridTimeline__c agt : scope) {
            agt.Status__c = AgreementGridTimelineUtility.AGT_ACTIVE;
            agtsToActivate.add(agt);

            if (processedAgreements.contains(agt.Agreement__c)) continue;
            processedAgreements.add(agt.Agreement__c);

            Convention__c agr = agreementsById.get(agt.Agreement__c);
            if (agr == null || agr.Grid_Request__c == null) continue;

            if (agr.Grid__c != null) oldGridIds.add(agr.Grid__c);

            GridUtility.setGridOnAgreement(agr);
            agreementsToUpdate.add(agr);
        }

        if (!agtsToActivate.isEmpty()) update agtsToActivate;
        if (!agreementsToUpdate.isEmpty()) update agreementsToUpdate;
        if (!oldGridIds.isEmpty()) {
            List<AgreementGridTimeline__c> agtsToInactivate = new List<AgreementGridTimeline__c>();
            for (AgreementGridTimeline__c agt : [SELECT Id FROM AgreementGridTimeline__c WHERE Grid__c IN :oldGridIds AND Status__c = :AgreementGridTimelineUtility.AGT_ACTIVE]) {
                agt.Status__c = AgreementGridTimelineUtility.AGT_INACTIVE;
                agtsToInactivate.add(agt);
            }
            if (!agtsToInactivate.isEmpty()) update agtsToInactivate;
        }
    }

    public void finish(Database.BatchableContext bc) {}
}