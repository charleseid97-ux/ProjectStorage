/** 
* @author: Adolphe SONKO
* @modify by:Abderrahmane TRIA
* @date : Création 14/09/2016
* @date : Modification 08/12/2020
* @description : This Class allows to manage triggers in Strategic News entity.
*/

trigger StrategicNewsTrigger on StrategicNews__c (after insert) {
    
    if(!PAD.byPassStrategicNewsTriggerHandler){
        
        // after insert
        if(Trigger.isInsert && Trigger.isAfter){
            if(PAD.canTrigger('StrategicNewsAfterInsert')){            
                SM010_StrategicNewsTriggerHandler.onAfterInsert(Trigger.new);
            }
        }                  
    }
}