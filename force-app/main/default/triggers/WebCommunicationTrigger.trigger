/**
* @author: Noor Goolamnabee
* @date : 12/07/2019
* @description : Trigger for Web communication
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 12-JUL-2019  JLC         1.0    Init
*
*/
trigger WebCommunicationTrigger on Web_Communication__c (before insert, before update, after insert, after delete) {
    
    if ((!PAD.byPassWebCommunicationTriggerHandler))
    {
        
        
        if(trigger.isBefore){
            if(trigger.isInsert){
                if(PAD.canTrigger('WebCommunicationBeforeInsertTrigger')){
                    SM029_WebCommunicationTriggerHandler.onBeforeInsert(Trigger.new);
                }
            }
            if(trigger.isUpdate){
                if(PAD.canTrigger('WebCommunicationBeforeUpdateTrigger')){     
                    SM029_WebCommunicationTriggerHandler.onBeforeInsert(Trigger.new);
                }
            }
        }
        
        if(trigger.isAfter){
            
            if(trigger.isInsert){
                if(PAD.canTrigger('WebCommunicationAfterInsertTrigger') &&
                        (UserInfo.getUserId() != Label.WebsiteProspaceId)){//do not trigger for website user

                    SM029_WebCommunicationTriggerHandler.onAfterInsert(Trigger.new);

                }
            }
            if(trigger.isDelete){
                if(PAD.canTrigger('WebCommunicationAfterDeleteTrigger') &&
                        (UserInfo.getUserId() != Label.WebsiteProspaceId)){//do not trigger for website user
                    SM029_WebCommunicationTriggerHandler.onAfterDelete(Trigger.old);
                }
            }
        }        
    }    
}