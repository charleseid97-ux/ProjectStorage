/** ──────────────────────────────────────
 * @description Mirrors the native Salesforce Standard Approval Process (ProcessInstance/
 *              ProcessInstanceStep/ProcessInstanceWorkitem) for a first Grid onto the custom
 *              approval objects (CustomApproval__c/CustomApprovalStep__c), so the custom
 *              approval history UI shows progress/final state for first-grid approvals that
 *              actually run through the standard Salesforce approval process.
 *              Runs "without sharing" because it must read/update CustomApproval__c
 *              (OWD Private, no sharing rules) regardless of which non-admin user's
 *              transaction enqueued it - e.g. the approver finalizing the approval is rarely
 *              the same user (or in the same role hierarchy) as the original submitter who
 *              owns the earlier CustomApproval__c record. Under "with sharing" a mismatch
 *              between submitter/approver caused the existing record to be invisible to the
 *              approver, so a duplicate CustomApproval__c was created instead of updating it.
 * @author Charles EID
 ────────────────────────────────────── */
public without sharing class GridStandardApprovalMirrorQueueable implements Queueable {
    private Map<Id, Id>     progressMap;
    private Map<Id, String> progressLabels;
    private Map<Id, Id>     finalMap;

    public GridStandardApprovalMirrorQueueable(Map<Id, Id> progressMap, Map<Id, String> progressLabels, Map<Id, Id> finalMap) {
        this.progressMap    = progressMap;
        this.progressLabels = progressLabels;
        this.finalMap       = finalMap;
    }

    public void execute(QueueableContext ctx) {
        if (!progressMap.isEmpty()) syncFirstGridApprovalProgress(progressMap, progressLabels);
        if (!finalMap.isEmpty())    finalizeFirstGridApprovalMirror(finalMap);
    }

    private static void syncFirstGridApprovalProgress(Map<Id, Id> agreementToGridMap, Map<Id, String> pendingStepLabels) {
        Map<Id, Id> piIdToAgrId = new Map<Id, Id>();
        Map<Id, Id> agrIdToPiId = new Map<Id, Id>();
        for (ProcessInstance pi : [SELECT Id, TargetObjectId FROM ProcessInstance
                                    WHERE TargetObjectId IN :agreementToGridMap.keySet()
                                      AND Status = 'Pending'
                                    ORDER BY CreatedDate DESC]) {
            if (!agrIdToPiId.containsKey(pi.TargetObjectId)) {
                agrIdToPiId.put(pi.TargetObjectId, pi.Id);
                piIdToAgrId.put(pi.Id, pi.TargetObjectId);
            }
        }

        Map<Id, List<ProcessInstanceStep>>     stepsByPi     = new Map<Id, List<ProcessInstanceStep>>();
        Map<Id, List<ProcessInstanceWorkitem>> workitemsByPi = new Map<Id, List<ProcessInstanceWorkitem>>();
        for (ProcessInstanceStep pis : [SELECT Id, ProcessInstanceId, StepStatus, Comments, CreatedDate,
                                               ActorId, Actor.Name, OriginalActorId, OriginalActor.Name
                                        FROM ProcessInstanceStep
                                        WHERE ProcessInstanceId IN :piIdToAgrId.keySet()
                                        ORDER BY CreatedDate ASC]) {
            if (!stepsByPi.containsKey(pis.ProcessInstanceId)) stepsByPi.put(pis.ProcessInstanceId, new List<ProcessInstanceStep>());
            stepsByPi.get(pis.ProcessInstanceId).add(pis);
        }
        for (ProcessInstanceWorkitem wk : [SELECT Id, ProcessInstanceId, ActorId, Actor.Name, OriginalActorId, OriginalActor.Name
                                           FROM ProcessInstanceWorkitem
                                           WHERE ProcessInstanceId IN :piIdToAgrId.keySet()]) {
            if (!workitemsByPi.containsKey(wk.ProcessInstanceId)) workitemsByPi.put(wk.ProcessInstanceId, new List<ProcessInstanceWorkitem>());
            workitemsByPi.get(wk.ProcessInstanceId).add(wk);
        }

        // Build approvalId map — bulk query then bulk insert for new records
        Set<String> allGridIdStrs = new Set<String>();
        for (Id agrId : agreementToGridMap.keySet()) allGridIdStrs.add(String.valueOf(agreementToGridMap.get(agrId)));

        Map<String, Id> approvalIdByGridId = new Map<String, Id>();
        for (CustomApproval__c ca : [SELECT Id, TargetRecordId__c FROM CustomApproval__c
                                      WHERE TargetRecordId__c IN :allGridIdStrs
                                        AND ProcessDeveloperName__c = 'AgreementStandardApproval'
                                        AND Status__c = 'Pending']) {
            approvalIdByGridId.put(ca.TargetRecordId__c, ca.Id);
        }

        List<CustomApproval__c> newCas     = new List<CustomApproval__c>();
        List<String>            newCaGrids = new List<String>();
        for (Id agrId : agreementToGridMap.keySet()) {
            String gridIdStr = String.valueOf(agreementToGridMap.get(agrId));
            if (!approvalIdByGridId.containsKey(gridIdStr)) {
                newCas.add(CustomApprovalHistoryUtility.createCustomApproval(gridIdStr, 'AgreementStandardApproval', 'Pending', null, null, null, true, null));
                newCaGrids.add(gridIdStr);
            }
        }
        if (!newCas.isEmpty()) {
            insert newCas;
            for (Integer i = 0; i < newCas.size(); i++) approvalIdByGridId.put(newCaGrids[i], newCas[i].Id);
        }

        delete [SELECT Id FROM CustomApprovalStep__c WHERE CustomApproval__c IN :approvalIdByGridId.values()];

        List<CustomApprovalStep__c> allSteps = new List<CustomApprovalStep__c>();
        for (Id agrId : agreementToGridMap.keySet()) {
            String gridIdStr  = String.valueOf(agreementToGridMap.get(agrId));
            Id     approvalId = approvalIdByGridId.get(gridIdStr);
            if (approvalId == null) continue;
            Id piId = agrIdToPiId.get(agrId);
            allSteps.addAll(buildProgressSteps(approvalId, pendingStepLabels.get(agrId),
                piId != null ? stepsByPi.get(piId) : null,
                piId != null ? workitemsByPi.get(piId) : null));
        }
        if (!allSteps.isEmpty()) insert allSteps;
    }

    private static List<CustomApprovalStep__c> buildProgressSteps(Id approvalId, String pendingLabel,
        List<ProcessInstanceStep> piSteps, List<ProcessInstanceWorkitem> piWorkitems) {

        List<CustomApprovalStep__c> steps = new List<CustomApprovalStep__c>();
        if (piSteps != null) {
            for (ProcessInstanceStep pis : piSteps) {
                Boolean isUser         = String.valueOf(pis.ActorId).startsWith('005');
                String  stepStatus     = mapStandardStepStatus(pis.StepStatus);
                String  assignedToId   = String.valueOf(pis.ActorId);
                String  assignedName   = pis.Actor?.Name;
                String  origId         = pis.OriginalActorId != null ? String.valueOf(pis.OriginalActorId) : assignedToId;
                String  origName       = pis.OriginalActor?.Name != null ? pis.OriginalActor.Name : assignedName;
                Id      actualApprover = isUser && (pis.StepStatus == 'Approved' || pis.StepStatus == 'Rejected') ? pis.ActorId : null;
                steps.add(CustomApprovalHistoryUtility.createCustomApprovalStep(approvalId, pis.StepStatus, pis.StepStatus, stepStatus, false, assignedToId, assignedName, origId, origName, actualApprover, pis.CreatedDate, pis.Comments, null));
            }
        }
        if (piWorkitems != null) {
            for (ProcessInstanceWorkitem wk : piWorkitems) {
                String assignedToId = String.valueOf(wk.ActorId);
                String assignedName = wk.Actor?.Name;
                String origId       = wk.OriginalActorId != null ? String.valueOf(wk.OriginalActorId) : assignedToId;
                String origName     = wk.OriginalActor?.Name != null ? wk.OriginalActor.Name : assignedName;
                steps.add(CustomApprovalHistoryUtility.createCustomApprovalStep(approvalId, pendingLabel, pendingLabel, 'Pending', true, assignedToId, assignedName, origId, origName, null, null, null, null));
            }
        }
        return steps;
    }

    private static void finalizeFirstGridApprovalMirror(Map<Id, Id> agreementToGridMap) {
        Map<Id, Id> piIdToAgrId = new Map<Id, Id>();
        Map<Id, Id> agrIdToPiId = new Map<Id, Id>();
        for (ProcessInstance pi : [SELECT Id, TargetObjectId FROM ProcessInstance
                                    WHERE TargetObjectId IN :agreementToGridMap.keySet()
                                      AND Status = 'Approved'
                                    ORDER BY CreatedDate DESC]) {
            if (!agrIdToPiId.containsKey(pi.TargetObjectId)) {
                agrIdToPiId.put(pi.TargetObjectId, pi.Id);
                piIdToAgrId.put(pi.Id, pi.TargetObjectId);
            }
        }

        Map<Id, List<ProcessInstanceStep>> stepsByPi = new Map<Id, List<ProcessInstanceStep>>();
        for (ProcessInstanceStep pis : [SELECT Id, ProcessInstanceId, StepStatus, Comments, CreatedDate,
                                               ActorId, Actor.Name, OriginalActorId, OriginalActor.Name
                                        FROM ProcessInstanceStep
                                        WHERE ProcessInstanceId IN :piIdToAgrId.keySet()
                                        ORDER BY CreatedDate ASC]) {
            if (!stepsByPi.containsKey(pis.ProcessInstanceId)) stepsByPi.put(pis.ProcessInstanceId, new List<ProcessInstanceStep>());
            stepsByPi.get(pis.ProcessInstanceId).add(pis);
        }

        // Build approvalId map — bulk query then bulk insert/update for new/existing records
        Set<String> allGridIdStrs = new Set<String>();
        for (Id agrId : agreementToGridMap.keySet()) allGridIdStrs.add(String.valueOf(agreementToGridMap.get(agrId)));

        Map<String, CustomApproval__c> existingCaByGridId = new Map<String, CustomApproval__c>();
        for (CustomApproval__c ca : [SELECT Id, Status__c, TargetRecordId__c FROM CustomApproval__c
                                      WHERE TargetRecordId__c IN :allGridIdStrs
                                        AND ProcessDeveloperName__c = 'AgreementStandardApproval']) {
            existingCaByGridId.put(ca.TargetRecordId__c, ca);
        }

        Map<String, Id>        approvalIdByGridId = new Map<String, Id>();
        List<CustomApproval__c> newCas            = new List<CustomApproval__c>();
        List<String>            newCaGrids        = new List<String>();
        List<CustomApproval__c> casToUpdate       = new List<CustomApproval__c>();

        for (Id agrId : agreementToGridMap.keySet()) {
            String gridIdStr = String.valueOf(agreementToGridMap.get(agrId));
            if (!existingCaByGridId.containsKey(gridIdStr)) {
                newCas.add(CustomApprovalHistoryUtility.createCustomApproval(gridIdStr, 'AgreementStandardApproval', 'Approved', null, null, null, true, null));
                newCaGrids.add(gridIdStr);
            } else {
                CustomApproval__c ca = existingCaByGridId.get(gridIdStr);
                approvalIdByGridId.put(gridIdStr, ca.Id);
                if (ca.Status__c != 'Approved') {
                    ca.Status__c = 'Approved';
                    casToUpdate.add(ca);
                }
            }
        }
        if (!newCas.isEmpty()) {
            insert newCas;
            for (Integer i = 0; i < newCas.size(); i++) approvalIdByGridId.put(newCaGrids[i], newCas[i].Id);
        }
        if (!casToUpdate.isEmpty()) update casToUpdate;

        delete [SELECT Id FROM CustomApprovalStep__c WHERE CustomApproval__c IN :approvalIdByGridId.values()];

        List<CustomApprovalStep__c> allSteps = new List<CustomApprovalStep__c>();
        for (Id agrId : agreementToGridMap.keySet()) {
            String gridIdStr  = String.valueOf(agreementToGridMap.get(agrId));
            Id     approvalId = approvalIdByGridId.get(gridIdStr);
            Id     piId       = agrIdToPiId.get(agrId);
            if (approvalId == null || piId == null) continue;
            allSteps.addAll(buildProgressSteps(approvalId, null, stepsByPi.get(piId), null));
        }
        if (!allSteps.isEmpty()) insert allSteps;
    }

    private static String mapStandardStepStatus(String sfStatus) {
        if (sfStatus == 'Approved')    return 'Approved';
        if (sfStatus == 'Rejected')    return 'Rejected';
        if (sfStatus == 'Recalled')    return 'Recalled';
        if (sfStatus == 'Removed')     return 'Recalled';
        if (sfStatus == 'No Response') return 'Recalled';
        return 'Started';
    }
}
