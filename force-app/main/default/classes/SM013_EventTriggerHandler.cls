/** 
* @author: Stéphane Trotto
* @date : Création 15/09/2016
* @date : Modification 15/09/2016
* @description : This Class allows to manage triggers in Event entity.
*/

public class SM013_EventTriggerHandler {

    private static String CLASS_NAME = SM013_EventTriggerHandler.class.getName();
       
    /**
     * @author: Stéphane Trotto
	 * @date : Création 15/09/2016
	 * @date : Modification 15/09/2016
     * @description : This method 
     * @param : List<Event> events This parameter is the the new triggered events.
     * @return : N/A.
     */
    public static void onBeforeInsert(List<Event> events){
        
        String methodName = 'onBeforeInsert';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [events] : ' + events);
        
        Set<Id> listWhoIds = new Set<Id>();
        for(Event e : events){
            
            // if (Who = contact) && (What = null) 
            if((!ObjectUtil.isEmpty(e.WhoId) && (e.WhoId).getSObjectType().getDescribe().getName() == 'Contact')
               && ObjectUtil.isEmpty(e.WhatId)){
               
             // OLD code
            //	RetrieveContactMainCompany(e,e.WhoId);
            
            //ASonko fix SOQL Query Limit exception 04/04/2017
                listWhoIds.add(e.WhoId);
            }
        }      	
        
        if(listWhoIds != null && listWhoIds.size() > 0){
             RetrieveContactMainCompany(events, listWhoIds);
        }
    }
    
    /**
     * @author: Stéphane Trotto
	 * @date : Création 15/09/2016
	 * @date : Modification 15/09/2016
     * @description : This method 
     * @param : List<Event> events This parameter is the the new triggered events.
     * @param : Map<Id, Event> oldEvents This parameter is the the old triggered events for callout.
     * @return : N/A.
     */
    public static void onBeforeUpdate(List<Event> events, Map<Id, Event> oldEvents){
        
        String methodName = 'onBeforeUpdate';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [events] : ' + events);
        
        Set<Id> listWhoIds = new Set<Id>();
        
        // if (Who = contact and is changed) && (What = null) 
        for(Event e : events){
        	if(!ObjectUtil.isEmpty(e.WhoId) && (e.WhoId).getSObjectType().getDescribe().getName() == 'Contact' 
               && e.WhoId != oldEvents.get(e.Id).WhoId && ObjectUtil.isEmpty(e.WhatId)){        
        		// OLD code
               //    RetrieveContactMainCompany(e,e.WhoId); 
                //ASonko fix SOQL Query Limit exception 04/04/2017
                listWhoIds.add(e.WhoId);
        	}
        } 
        
        //ASonko fix SOQL Query Limit exception 04/04/2017
        if(listWhoIds != null && listWhoIds.size() > 0){
             RetrieveContactMainCompany(events, listWhoIds);
        }
    }
    
    /**
     * @author: Stéphane Trotto
	 * @date : Création 15/09/2016
	 * @date : Modification 15/09/2016
     * @description : This method 
     * @param : Event events This parameter is the the new triggered events.
     * @param : Id ContactId the Id of the related contact.
     * @return : N/A.
     */
 /*   public static void RetrieveContactMainCompany(Event event, Id ContactId){
        
        String methodName = 'RetrieveContactMainCompany';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [event] : ' + event);
        
        Contact contact = EM002_Contact.getListByIds(new Set<Id>{contactId}).get(0);       
        
        if(!ObjectUtil.isEmpty(contact.AccountId)){
        	
            event.WhatId = contact.AccountId;          
        }      
    } */
    
    /**
     * @author : Adolphe SONKO
     * @date : Création 04/04/2017
	 * @date : Modification 04/04/2017 
     * @description : This method .
     * @param : List<Event> listevents This parameter is the the new triggered events.
     * @return : N/A.
     */  
    
     public static void RetrieveContactMainCompany(List<Event> listEvents, Set<Id> ContactIds){
        
        String methodName = 'RetrieveContactMainCompany';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [listEvents] : ' + listEvents);
        
        List<Contact> listcontacts = EM002_Contact.getListByIds(ContactIds);       
        
         for(Event e :listEvents){
             for(Contact con :listcontacts){
                  if(e.WhoId == con.Id && !ObjectUtil.isEmpty(con.AccountId)){
                        e.WhatId = con.AccountId;          
                  }     
             }
         }
    }
}