/** ──────────────────────────────────────
 * @description Trigger handler for Contact, dispatched via TriggerDispatcher.
 *              Orchestrates SM007_ContactTriggerHandler / OptOutHelper,
 *              preserving the logic previously inlined in ContactTrigger.
 * @author Charles EID
────────────────────────────────────── */
public without sharing class ContactTriggerHandler implements ITriggerHandler {

    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {
        List<Contact> contacts = (List<Contact>) newItems;
        if (!PAD.byPassContactTriggerHandler && PAD.canTrigger('ContactBeforeInsert')) {
            SM007_ContactTriggerHandler.onBeforeInsert(contacts);
        }
    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        if (!PAD.canTrigger('ContactBeforeUpdate') || Pad.SKIP_STRIGGER_MAP.containsKey('ContactBeforeUpdate')) return;

        List<Contact> newContacts = (List<Contact>) newItems.values();
        Map<Id, Contact> oldContacts = (Map<Id, Contact>) oldItems;
        List<Contact> contactStatusList = new List<Contact>();

        for (Contact cn : newContacts) {
            Contact oldCn = oldContacts.get(cn.Id);

            if (String.isNotBlank(cn.Prospace_Status__c) && String.isNotBlank(oldCn.Prospace_Status__c) && cn.Prospace_Status__c != oldCn.Prospace_Status__c) {
                if (UserInfo.getUserId() != Label.WebsiteProspaceId) cn.Synchrostatus__c = 'To be synced';
            }

            if (cn.ContactStatus__c != oldCn.ContactStatus__c) {
                contactStatusList.add(cn);
            }
        }

        SM007_ContactTriggerHandler.onBeforeUpdate(newContacts, oldContacts);
        OptOutHelper.getLastModifiedOptOut(newContacts, oldContacts);

        if (!contactStatusList.isEmpty()) {
            SM007_ContactTriggerHandler.onBeforeUpdateStatus(contactStatusList);
        }

        Pad.SKIP_STRIGGER_MAP.put('ContactBeforeUpdate', 'prevent double execution');
    }

    public void BeforeDelete(Map<Id, SObject> oldItems) { }

    public void AfterInsert(Map<Id, SObject> newItems) {
        if (PAD.canTrigger('ContactAfterInsert') && !Pad.SKIP_STRIGGER_MAP.containsKey('ContactAfterInsert')) {
            SM007_ContactTriggerHandler.onAfterInsert((List<Contact>) newItems.values());
        }
    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        List<Contact> newContacts = (List<Contact>) newItems.values();
        Map<Id, Contact> oldContacts = (Map<Id, Contact>) oldItems;

        if (PAD.canTrigger('ContactAfterUpdate') && !Pad.SKIP_STRIGGER_MAP.containsKey('ContactAfterUpdate')) {
            SM007_ContactTriggerHandler.onAfterUpdate(newContacts, oldContacts);
        }

        if (PAD.canTrigger('ContactSyncWebComOptOut')) {
            OptOutHelper.syncWebCommunicationActivation(newContacts, oldContacts);
        }
    }

    public void AfterDelete(Map<Id, SObject> oldItems) {
        if (PAD.canTrigger('ContactAfterDelete')) {
            SM007_ContactTriggerHandler.onAfterDelete((List<Contact>) oldItems.values());
        }
    }

    public void AfterUndelete(Map<Id, SObject> newItems) { }

    public Boolean isDisabled() {
        return triggerDisabled;
    }
}