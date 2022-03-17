/** 
* @author: Pape DIOUF
* @date : Création 03/08/2016
* @date : Modification 03/08/2016
* @description : this Class allow to manage all database operations (such as select requests and dml) with Salesforce.com .
*/
public class DM001_Lead {
    
    private static String CLASS_NAME = 'DM001_Lead';
    private static final String ALL_FIELDS = ObjectUtil.constructFieldListForQueryFrom('Lead');
    
    public static final String WEBSITEROLE_PROSPACETEMP = '5';
    public static final String WEBSITEROLE_NOPROFILE = '1';
    public static final String WEBSITEROLE_PROSPACE = '3';
    public static final String TRIALSTATUS1_PROSPACE = '1';
    public static final String TRIALSTATUS_WAITINGFORVALIDATIONPROSPACE = '5';
    
    /**
     * @author : Pape DIOUF
     * @date : Création 03/08/2016
     * @date : Modification 03/08/2016 
     * @description : This method performs an SQL query on the lead to repatriate its data from an ID list.
     * @param : Set<String> leadIds This parameter is a list of unique identifiers of lead.
     * @return : List<Lead> L'élément retourné est une liste de comptes.
     */    
    public static List<Lead> getListByIds(Set<String> leadIds){
        
        String methodName = 'getListByIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[leadIds] :' + leadIds);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Lead WHERE Id IN: leadIds';    
        List<Lead> listLeads = new List<Lead>((List<Lead>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listLeads);
        return listLeads; 
    }
    
    // BGU 20 Feb 2017 New Process
       
    /*
     public static List<Lead> getListByTechSunIds(Set<String> leadIds){
        
        String methodName = 'getListByTechSunIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[leadIds] :' + leadIds);
        
        
        
        
        system.debug(leadIds);
        
        Integer TechID = integer.valueof(leadIds);
        
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM 	Lead WHERE Technical_ID__c IN: TechID';  
        
        system.debug('BGU query');
        
         system.debug(soqlQuery);
         
        List<Lead> listLeads = new List<Lead>((List<Lead>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listLeads);
        return listLeads; 
    }*/ 
    
     public static List<Lead> getListByTechSunIds(Set<Integer> TechID){
        
        String methodName = 'getListByTechSunIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[TechID] :' + TechID);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM 	Lead WHERE Technical_ID__c IN: TechID';  
        
        system.debug('BGU query');
        
         system.debug(soqlQuery);
         
        List<Lead> listLeads = new List<Lead>((List<Lead>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listLeads);
        return listLeads; 
    }
    
    // By Perso Mail    
    public static List<Lead> getListByPersoMails(Set<String> PersoMails){
        
        String methodName = 'getListByPersoMails';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[PersoMails] :' + PersoMails);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Lead WHERE PersonalEmail__c IN: PersoMails';    
        List<Lead> listLeads = new List<Lead>((List<Lead>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listLeads);
        return listLeads; 
    }
    
    // By Pro Mail    
    public static List<Lead> getListByProMails(Set<String> ProMails){
        
        String methodName = 'getListByProMails';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ProMails] :' + ProMails);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Lead WHERE EMAIL IN: ProMails';    
        List<Lead> listLeads = new List<Lead>((List<Lead>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listLeads);
        return listLeads; 
    }
    
    /*
     public static List<Lead> getAllLeads(){        
        String methodName = 'getAllLeads';    
          
        String soqlQuery = 'SELECT '+ ALL_FIELDS +' FROM Lead ';    
         
        List<Lead> listleads = new List<Lead>((List<Lead>)Database.query(soqlQuery));
           
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listleads);
        return listleads; 
    }*/
    
      public static List<Lead> getListLeadsFromEmails(List<String> listEmails){        
        String methodName = 'getListLeadsFromEmails';    
          
        String soqlQuery = 'SELECT Id, Email,LastName,FirstName,  PersonalEmail__c FROM Lead WHERE Email IN: listEmails or PersonalEmail__c IN: listEmails';    
         
        List<Lead> listleads = new List<Lead>((List<Lead>)Database.query(soqlQuery));
           
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listleads);
        return listleads; 
    }  
  
     public static String getFromgetTechnicalIdById(List<String> LeadId){
        
        String methodName = 'getFromgetTechnicalIdById';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[LeadId] :' + LeadId);
        
        String soqlQuery = 'SELECT Technical_ID__c FROM Lead WHERE Id IN: LeadId';    
        List<Lead> listlead = new List<Lead>((List<Lead>)Database.query(soqlQuery));
        
        Lead returnLead = listlead.get(0);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[returnLead] :' + returnLead);
        return String.valueof(returnLead.Technical_ID__c); 
    }   
    
    public static Lead getLeadByUpdateSubscriber(WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber updateSubscriber){
        
        String methodName = 'getLeadByUpdateSubscriber';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[updateSubscriber] :' + updateSubscriber);
        
        String Email = updateSubscriber.Email;
        String FirstName = updateSubscriber.FirstName; 
        String LastName = updateSubscriber.LastName; 
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Lead WHERE (Email =:Email or PersonalEmail__c =:Email) and FirstName =:FirstName and LastName =:LastName';    
        List<Lead> listLeads = new List<Lead>((List<Lead>)Database.query(soqlQuery));
        
        if(listLeads != null && listLeads.size() > 0){
           Lead tempReturn = listLeads.get(0);
           
           ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + tempReturn);
           return tempReturn;
       }
        
        
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + null);
        return null; 
    }
    
    public static List<Lead> getLeadToDeactivate(){
        
        String methodName = 'getLeadToDeactivate';            
 		Date myDate = Date.Today();
        myDate = myDate - 30;
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Lead WHERE WebsiteRole__c =:WEBSITEROLE_PROSPACETEMP and TrialStatus__c =:TRIALSTATUS_WAITINGFORVALIDATIONPROSPACE and WebsiteCreationDate__c =:myDate';    
        List<Lead> listLeads = new List<Lead>((List<Lead>)Database.query(soqlQuery));        
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listLeads);
        return listLeads; 
    }

}