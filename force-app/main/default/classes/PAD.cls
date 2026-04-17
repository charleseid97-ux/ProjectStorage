/** 
* @author: Pape DIOUF
* @date : Création 06/09/2016
* @date : Modification 13/09/2016
* @description : This Class allows to manage trigger bypass.
*/
public class PAD{
    
    public static final string byPassTrigger;
    
    public static Map<String, String> SKIP_STRIGGER_MAP = new Map<String, String>();//triggerName -> Reason to skip
    
    //BGU change byPassContactTriggerHandler to false to test contact action
    public static  boolean byPassContactTriggerHandler = false;
    
    //BGU changebyPassCommunicationSubscriptionTriggerHandler to false to test CommunicationSubscription action
    public static  boolean byPassCommunicationSubscriptionTriggerHandler = false;
    
    //BGU changebyPassCommunicationSubscriptionTriggerHandler to false to test CommunicationSubscription action
    public static  boolean byPassLeadTriggerHandler = false;
    
    public static  boolean byPassUserTriggerHandler = false ;
    public static  boolean byPassRelationshipStatusTriggerHandler = false ;
    public static  boolean byPassStrategicNewsTriggerHandler = false ;
    public static  boolean byPassGridTriggerHandler = false ;
    public static  boolean byPassActivitiesTriggerHandler = false ;
    
    //BGU new byPassCampaignMemberTriggerHandler
    public static  boolean byPassCampaignMemberTriggerHandler = false ;
    
    public static  boolean byPassCampaignTriggerHandler = false ;
    
    //Asonko new byPassCampaignMemberTriggerHandler
    public static  boolean byPassSpeakerTriggerHandler = false;
    
    public static  boolean byPassWebCommunicationTriggerHandler = false;
    
    public static final User user;
    
    
    static{
        System.debug('>>>>> PAD start run by ' +  UserInfo.getName());
        
        user = [Select BypassApexTriggers__c, Name, Email, username from User where Id=:UserInfo.getUserId() limit 1];
        system.debug('user List ##>>'+ user);
        byPassTrigger = ';' + user.BypassApexTriggers__c + ';';                                                                                                                                   
        
        System.debug('>>>>> PAD constructor : END <<<<<');    
    }
    
    
    
    public static boolean canTrigger(string Name){ 
        return (byPassTrigger.indexof(';' + Name + ';') == -1);
    }
    

}