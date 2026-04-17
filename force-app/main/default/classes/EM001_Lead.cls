/** 
* @author: Pape DIOUF
* @date : Création 03/08/2016
* @date : Modification 03/08/2016
* @description : this Class allow to manage Lead busness entity data preparation .
*/
public class EM001_Lead {
    
    private static String CLASS_NAME = 'EM001_Lead';
    public static final String RECORDTYPE_NAME_PROSPACE = 'Generic Lead';
    public static final String RECORDTYPE_ID_PROSPACE = ObjectUtil.getRecordTypeId('Lead', RECORDTYPE_NAME_PROSPACE);
    public static final String WEBSITEROLE_PROSPACETEMP = '5';
    public static final String STATUS_WAITINGFORVALIDATION = '5';
    public static final String STATUS_NEW='New';
    
    
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
        
        List<Lead> listLeads = DM001_Lead.getListByIds(leadIds);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listLeads);
        return listLeads; 
    }
    
     // BGU 21 Feb 2017 new process
    
   /* public static List<Lead> getListByTechSunIds(Set<String> Ids){
        
        String methodName = 'getListByTechSunIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[getListByTechSunIds] :' + Ids);
        
        List<Lead> listLeads = DM001_Lead.getListByTechSunIds(Ids);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listLeads);
        return listLeads; 
    }*/
    
    public static List<Lead> getListByTechSunIds(Set<Integer> Ids){
        
        String methodName = 'getListByTechSunIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[getListByTechSunIds] :' + Ids);
        
        List<Lead> listLeads = DM001_Lead.getListByTechSunIds(Ids);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listLeads);
        return listLeads; 
    }
    
    
   
    
    public static List<Lead> getListByPersoMails(Set<String> PersoMails){
        
        String methodName = 'getListByPersoMails';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[PersoMails] :' + PersoMails);
        
        List<Lead> listLeads = DM001_Lead.getListByPersoMails(PersoMails);
        
        
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + PersoMails);
        return listLeads; 
    }
    

	// BGU 21 Feb 2017 new process
	
	public static List<Lead> getListByProMails(Set<String> ProMails){
        
        String methodName = 'getListByProMails';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[PersoMails] :' + ProMails);
        
        List<Lead> listLeads = DM001_Lead.getListByProMails(ProMails);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + ProMails);
        return listLeads; 
    }
    
    
         /**
     * @author : Briag GUEMARD 
     * @date : Création 07/03/2017
	 * @date : Modification 07/03/2017 
     * @description : This method add a Profile to the contact 
     * @param : Lead
     * @return :Lead
     */
    
     public static Lead setProfile(Lead lead1){
        
        String methodName = 'setProfile';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Lead] :' + lead1);
        
        If (lead1.WebsiteRole__c == null)
        {
        	lead1.WebsiteRole__c =WEBSITEROLE_PROSPACETEMP;
        	lead1.TrialStatus__c=STATUS_WAITINGFORVALIDATION;
        	
        }
        date myDate = date.today();

        
        
        lead1.WebsiteCreationDate__c = myDate;
        if (lead1.Status == null )
        {
        	lead1.Status=STATUS_NEW;        	
        }
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + lead1);
        return lead1; 
    }
    
    /*
       public static List<Lead> getAllLeads(){
        
        String methodName = 'getAllLeads';    
    //    ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactTeamEmails] :' + ContactTeamEmails);
        
        List<Lead> listleads = DM001_Lead.getAllLeads();
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listleads);
        return listleads; 
    }*/

    public static List<Lead> getListLeadsFromEmails(List<String> listEmails){
        
        String methodName = 'getListLeadsFromEmails';    
    //    ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ContactTeamEmails] :' + ContactTeamEmails);
        
        List<Lead> listleads = DM001_Lead.getListLeadsFromEmails(listEmails);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listleads);
        return listleads; 
    }
       
      public static String getTechnicalIDById(String LeadId){
      
      String methodName = 'getTechnical_ID__cById';    
      
      ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[LeadId] :' + LeadId);
      
      List<String> listTemp =new  List<String>();
      
      listTemp.add(LeadId);
      
      String returnLead = DM001_Lead.getFromgetTechnicalIdById(listTemp) ;
            
      ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + returnLead);  
      
      return returnLead; 
    }
    
    public static Lead getLeadByUpdateSubscriber(WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber updateSubscriber)
        {
            String methodName = 'getLeadByUpdateSubscriber';  
        
            Lead lead = DM001_Lead.getLeadByUpdateSubscriber(updateSubscriber);
        
            ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + lead);
            return lead; 
        }
	
     public static List<Lead> getLeadToDeactivate()
        {
            String methodName = 'getLeadToDeactivate';  
        
            List<Lead> leads = DM001_Lead.getLeadToDeactivate();
        
            ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + leads);
            return leads; 
        }
}