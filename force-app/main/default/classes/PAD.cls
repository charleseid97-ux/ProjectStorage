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
    public static boolean byPassContactTriggerHandler = false;
    
    //BGU changebyPassCommunicationSubscriptionTriggerHandler to false to test CommunicationSubscription action
    public static boolean byPassCommunicationSubscriptionTriggerHandler = false;
    
    //BGU changebyPassCommunicationSubscriptionTriggerHandler to false to test CommunicationSubscription action
    public static boolean byPassLeadTriggerHandler = false;
    
    public static boolean byPassUserTriggerHandler = false ;
    public static boolean byPassRelationshipStatusTriggerHandler = false ;
    public static boolean byPassStrategicNewsTriggerHandler = false ;
    public static boolean byPassGridTriggerHandler = false ;
    public static boolean byPassActivitiesTriggerHandler = false ;
    
    //BGU new byPassCampaignMemberTriggerHandler
    public static boolean byPassCampaignMemberTriggerHandler = false ;
    
    public static boolean byPassCampaignTriggerHandler = false ;
    
    //Asonko new byPassCampaignMemberTriggerHandler
    public static boolean byPassSpeakerTriggerHandler = false;
    
    public static boolean byPassWebCommunicationTriggerHandler = false;
    
    public static final User user;
    
    
    static{
        System.debug('>>>>> PAD start run by ' + UserInfo.getName());
        
        // NEW: use a list to avoid QueryException when no User row is returned
        List<User> users = [
            SELECT BypassApexTriggers__c, Name, Email, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        // NEW: safely assign the running user if found, otherwise null
        user = users.isEmpty() ? null : users[0];
        
        System.debug('user List ##>>' + user);
        
        // NEW: protect against null user or null bypass configuration
        byPassTrigger = (user != null && user.BypassApexTriggers__c != null)
            ? ';' + user.BypassApexTriggers__c + ';'
            : ';;';
                                                                                                                                   
        System.debug('>>>>> PAD constructor : END <<<<<');    
    }
    
    
    public static boolean canTrigger(string Name){ 
        return (byPassTrigger.indexof(';' + Name + ';') == -1);
    }
}