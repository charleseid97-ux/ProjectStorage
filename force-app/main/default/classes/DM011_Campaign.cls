/** 
* @author: Briag GUEMARD
* @date : Création 27/02/2017
* @date : Modification 27/02/2017
* @description : this Class allow to manage all database operations (such as select requests and dml) with Salesforce.com .
*/

public  class DM011_Campaign {    
     
   private static String CLASS_NAME = 'DM011_Campaign';
   private static final String ALL_FIELDS = ObjectUtil.constructFieldListForQueryFrom('Campaign');    
    
   public static List<Campaign> getListByIds(Set<id> CampaignIds){
        
        String methodName = 'getListByIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[CampaignIds] :' + CampaignIds);  
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Campaign WHERE Id IN: CampaignIds';    
        List<Campaign> listCampaigns = new List<Campaign>((List<Campaign>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCampaigns);
        return listCampaigns; 
    }
    
    public static List<Campaign> getAllListByIds(List<id> CampaignIds)
    {        
        String methodName = 'getListByIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[CampaignIds] :' + CampaignIds);  
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Campaign WHERE Id IN: CampaignIds';    
        List<Campaign> listCampaigns = new List<Campaign>((List<Campaign>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCampaigns);
        return listCampaigns; 
    }    
    
    public static void setEtoucheEventID(Campaign campaign, String EventID)
    {        
        String methodName = 'setEtoucheEventID';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Campaign] :' + campaign);
              
        campaign.Event_code_Etouches__c = EventID;       
        
        database.update(campaign);
        
        //database.updateImmediate(campaign);        
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + campaign);         
    }
    
    public static void setEtouchesMailingListID(Campaign campaign, String MailinglistID){
        
        String methodName = 'setEtouchesMailingListID';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Campaign] :' + campaign);
              
        campaign.TECH_Mailing_List_ID_Etouches__c = MailinglistID;
        
        database.update(campaign);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + campaign);         
    }
    
       public static String getEndPointUpdateEtouchesEvent(Campaign campaign){
        
        String methodName = 'getEndPointUpdateEtouchesEvent';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Campaign] :' + campaign);
        String    getEndPointUpdateEtouchesEvent;   
        
        getEndPointUpdateEtouchesEvent='&eventid='+campaign.Event_code_Etouches__c;
        //Name
        if (campaign.name <> null){
        	getEndPointUpdateEtouchesEvent = getEndPointUpdateEtouchesEvent +'&name=' +campaign.name;
        	
        }
        //StartDate
        if (campaign.Start_Date_Time__c <> null){
        	
        }
        //end date
        If (campaign.End_Date_Time__c<>null)
        {
        	
        }   
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + getEndPointUpdateEtouchesEvent);
        return getEndPointUpdateEtouchesEvent;
    }
    
    
     public static void setEtouchesData(Campaign campaign, String MailinglistID, String EventID){
        
        String methodName = 'setEtouchesData';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Campaign] :' + campaign);
              
        campaign.TECH_Mailing_List_ID_Etouches__c = MailinglistID;
        campaign.Event_code_Etouches__c = EventID;
        
        database.update(campaign);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + campaign); 
    }
    
     public static List<String> getMailingListIdsByEventID(List<String> EventIDList){
        
        String methodName = 'getMailingListIdsByEventID';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[EventIDList] :' + EventIDList);
          
        String soqlQuery = 'SELECT '+ ALL_FIELDS +' FROM Campaign WHERE Event_code_Etouches__c IN: EventIDList';    
        
        List<Campaign> listCampaign = new List<Campaign>((List<Campaign>)Database.query(soqlQuery));
        
        List<String> listMailingList = new List<String>();
        
        for (Campaign camp :listCampaign){
            if(camp.TECH_Mailing_List_ID_Etouches__c != null){
                listMailingList.add(camp.TECH_Mailing_List_ID_Etouches__c);
            }
        }
   
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listMailingList);
        return listMailingList; 
    }
    
    public static List<Campaign> getEventListIdsByEventID(Set<String> EventIDList){
        
        String methodName = 'getEventListIdsByEventID';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[EventIDList] :' + EventIDList);
          
        String soqlQuery = 'SELECT '+ ALL_FIELDS +' FROM Campaign WHERE Event_code_Etouches__c IN: EventIDList';    
        
        List<Campaign> listCampaign = new List<Campaign>((List<Campaign>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCampaign);
        return listCampaign; 
    }
    
    public static List<Campaign> getEventListsByEventID(List<String> EventIDList){
        
        String methodName = 'getEventListIdsByEventID';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[EventIDList] :' + EventIDList);
          
        String soqlQuery = 'SELECT '+ ALL_FIELDS +' FROM Campaign WHERE Event_code_Etouches__c IN: EventIDList';    
        
        List<Campaign> listCampaign = new List<Campaign>((List<Campaign>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCampaign);
        return listCampaign; 
    }
    
    public static List<Campaign> getEventListsByScheduleId(List<String> List_ID_Schedule){
        
        String methodName = 'getEventListsByScheduleId';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[EventIDList] :' + List_ID_Schedule);
          
        String soqlQuery = 'SELECT '+ ALL_FIELDS +' FROM Campaign WHERE TECH_ID_Schedule__c IN: List_ID_Schedule';    
        
        List<Campaign> listCampaign = new List<Campaign>((List<Campaign>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCampaign);
        return listCampaign; 
    }
    
    public static Campaign getCampaignByID(String CampaignID){
        
        String methodName = 'getCampaignByID';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[CampaignID] :' + CampaignID);
          
        String soqlQuery = 'SELECT '+ ALL_FIELDS +', owner.BusinessDevelopmentRegions__c FROM Campaign WHERE Campaign_ID__c =: CampaignID';    
        
        List<Campaign> listCampaign = new List<Campaign>((List<Campaign>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCampaign);
        
        if(listCampaign !=null)
        {
            return listCampaign[0]; 
        }else
        {
            return null;
        }
    }
    
}