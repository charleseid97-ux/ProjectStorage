/** ──────────────────────────────────────
 * @description Trigger handler for Disclaimer__c.
 * @author Charles EID
 * @testClass [TBD]
 * @coverage 90%   [TBD]
────────────────────────────────────── */
public without sharing class DisclaimerTriggerHandler implements ITriggerHandler {
    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) { }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        if (PAD.canTrigger('DisclaimerApprovalLock')) {
            CustomApprovalHistoryUtility.enforceApprovalLock(newItems.values(), oldItems);
        }
    }

    public void BeforeDelete(Map<Id, SObject> oldItems) { }

    public void AfterInsert(Map<Id, SObject> newItems) { }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) { }

    public void AfterDelete(Map<Id, SObject> oldItems) { }

    public void AfterUndelete(Map<Id, SObject> oldItems) { }

    public Boolean isDisabled() {
        if (PAD.canTrigger('DisclaimerTrigger')) {
            return triggerDisabled;
        }
        return true;
    }
}