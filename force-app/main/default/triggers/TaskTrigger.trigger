/** 
* @author: Stéphane Trotto
* @date : Création 15/09/2016
* @date : Modification 15/09/2016
* @description : This Class allows to manage triggers in Task entity.
*/
trigger TaskTrigger on Task (before insert, before update) {

    if(!PAD.byPassActivitiesTriggerHandler){
        // before insert
        if(Trigger.isInsert && Trigger.isBefore){
            if(PAD.canTrigger('ActivityBeforeInsert')){
             	SM012_TaskTriggerHandler.onBeforeInsert(Trigger.new);
            }
        } 
         
        // before update    
        if(Trigger.isUpdate && Trigger.isBefore){
            if(PAD.canTrigger('ActivityBeforeUpdate')){
             	SM012_TaskTriggerHandler.onBeforeUpdate(Trigger.new, Trigger.oldMap);  
            }
        }
    }
    
}