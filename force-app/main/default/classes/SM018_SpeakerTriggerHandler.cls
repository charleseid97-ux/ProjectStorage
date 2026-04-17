/** 
* @author: Adolphe SONKO
* @date : Creation 07/04/2017
* @date : Modification 07/04/2017
* @description : This Class allows to handle trigger events in speaker entity.
*/

public class SM018_SpeakerTriggerHandler {
    
	   private static String  CLASS_NAME = SM018_SpeakerTriggerHandler.class.getName();
    
       public static void onBeforeInsert(List<Speaker__c> speakers){
       	
       	
            String methodName = 'onBeforeInsert';  
            ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [campaigns] : ' + speakers);
            
            List<String> schedule_Key_EventIds = new List<String>();
            List<Campaign> listCampaignLinkedToSpeakers = new List<Campaign>();
             
            for(Speaker__c s : speakers){
                if(s.Schedule_Key_Event__c != null) {
                    schedule_Key_EventIds.add(s.Schedule_Key_Event__c);
                }
            }    
            Boolean testbool = False;
            if(schedule_Key_EventIds != null && schedule_Key_EventIds.size() > 0)
            {
                listCampaignLinkedToSpeakers = EM027_Speaker.getEventListsByScheduleId(schedule_Key_EventIds);
                if(listCampaignLinkedToSpeakers != null && listCampaignLinkedToSpeakers.size()>0){
                for(Speaker__c s : speakers){
                       for(Campaign camp :listCampaignLinkedToSpeakers){
                           if(s.Schedule_Key_Event__c == camp.TECH_ID_Schedule__c){
                               testbool = true;
                               system.debug('BGU ta vu testbool'+testbool);
                               s.Campaign__c = camp.Id;
                           }
                       }	 
                   } 
                }
            }
           
           if (testbool){
               system.debug('BGU ta vu '+speakers);
           }
           
       } 
    
    
     public static void onBeforeUpdate(List<Speaker__c> speakers, Map<Id, Speaker__c> oldSpeakers){
        
        String methodName = 'onBeforeUpdate';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [speakers] : ' + speakers);
        
        List<String> schedule_Key_EventIds = new List<String>();
        List<Campaign> listCampaignLinkedToSpeakers = new List<Campaign>();

        for(Speaker__c s : speakers){
        	if(s.Schedule_Key_Event__c != oldSpeakers.get(s.Id).Schedule_Key_Event__c){        
        		schedule_Key_EventIds.add(s.Schedule_Key_Event__c);
        	}
        } 
        
        if(schedule_Key_EventIds != null && schedule_Key_EventIds.size() > 0)
        {
            listCampaignLinkedToSpeakers = EM027_Speaker.getEventListsByScheduleId(schedule_Key_EventIds);
            if(listCampaignLinkedToSpeakers != null && listCampaignLinkedToSpeakers.size() > 0){
                for(Speaker__c s : speakers){
                    for(Campaign camp :listCampaignLinkedToSpeakers){
                       if(s.Schedule_Key_Event__c == camp.TECH_ID_Schedule__c){
                             s.Campaign__c = camp.Id;
                       }
                    }	 
                } 
         	}
        }
            
        
    }
  
}