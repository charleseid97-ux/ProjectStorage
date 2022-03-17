trigger CampaignTrigger on Campaign (after insert, after update, after undelete, before delete, before insert) {

    //Noor Decommissioning Aventri Date : 02/03/2021
   /* if (!PAD.byPassCampaignTriggerHandler) {

        if (Trigger.isInsert && Trigger.isAfter) {

            //BGU Test merge 27/02/2017
            system.debug('isInsert && isAfter Campaign ');

            if (PAD.canTrigger('CampaignAfterInsert')) {

                system.debug('BGU CampaignAfterInsert');
                SM014_CampaignTriggerHandler.onAfterInsert(Trigger.new);
            }
        }

        if (Trigger.isUpdate && Trigger.isAfter) {

            system.debug('Trigger.isUpdate && Trigger.isAfter ');

            if (PAD.canTrigger('CampaignAfterUpdate')) {
                system.debug('BGU Trigger.isUpdate && Trigger.isAfter');
                //launchupdateToEtouhces
                SM014_CampaignTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
            }
        }
    }*/
}