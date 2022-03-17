/** 
* @author: 
* @date : Creation 
* @date : Modification 12/02/19 
* @description : manage the the triggers on the contact object
*/
trigger ContactTrigger on Contact (after insert, after update, after undelete, before delete, before insert, before update, after delete) {

    if (!PAD.byPassContactTriggerHandler) {
        //BGU Legacy ID Counter 14/02/2017
        if (Trigger.isInsert && Trigger.isBefore && PAD.canTrigger('ContactBeforeInsert')) {

            system.debug('BGU IS isInsert isBefore');
            ContactTH.onBeforeInsert(Trigger.new);
            SM007_ContactTriggerHandler.onBeforeInsert(Trigger.new);
        }
    }

    if (Trigger.isUpdate && Trigger.isBefore && PAD.canTrigger('ContactBeforeUpdate') && !Pad.SKIP_STRIGGER_MAP.containsKey('ContactBeforeUpdate')) {
        system.debug('BGU IS isUPDATE / isBefore');

        List<Contact> contactStatusList = new List<Contact>();

        for (Contact cn : Trigger.new) {
            if (String.IsNotBlank(trigger.newMap.get(cn.Id).Prospace_Status__c) && String.IsNotBlank(trigger.oldMap.get(cn.Id).Prospace_Status__c) && trigger.newMap.get(cn.Id).Prospace_Status__c != trigger.oldMap.get(cn.Id).Prospace_Status__c) {
                if (UserInfo.getUserId() != Label.WebsiteProspaceId) trigger.newMap.get(cn.Id).Synchrostatus__c = 'To be synced';
            }

            if (trigger.newMap.get(cn.Id).ContactStatus__c != trigger.oldMap.get(cn.Id).ContactStatus__c) {
                contactStatusList.add(cn);
            }

        }

        if (contactStatusList.size() > 0) {
            SM007_ContactTriggerHandler.onBeforeUpdateStatus(contactStatusList);
        }

        Pad.SKIP_STRIGGER_MAP.put('ContactBeforeUpdate', 'prevent double execution');

    }

    // after insert
    if (Trigger.isInsert && Trigger.isAfter && PAD.canTrigger('ContactAfterInsert') && !Pad.SKIP_STRIGGER_MAP.containsKey('ContactAfterInsert')) {
        //BGU Test merge 16/01/2017
        system.debug('isInsert && isAfter legacy ');
        if (PAD.canTrigger('ContactAfterInsert')) {

            system.debug('BGU ContactAfterInsert');
            SM007_ContactTriggerHandler.onAfterInsert(Trigger.new);

        }
    }

    // after update --> for Update & Deactivation
    if (Trigger.isUpdate && Trigger.isAfter && PAD.canTrigger('ContactAfterUpdate') && !Pad.SKIP_STRIGGER_MAP.containsKey('ContactAfterUpdate')) {
        //BGU Test merge 16/01/2017
        system.debug('isUpdate && isAfter legacy ');

        if (PAD.canTrigger('ContactAfterUpdate')) {
            SM007_ContactTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }

    // after delete --> for Delete website contact
    if (Trigger.isDelete && Trigger.isAfter) {

        if (PAD.canTrigger('ContactAfterDelete')) {
            SM007_ContactTriggerHandler.onAfterDelete(Trigger.old);

        }
    }
}