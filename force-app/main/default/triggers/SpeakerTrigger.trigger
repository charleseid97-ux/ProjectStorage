/** 
* @author: Adolphe SONKO
* @date : Création 06/04/2017
* @date : Modification 06/04/2017
* @description : This Class allows to manage triggers in speaker entity.
*/

trigger SpeakerTrigger on Speaker__c (before insert, before update) {
    
	if(!PAD.byPassSpeakerTriggerHandler){
		// after insert
        if(Trigger.isInsert && Trigger.isBefore){      
            if(PAD.canTrigger('SpeakerBeforeInsert')){
                SM018_SpeakerTriggerHandler.onBeforeInsert(Trigger.new);       
            }
        }
        
        // after update      
        if(Trigger.isUpdate && Trigger.isBefore){
            if(PAD.canTrigger('onBeforeUpdate')){
             	SM018_SpeakerTriggerHandler.onBeforeUpdate(Trigger.new, Trigger.oldMap);  
            }
        }
    }
}