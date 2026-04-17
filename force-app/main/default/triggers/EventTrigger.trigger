/** 
* @author: Stéphane Trotto
* @date : Création 15/09/2016
* @date : Modification 15/09/2016
* @description : This Class allows to manage triggers in Event entity.
*/
trigger EventTrigger on Event (before insert, before update) {

    if(!PAD.byPassActivitiesTriggerHandler){
        // before insert
        if(Trigger.isInsert && Trigger.isBefore){
            if(PAD.canTrigger('ActivityBeforeInsert')){
             	SM013_EventTriggerHandler.onBeforeInsert(Trigger.new);
            }
        } 
         
        // before update     
        if(Trigger.isUpdate && Trigger.isBefore){
            if(PAD.canTrigger('ActivityBeforeUpdate')){
             	SM013_EventTriggerHandler.onBeforeUpdate(Trigger.new, Trigger.oldMap);  
            }
        }
    }
}