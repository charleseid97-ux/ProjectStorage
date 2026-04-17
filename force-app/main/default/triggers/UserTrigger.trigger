/** 
* @author: Adolphe SONKO
* @date : Création 13/09/2016
* @date : Modification 14/09/2016
* @description : This Class allows to manage triggers in user entity.
*/

trigger UserTrigger on User (before insert, after insert, before update, after update) {
    
    
    if(!PAD.byPassUserTriggerHandler){
        
        // before insert
        if(Trigger.isInsert && Trigger.isBefore){
            if(PAD.canTrigger('UserBeforeInsert')){
                //SM005_UserTriggerHandler.onBeforeInsert(Trigger.new);
                for(User u : Trigger.new){
                    // if BusinessDevelopmentRegions__c is not empty --> set value in a technical field
                    if(!ObjectUtil.isEmpty(u.BusinessDevelopmentRegions__c)){
                        Set_BusinessDevelopmentRegions_Value(u, u.BusinessDevelopmentRegions__c); 
                    }  
                }       
            }
        } 
        
        // before update      
        if(Trigger.isUpdate && Trigger.isBefore){
            if(PAD.canTrigger('UserBeforeUpdate')){
                //SM005_UserTriggerHandler.onBeforeUpdate(Trigger.new, Trigger.oldMap);  
                for(User u : Trigger.new){
                    // if BusinessDevelopmentRegions__c is not empty & updated --> set value in a technical field
                    if(u.BusinessDevelopmentRegions__c != Trigger.oldMap.get(u.Id).BusinessDevelopmentRegions__c && !ObjectUtil.isEmpty(u.BusinessDevelopmentRegions__c)){        
                        Set_BusinessDevelopmentRegions_Value(u, u.BusinessDevelopmentRegions__c);      		
                    }
                }       
            }
        }

        //end
    }
    
    /**
* @author: Stéphane Trotto
* @date : Création 14/09/2016
* @date : Modification 14/09/2016
* @description : This method
* @param : User user This parameter is the the new triggered user.
* @param : String BusinessRegionValues This parameter represent the Business Developer Regions of the user. 
* @return : N/A.
*/
    public static void Set_BusinessDevelopmentRegions_Value(User user, String BusinessDeveloperRegions){

        user.TECH_TextBusinessDevelopmentRegions__c= BusinessDeveloperRegions;
    }
}