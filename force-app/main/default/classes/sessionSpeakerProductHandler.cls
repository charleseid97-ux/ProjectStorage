public with sharing class sessionSpeakerProductHandler implements ITriggerHandler {

    public static Boolean triggerDisabled = false;

    public void beforeInsert(List<SObject> newItems) {}
    public void beforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {}
    public void beforeDelete(Map<Id, SObject> oldItems) {}

    public void afterInsert(Map<Id, SObject> newItems) {}
    public void afterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {}
    public void afterDelete(Map<Id, SObject> oldItems) {}
    public void afterUndelete(Map<Id, SObject> oldItems) {}

    public Boolean isDisabled() {
        if (PAD.canTrigger('sessionSpeakerProductHandler')) {
            return triggerDisabled;
        }
        return true;
    }
}