/** 
* @author: Stéphane Trotto
* @date : Création 15/09/2016
* @date : Modification 15/09/2016
* @description : This Class allows to manage triggers in Task entity.
*/

public class SM012_TaskTriggerHandler {

    private static String CLASS_NAME = SM012_TaskTriggerHandler.class.getName();
       
    /**
     * @author: Stéphane Trotto
	 * @date : Création 15/09/2016
	 * @date : Modification 15/09/2016
     * @description : This method 
     * @param : List<Task> tasks This parameter is the the new triggered tasks.
     * @return : N/A.
     */
    public static void onBeforeInsert(List<Task> tasks){
        
        String methodName = 'onBeforeInsert';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [tasks] : ' + tasks);
        
        Set<Id> listWhoIds = new Set<Id>();
        for(Task t : tasks){

            // if (Who = contact) && (What = null) 
            if((!ObjectUtil.isEmpty(t.WhoId) && (t.WhoId).getSObjectType().getDescribe().getName() == 'Contact')
               && ObjectUtil.isEmpty(t.WhatId)){
               
                   // OLD code
            //	RetrieveContactMainCompany(t,t.WhoId);
            
            //ASonko fix SOQL Query Limit exception 12/04/2017
            	listWhoIds.add(t.WhoId);
            } 
        }
        
        if(listWhoIds != null && listWhoIds.size() > 0){
             RetrieveContactMainCompany(tasks, listWhoIds);
        }
    }
    
    /**
     * @author: Stéphane Trotto
	 * @date : Création 15/09/2016
	 * @date : Modification 15/09/2016
     * @description : This method 
     * @param : List<Task> tasks This parameter is the the new triggered tasks.
     * @param : Map<Id, Task> oldTasks This parameter is the the old triggered tasks for callout.
     * @return : N/A.
     */
    public static void onBeforeUpdate(List<Task> tasks, Map<Id, Task> oldTasks){
        
        String methodName = 'onBeforeUpdate';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [tasks] : ' + tasks);
        
        
        Set<Id> listWhoIds = new Set<Id>();
        
        // if (Who = contact and is changed) && (What = null) 
        for(Task t : tasks){
        	if(!ObjectUtil.isEmpty(t.WhoId) && (t.WhoId).getSObjectType().getDescribe().getName() == 'Contact' 
               && t.WhoId != oldTasks.get(t.Id).WhoId && ObjectUtil.isEmpty(t.WhatId)){        
                // OLD code
        		// RetrieveContactMainCompany(t,t.WhoId);  
                   
                //ASonko fix SOQL Query Limit exception 12/04/2017
            	listWhoIds.add(t.WhoId);
        	}
        }  
        
        //ASonko fix SOQL Query Limit exception 12/04/2017
        if(listWhoIds != null && listWhoIds.size() > 0){
             RetrieveContactMainCompany(tasks, listWhoIds);
        }
    }
    
    /**
     * @author: Stéphane Trotto
	 * @date : Création 15/09/2016
	 * @date : Modification 15/09/2016
     * @description : This method 
     * @param : Task task This parameter is the the new triggered task.
     * @param : Id ContactId the Id of the related contact.
     * @return : N/A.
     */
 /*   public static void RetrieveContactMainCompany(Task task, Id ContactId){
        
        String methodName = 'RetrieveContactMainCompany';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [task] : ' + task);
        
        Contact contact = EM002_Contact.getListByIds(new Set<Id>{contactId}).get(0);       
        
        if(!ObjectUtil.isEmpty(contact.AccountId)){
        	
            task.WhatId = contact.AccountId;         
        }      
    }  */
    
        /**
     * @author : Adolphe SONKO
     * @date : Création 12/04/2017
	 * @date : Modification 12/04/2017 
     * @description : This method .
     * @param : List<Task> listTasks This parameter is the the new triggered events.
     * @return : N/A.
     */  
    
     public static void RetrieveContactMainCompany(List<Task> listTasks, Set<Id> ContactIds){
        
        String methodName = 'RetrieveContactMainCompany';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [listTasks] : ' + listTasks);
        
        List<Contact> listcontacts = EM002_Contact.getListByIds(ContactIds);       
        
         for(Task t :listTasks){
             for(Contact con :listcontacts){
                  if(t.WhoId == con.Id && !ObjectUtil.isEmpty(con.AccountId)){
                        t.WhatId = con.AccountId;   
                      	System.debug('ASO Voici l-Id de l-account'+t.WhatId);
                  }     
             }
         }
    }
}