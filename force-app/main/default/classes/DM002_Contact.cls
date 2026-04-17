/** 
* @author: Pape DIOUF
* @date : Création 03/08/2016
* @date : Modification 03/08/2016
* @description : this Class allow to manage all database operations (such as select requests and dml) with Salesforce.com .
*/
public class DM002_Contact {
    
    private static String CLASS_NAME = 'DM002_Contact';
    private static final String ALL_FIELDS = ObjectUtil.constructFieldListForQueryFrom('Contact');
    
    /**
     * @author : Pape DIOUF
     * @date : Création 03/08/2016
	 * @date : Modification 03/08/2016 
     * @description : This method performs an SQL query on the contact to repatriate its data from an ID list.
     * @param : Set<id> ContactIds This parameter is a list of unique identifiers of contact.
     * @return : List<Contact> The returned item is a list of Contacts.
     */  
    public static List<Contact> getListByIds(Set<id> ContactIds){
        
        String methodName = 'getListByIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactIds] :' + ContactIds);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Contact WHERE Id IN: ContactIds';    
        List<Contact> listContacts = new List<Contact>((List<Contact>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }
    
    
    /**
     * @author : Pape DIOUF
     * @date : Création 03/08/2016
	 * @date : Modification 03/08/2016 
     * @description : This method performs an SQL query on the contact to repatriate its data from a Sun ID list.
     * @param : Set<String> ContactTechSunIds This parameter is a list of unique Sun identifiers of contact.
     * @return : List<Contact> The returned item is a list of Contacts.
     */  
  /*  public static List<Contact> getListByTechSunIds(Set<String> ContactTechSunIds){
        
        String methodName = 'getListByTechSunIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactTechSunIds] :' + ContactTechSunIds);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Contact WHERE TECH_ContactTechSUNID__c IN: ContactTechSunIds';    
        List<Contact> listContacts = new List<Contact>((List<Contact>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }  */
    
     public static List<Contact> getListByTechSunIds(Set<Integer> ContactTechSunIds){
        
        String methodName = 'getListByTechSunIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactTechSunIds] :' + ContactTechSunIds);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Contact WHERE Technical_ID__c IN: ContactTechSunIds';    
        List<Contact> listContacts = new List<Contact>((List<Contact>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }
    
    
    /**
     * @author : Pape DIOUF
     * @date : Création 03/08/2016
	 * @date : Modification 03/08/2016 
     * @description : This method performs an SQL query on the contact to repatriate its data from a Website ID list.
     * @param : Set<String> ContactWebSiteIds This parameter is a list of unique Website identifiers of contact.
     * @return : List<Contact> The returned item is a list of Contacts.
     */  
    public static List<Contact> getListByTechWebSiteIds(Set<String> ContactWebSiteIds){
        
        String methodName = 'getListByTechWebSiteIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactWebSiteIds] :' + ContactWebSiteIds);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Contact WHERE TECH_WebSiteID__c IN: ContactWebSiteIds';    
        List<Contact> listContacts = new List<Contact>((List<Contact>)Database.query(soqlQuery));
        
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
	/*    public static List<Contact> getListByOneOfSfIds(Set<String> ContactWebSiteIds){
        
        String methodName = 'getListByOneOfSfIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactWebSiteIds] :' + ContactWebSiteIds);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Contact WHERE Technical_ID__c IN: ContactWebSiteIds or TECH_WebSiteID__c IN: ContactWebSiteIds or Id IN: ContactWebSiteIds ';    
        List<Contact> listContacts = new List<Contact>((List<Contact>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    } */   
    
    
    /**
     * @author : Pape DIOUF
     * @date : Création 03/08/2016
	 * @date : Modification 03/08/2016 
     * @description : This method performs an SQL query on the contact to repatriate its data from a Professional Email list.
     * @param : Set<String> ContactProfessionalEmails This parameter is a list of Professional Email of contact.
     * @return : List<Contact> The returned item is a list of Contacts.
     */
    public static List<Contact> getListByProfessionalEmails_WithoutProSpace(Set<String> ContactProfessionalEmails){
        
        String methodName = 'getListByProfessionalEmails_WithoutProSpace';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactProfessionalEmails] :' + ContactProfessionalEmails);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Contact WHERE Email IN: ContactProfessionalEmails and WebsiteRole__c != \'ProSpace\' and WebsiteRole__c != \'ProSpace Temp\' order by CreatedDate desc';    
        List<Contact> listContacts = new List<Contact>((List<Contact>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }   
    
    /**
     * @author : Pape DIOUF
     * @date : Création 03/08/2016
	 * @date : Modification 03/08/2016 
     * @description : This method performs an SQL query on the contact to repatriate its data from a Personal Email list.
     * @param : Set<String> ContactPersonalEmails This parameter is a list of Personal Email of lead.
     * @return : List<Contact> The returned item is a list of Contacts.
     */
    public static List<Contact> getListByPersonalEmails_WithoutProSpace(Set<String> ContactPersonalEmails){
        
        String methodName = 'getListByPersonalEmails_WithoutProSpace';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactPersonalEmails] :' + ContactPersonalEmails);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Contact WHERE PersonalEmail__c IN: ContactPersonalEmails and WebsiteRole__c != \'ProSpace\' and WebsiteRole__c != \'ProSpace Temp\' order by CreatedDate desc';    
        List<Contact> listContacts = new List<Contact>((List<Contact>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }
    
    
    
    /**
     * @author : Pape DIOUF
     * @date : Création 03/08/2016
	 * @date : Modification 03/08/2016 
     * @description : This method performs an SQL query on the contact to repatriate its data from a Team Email list.
     * @param : Set<String> ContactTeamEmails This parameter is a list of Team Email of lead.
     * @return : List<Contact> The returned item is a list of Contacts.
     */
    public static List<Contact> getListByTeamEmails_WithoutProSpace(Set<String> ContactTeamEmails){
        
        String methodName = 'getListByTeamEmails_WithoutProSpace';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactTeamEmails] :' + ContactTeamEmails);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Contact WHERE TeamEmail__c IN: ContactTeamEmails and WebsiteRole__c != \'ProSpace\' and WebsiteRole__c != \'ProSpace Temp\' order by CreatedDate desc';    
        List<Contact> listContacts = new List<Contact>((List<Contact>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listContacts);
        return listContacts; 
    }
    
/*  public static List<Contact> getAllContacts(){        
        String methodName = 'getAllContacts';    
          
        String soqlQuery = 'SELECT '+ ALL_FIELDS +' FROM Contact ';    
         
        List<Contact> listcontacts = new List<Contact>((List<Contact>)Database.query(soqlQuery));
           
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listcontacts);
        return listcontacts; 
    } */
    
  public static List<Contact> getListContactsFromEmails(List<String> listEmails){        
        String methodName = 'getListContactFsFromEmails';    
          
        String soqlQuery = 'SELECT Id, Email,LastName,FirstName,  PersonalEmail__c  FROM Contact WHERE Email IN: listEmails or PersonalEmail__c IN: listEmails';    
         
        List<Contact> listcontacts = new List<Contact>((List<Contact>)Database.query(soqlQuery));
           
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listcontacts);
        return listcontacts; 
    }
       
     public static String getFromgetTechnicalIdById(list<String> ContactId){
        
        String methodName = 'getFromgetTechnical_ID__cById';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactId] :' + ContactId);
        
        String soqlQuery = 'SELECT Technical_ID__c FROM Contact WHERE Id IN: ContactId';    
        List<Contact> listcontacts = new List<Contact>((List<Contact>)Database.query(soqlQuery));
        
        Contact returnContact = listcontacts.get(0);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + returnContact);
        return String.valueof(returnContact.Technical_ID__c); 
    }
    
     public static Contact getProSpaceProfile(Set<Id> ContactID){
        
        String methodName = 'getProSpaceProfile';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactID] :' + ContactID);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Contact WHERE Id IN: ContactID';    
        List<Contact> listContacts = new List<Contact>((List<Contact>)Database.query(soqlQuery));
        
        Contact tempReturn = listContacts.get(0);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + tempReturn);
        return tempReturn; 
    }
                
        public static Contact getContactByUpdateSubscriber(WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber updateSubscriber){
        
        String methodName = 'getContactByUpdateSubscriber';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[updateSubscriber] :' + updateSubscriber);
        
        String Email = updateSubscriber.Email;
        String FirstName = updateSubscriber.FirstName; 
        String LastName = updateSubscriber.LastName;    
            
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Contact WHERE (Email =:Email or PersonalEmail__c =:Email) and FirstName =:FirstName and LastName =:LastName';    
        List<Contact> listContacts = new List<Contact>((List<Contact>)Database.query(soqlQuery));
        
       if(listContacts != null && listContacts.size() > 0){
           Contact tempReturn = listContacts.get(0);
           
           ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + tempReturn);
        	return tempReturn;
       }
        
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + null);
        return null; 
    }
}