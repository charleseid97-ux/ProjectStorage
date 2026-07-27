public without sharing class sessionSpeakerProductHandler implements ITriggerHandler {

    public static Boolean triggerDisabled = false;

    public void beforeInsert(List<SObject> newItems) {
        List<SessionSpeakerProduct__c> ssps = (List<SessionSpeakerProduct__c>) newItems;

        // Keep only SSPs linked to automated Sessions
        List<SessionSpeakerProduct__c> sspsToProcess = filterAutomatedSSPs(ssps);

        if (sspsToProcess.isEmpty()) return;

        sessionSpeakerProductService.setPresentationStatusForTopSpeakers(sspsToProcess);
        sessionSpeakerProductService.updateSSPName(sspsToProcess, null);
        sessionSpeakerProductService.updateStatus(sspsToProcess, null);
    }

    public void beforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, SessionSpeakerProduct__c> newSsps = (Map<Id, SessionSpeakerProduct__c>) newItems;
        Map<Id, SessionSpeakerProduct__c> oldSsps = (Map<Id, SessionSpeakerProduct__c>) oldItems;

        // Keep only SSPs linked to automated Sessions
        Map<Id, SessionSpeakerProduct__c> newSspsToProcess = filterAutomatedSSPsMap(newSsps);
        Map<Id, SessionSpeakerProduct__c> oldSspsToProcess = filterOldMap(
            oldSsps,
            newSspsToProcess.keySet()
        );

        if (newSspsToProcess.isEmpty()) return;

        sessionSpeakerProductService.updateSSPName(
            newSspsToProcess.values(),
            oldSspsToProcess
        );

        BooklyModificationsManagement.registerSspModificationSessions(
            oldSspsToProcess,
            newSspsToProcess
        );

        sessionSpeakerProductService.handleRequestedPresentationNotifications(
            newSspsToProcess,
            oldSspsToProcess
        );
    }

    public void beforeDelete(Map<Id, SObject> oldItems) {}

    public void afterInsert(Map<Id, SObject> newItems) {
        Map<Id, SessionSpeakerProduct__c> ssps = (Map<Id, SessionSpeakerProduct__c>) newItems;

        // Keep only SSPs linked to automated Sessions
        Map<Id, SessionSpeakerProduct__c> sspsToProcess = filterAutomatedSSPsMap(ssps);

        if (sspsToProcess.isEmpty()) return;

        sessionSpeakerProductService.updateEventNamesFromSSP(sspsToProcess.values());
        BooklyModificationsManagement.handleSessionSpeakerProductInsert(sspsToProcess.values());
    }

    public void afterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, SessionSpeakerProduct__c> newSsps = (Map<Id, SessionSpeakerProduct__c>) newItems;
        Map<Id, SessionSpeakerProduct__c> oldSsps = (Map<Id, SessionSpeakerProduct__c>) oldItems;

        // Keep only SSPs linked to automated Sessions
        Map<Id, SessionSpeakerProduct__c> newSspsToProcess = filterAutomatedSSPsMap(newSsps);
        Map<Id, SessionSpeakerProduct__c> oldSspsToProcess = filterOldMap(
            oldSsps,
            newSspsToProcess.keySet()
        );

        if (newSspsToProcess.isEmpty()) return;
 
        BooklyModificationsManagement.registerSspModificationSessions(
            oldSspsToProcess,
            newSspsToProcess
        );

        BooklyModificationsManagement.isSspModificationNotificationRunning = true;

        try {
            sessionSpeakerProductService.updateEventNamesFromSSP(
                newSspsToProcess.values()
            );

            BooklyModificationsManagement.handleSessionSpeakerProductUpdate(
                oldSspsToProcess,
                newSspsToProcess
            );
        } finally {
            BooklyModificationsManagement.isSspModificationNotificationRunning = false;
        }
    }

    public void afterDelete(Map<Id, SObject> oldItems) {
        Map<Id, SessionSpeakerProduct__c> oldSsps = (Map<Id, SessionSpeakerProduct__c>) oldItems;

        // Keep only SSPs linked to automated Sessions
        Map<Id, SessionSpeakerProduct__c> oldSspsToProcess = filterAutomatedSSPsMap(oldSsps);

        if (oldSspsToProcess.isEmpty()) return;

        sessionSpeakerProductService.updateEventNamesFromSSP(
            oldSspsToProcess.values()
        );

        BooklyModificationsManagement.handleSessionSpeakerProductDelete(oldSspsToProcess.values());
    }

    public void afterUndelete(Map<Id, SObject> oldItems) {
        Map<Id, SessionSpeakerProduct__c> ssps = (Map<Id, SessionSpeakerProduct__c>) oldItems;
    }

    public Boolean isDisabled() {
        if (PAD.canTrigger('sessionSpeakerProductHandler')) {
            return triggerDisabled;
        }

        return true;
    }

    // Filter SSPs linked to automated Sessions only
    private static List<SessionSpeakerProduct__c> filterAutomatedSSPs(
        List<SessionSpeakerProduct__c> ssps
    ) {
        List<SessionSpeakerProduct__c> result = new List<SessionSpeakerProduct__c>();

        // Load automation flags in a single SOQL
        Map<Id, Boolean> automationBySessionId = getAutomationBySessionId(ssps);

        for (SessionSpeakerProduct__c ssp : ssps) {
            if (automationBySessionId.get(ssp.Session__c) != true) {
                result.add(ssp);
            }
        }

        return result;
    }

    // Filter SSP map linked to automated Sessions only
    private static Map<Id, SessionSpeakerProduct__c> filterAutomatedSSPsMap(
        Map<Id, SessionSpeakerProduct__c> ssps
    ) {
        Map<Id, SessionSpeakerProduct__c> result = new Map<Id, SessionSpeakerProduct__c>();

        // Load automation flags in a single SOQL
        Map<Id, Boolean> automationBySessionId = getAutomationBySessionId(
            ssps.values()
        );

        for (Id sspId : ssps.keySet()) {
            SessionSpeakerProduct__c ssp = ssps.get(sspId);

            if (automationBySessionId.get(ssp.Session__c) != true) {
                result.put(sspId, ssp);
            }
        }

        return result;
    }

    // Load Session automation flags with a single query
    private static Map<Id, Boolean> getAutomationBySessionId(
        List<SessionSpeakerProduct__c> ssps
    ) {
        Set<Id> sessionIds = new Set<Id>();

        for (SessionSpeakerProduct__c ssp : ssps) {
            if (ssp.Session__c != null) {
                sessionIds.add(ssp.Session__c);
            }
        }

        Map<Id, Boolean> result = new Map<Id, Boolean>();

        for (Event__c session : [
            SELECT Id, noAutomations__c
            FROM Event__c
            WHERE Id IN :sessionIds
        ]) {
            result.put(session.Id, session.noAutomations__c);
        }

        return result;
    }

    // Keep only old SSPs matching processed records
    private static Map<Id, SessionSpeakerProduct__c> filterOldMap(
        Map<Id, SessionSpeakerProduct__c> oldSsps,
        Set<Id> idsToKeep
    ) {
        Map<Id, SessionSpeakerProduct__c> result = new Map<Id, SessionSpeakerProduct__c>();

        for (Id sspId : idsToKeep) {
            if (oldSsps.containsKey(sspId)) {
                result.put(sspId, oldSsps.get(sspId));
            }
        }

        return result;
    }

    // Collecte les sessions impactees par les SSP.
    private static Set<Id> collectSessionIds(List<SessionSpeakerProduct__c> ssps) {
        Set<Id> sessionIds = new Set<Id>();

        for (SessionSpeakerProduct__c ssp : ssps) {
            if (ssp != null && ssp.Session__c != null) {
                sessionIds.add(ssp.Session__c);
            }
        }

        return sessionIds;
    }
}