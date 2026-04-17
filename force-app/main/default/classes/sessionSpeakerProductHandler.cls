public with sharing class sessionSpeakerProductHandler implements ITriggerHandler {

    public static Boolean triggerDisabled = false;

    public void beforeInsert(List<SObject> newItems) {
        List<SessionSpeakerProduct__c> ssps = (List<SessionSpeakerProduct__c>) newItems;
        sessionSpeakerProductService.setPresentationStatusForTopSpeakers(ssps);
        sessionSpeakerProductService.updateSSPName(ssps,null);
    }

    public void beforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, SessionSpeakerProduct__c> newSsps = (Map<Id, SessionSpeakerProduct__c>) newItems;
        Map<Id, SessionSpeakerProduct__c> oldSsps = (Map<Id, SessionSpeakerProduct__c>) oldItems;
        sessionSpeakerProductService.updateSSPName(newSsps.values(),oldSsps);
        sessionSpeakerProductService.handleRequestedPresentationNotifications(newSsps, oldSsps);
    }

    public void beforeDelete(Map<Id, SObject> oldItems) {}

    public void afterInsert(Map<Id, SObject> newItems) {
        Map<Id, SessionSpeakerProduct__c> ssps = (Map<Id, SessionSpeakerProduct__c>) newItems;

        sessionSpeakerProductService.handleRequestedPresentationNotifications(ssps, null);
        sessionSpeakerProductService.updateEventNamesFromSSP(ssps.values());
    }

    public void afterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        Map<Id, SessionSpeakerProduct__c> newSsps = (Map<Id, SessionSpeakerProduct__c>) newItems;
        Map<Id, SessionSpeakerProduct__c> oldSsps = (Map<Id, SessionSpeakerProduct__c>) oldItems;
        customEventSpeakerApprovalService.updateApprovalSlots(oldSsps, newSsps);
        sessionSpeakerProductService.updateEventNamesFromSSP(newSsps.values());

    }

    public void afterDelete(Map<Id, SObject> oldItems) {
        Map<Id, SessionSpeakerProduct__c> oldSsps = (Map<Id, SessionSpeakerProduct__c>) oldItems;
        sessionSpeakerProductService.updateEventNamesFromSSP(oldSsps.values());


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
}