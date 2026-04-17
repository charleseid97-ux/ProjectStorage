/** 
* @author: Pape DIOUF
* @date : Création 03/08/2016
* @date : Modification 13/09/2016
* @description : this Class allow to manage Contact busness entity data preparation .
*/
public class EM002_Contact {
    
    private static String CLASS_NAME = 'EM002_Contact';
    public static final String WEBSITEROLE_PROSPACETEMP = '5';
    public static final String WEBSITEROLE_NOPROFILE = '1';
    public static final String WEBSITEROLE_PROSPACE = '3';
    public static final String TRIALSTATUS1_PROSPACE = '1';
    public static final String TRIALSTATUS5_PROSPACE = '4';
    
    /**
     * @author : Pape DIOUF
     * @date : Création 03/08/2016
	 * @date : Modification 03/08/2016 
     * @description : This method performs an SQL query on the Contact to repatriate its data from an ID list.
     * @param : Set<id> ContactIds This parameter is a list of unique identifiers of contact.
     * @return : List<Contact> The returned item is a list of Contacts.
     */  
    public static List<Contact> getListByIds(Set<id> ContactIds){
        
        String methodName = 'getListByIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactIds] :' + ContactIds);
        
        List<Contact> listContacts = DM002_Contact.getListByIds(ContactIds);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }
    
    
    /**
     * @author : Pape DIOUF
     * @date : Création 03/08/2016
	 * @date : Modification 03/08/2016 
     * @description : This method performs an SQL query on the contact to repatriate its data from a Sun ID list.
     * @param : Set<String> ContactTechSunIds This parameter is a list of unique identifiers of contact.
     * @return : List<Contact> The returned item is a list of Contacts.
     */  
 /*   public static List<Contact> getListByTechSunIds(Set<String> ContactTechSunIds){
        
        String methodName = 'getListByTechSunIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactTechSunIds] :' + ContactTechSunIds);
        
        List<Contact> listContacts = DM002_Contact.getListByTechSunIds(ContactTechSunIds);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }  */
    
      public static List<Contact> getListByTechSunIds(Set<Integer> ContactTechSunIds){
        
        String methodName = 'getListByTechSunIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactTechSunIds] :' + ContactTechSunIds);
        
        List<Contact> listContacts = DM002_Contact.getListByTechSunIds(ContactTechSunIds);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }
    
    
    /**
     * @author : Pape DIOUF
     * @date : Création 03/08/2016
	 * @date : Modification 03/08/2016 
     * @description : This method performs an SQL query on the contact to repatriate its data from a Web Site ID list.
     * @param : Set<String> ContactWebSiteIds This parameter is a list of unique identifiers of contact.
     * @return : List<Contact> The returned item is a list of Contacts
     */  
    public static List<Contact> getListByTechWebSiteIds(Set<String> ContactWebSiteIds){
        
        String methodName = 'getListByWebSiteIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactWebSiteIds] :' + ContactWebSiteIds);
        
        List<Contact> listContacts = DM002_Contact.getListByTechWebSiteIds(ContactWebSiteIds);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }
    
    
    
    /**
     * @author : Pape DIOUF
     * @date : Création 03/08/2016
	 * @date : Modification 03/08/2016 
     * @description : This method performs an SQL query on the contact to repatriate its data from a Website ID list.
     * @param : Set<String> ContactWebSiteIds This parameter is a list of unique Website identifiers of Contact.
     * @return : List<Contact> The returned item is a list of Contacts.
     */  
 /*   public static List<Contact> getListByOneOfSfIds(Set<String> ContactWebSiteIds){
        
        String methodName = 'getListByOneOfSfIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactWebSiteIds] :' + ContactWebSiteIds);
        
        List<Contact> listContacts = DM002_Contact.getListByOneOfSfIds(ContactWebSiteIds);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    } */
    
    
    
    
    /**
     * @author : Pape DIOUF
     * @date : Création 03/08/2016
	 * @date : Modification 03/08/2016 
     * @description : This method performs an SQL query on the contact to repatriate its data from a Professional Email list.
     * @param : Set<String> ContactProfessionalEmails This parameter is a list of Professional Email of contact.
     * @return : List<Contact> The returned item is a list of Leads.
     */
    public static List<Contact> getListByProfessionalEmails_WithoutProSpace(Set<String> ContactProfessionalEmails){
        
        String methodName = 'getListByProfessionalEmails_WithoutProSpace';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactProfessionalEmails] :' + ContactProfessionalEmails);
            
        List<Contact> listContacts = DM002_Contact.getListByProfessionalEmails_WithoutProSpace(ContactProfessionalEmails);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }
    
    
    
    /**
     * @author : Pape DIOUF
     * @date : Création 03/08/2016
	 * @date : Modification 03/08/2016 
     * @description : This method performs an SQL query on the contact to repatriate its data from a Personal Email list.
     * @param : Set<String> ContactPersonalEmails This parameter is a list of Personal Email of contact.
     * @return : List<Contact> The returned item is a list of Leads.
     */
    public static List<Contact> getListByPersonalEmails_WithoutProSpace(Set<String> ContactPersonalEmails){
        
        String methodName = 'getListByPersonalEmails_WithoutProSpace';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactPersonalEmails] :' + ContactPersonalEmails);
        
        List<Contact> listContacts = DM002_Contact.getListByPersonalEmails_WithoutProSpace(ContactPersonalEmails);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }
    
    
    
    /**
     * @author : Pape DIOUF
     * @date : Création 03/08/2016
	 * @date : Modification 03/08/2016 
     * @description : This method performs an SQL query on the contact to repatriate its data from a Team Email list.
     * @param : Set<String> ContactTeamEmails This parameter is a list of Team Email of contact.
     * @return : List<Contact> The returned item is a list of Leads.
     */
    public static List<Contact> getListByTeamEmails_WithoutProSpace(Set<String> ContactTeamEmails){
        
        String methodName = 'getListByTeamEmails_WithoutProSpace';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactTeamEmails] :' + ContactTeamEmails);
        
        List<Contact> listContacts = DM002_Contact.getListByTeamEmails_WithoutProSpace(ContactTeamEmails);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }
    
    
     /**
     * @author : Briag GUEMARD 
     * @date : Création 07/03/2017
	 * @date : Modification 07/03/2017 
     * @description : This method add a Profile to the contact 
     * @param : Contact
     * @return :Contact
     */
    
     public static Contact setProfile(Contact con){
        
        String methodName = 'setProfile';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Contact] :' + con);
        
        If (con.WebsiteRole__c == null)
        {
        	con.WebsiteRole__c =WEBSITEROLE_PROSPACETEMP;
        	con.TrialStatus__c =WEBSITEROLE_PROSPACETEMP;
        }
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + con);
        return con; 
    }
    
    public static String getTechnicalIDById(String contactId){
      
      String methodName = 'getTechnical_ID__cById';    
      
      
      ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[contactId] :' + contactId);
      
      list<String> lTemp= new List<String>();
      
      lTemp.add(contactId);
      String returnContact = DM002_Contact.getFromgetTechnicalIdById(lTemp) ;
            
      ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + returnContact);  
      
      return returnContact; 
    }
    
     /**
     * @author : Briag GUEMARD 
     * @date : Création 30/03/2017
	 * @date : Modification 30/03/2017 
     * @description : This method reset the check box after Reset website Password 
     * @param : Contact
     * @return : -
     */
    
    public static void updateAfterReset(Contact con){
    	   String methodName = 'updateAfterReset';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Contact] :' + con);
        
        con.Website_Reset_Password__c=false;
        
        update con;
    	
    }
    
    
/*    public static List<Contact> getAllContacts(){
        
        String methodName = 'getAllContacts';    
    //    ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactTeamEmails] :' + ContactTeamEmails);
        
        List<Contact> listContacts = DM002_Contact.getAllContacts();
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }*/

   public static List<Contact> getListContactsFromEmails(List<String> listEmails){
        
        String methodName = 'getListContactFsFromEmails';    
    //    ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactTeamEmails] :' + ContactTeamEmails);
        
        List<Contact> listContacts = DM002_Contact.getListContactsFromEmails(listEmails);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }
    
    public static Boolean getProSpaceProfile(Set<Id> ContactIds){
    	
    	String methodName = 'getProSpaceProfile';  
    	Boolean returnBool = false;
    	Contact tempContact = DM002_Contact.getProSpaceProfile(ContactIds);
    	if (tempContact.WebsiteRole__c == WEBSITEROLE_PROSPACETEMP || tempContact.WebsiteRole__c == WEBSITEROLE_PROSPACE){
    		returnBool = true;
    	}
    	
    	return returnBool;    	
    	
    }
    
    public static Contact getContactByUpdateSubscriber(WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber updateSubscriber)
        {
            String methodName = 'getContactByUpdateSubscriber';  
        
            Contact contact = DM002_Contact.getContactByUpdateSubscriber(updateSubscriber);
        
            ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + contact);
            return contact; 
        }

}