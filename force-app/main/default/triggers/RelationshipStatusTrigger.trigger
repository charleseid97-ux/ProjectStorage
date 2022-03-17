/** 
* @author: Adolphe SONKO
* @date : Création 13/09/2016
* @date : Modification 13/09/2016
* @description : This Class allows to manage triggers in Relationship Status entity.
*/

trigger RelationshipStatusTrigger on RelationshipStatus__c (after update) {
    
    if(!PAD.byPassRelationshipStatusTriggerHandler){
        
        // after update      
        if(Trigger.isUpdate && Trigger.isAfter){
            if(PAD.canTrigger('RelationshipStatusAfterUpdate')){
                SM009_RelationshipStatusTriggerHandler.onAfterUpdate(Trigger.new);  
            }
        }
    }
}