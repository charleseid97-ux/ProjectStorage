/** 
* @author: Adolphe SONKO
* @date : Creation 14/03/2017
* @date : Modification /03/2017
* @description : his Class allows to Call the Webservices for eTouches create subscriber
*/

public class DM017_etouchesCreateSubscriber implements ITF008_POSTCreateSubscriberWS {
    
    private static String CLASS_NAME = 'DM017_etouchesCreateSubscriber';
    private static final String ALL_FIELDS = ObjectUtil.constructFieldListForQueryFrom('CampaignMember');

    
        /** 
        * @author: Adolphe SONKO
        * @date : Creation 14/03/2017
        * @date : Modification 14/03/2017
        * @description : This Methods call webservices method
        * @param : HttpRequest request This param is the HTTP request.
        * @return : HttpResponse The webservice call response.
        */    
            
    public HttpResponse postCreateSubscriber(HttpRequest request,  String responseType){
        
        string methodName = 'postCreateSubscriber';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
        system.debug('ADBS DM017_etouchesCreateSubscriber ' + response.getBody());
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;           
    }
    
    
     public HttpResponse putUpdateSubscriber(HttpRequest request,  String responseType){
        
        string methodName = 'putUpdateSubscriber';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[request] :' + request);
        
        Http httpProtocol = new Http();
        HttpResponse response = httpProtocol.send(request); 
        
        system.debug('ADBS DM017_etouchesCreateSubscriber ' + response.getBody());
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + response);              
        return response ;           
    }
    
    public static List<CampaignMember> getListByIds(List<id> CampaignMemberIds){
        
        String methodName = 'getListByIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[CampaignMemberIds] :' + CampaignMemberIds);

        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM CampaignMember WHERE Id IN: CampaignMemberIds';    
        List<CampaignMember> listCampaignMembers = new List<CampaignMember>((List<CampaignMember>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCampaignMembers);
        return listCampaignMembers; 
    }
    
            /** 
* @author: JLConsulting
* @date : Creation 06/05/19
* @date : Modification
* @description : this method retrieves the campaign member regarding the attendee ID. Taget process 16204 / 16244.
*/
    public static List<CampaignMember> getListByAttendeeID(List<String> listAttendeeID){
        String methodName = 'getListByAttendeeID';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[listAttendeeID] :' + listAttendeeID);

        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM CampaignMember WHERE TECH_ID_Attendee__c IN: listAttendeeID';    
        List<CampaignMember> listCampaignMembers = new List<CampaignMember>((List<CampaignMember>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listAttendeeID);
        return listCampaignMembers; 
    }
    
    public static List<CampaignMember> getListByCampaignIds(Set<Id> CampaignIds){
        
        String methodName = 'getListByCampaignIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[CampaignMemberIds] :' + CampaignIds);

        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM CampaignMember WHERE CampaignId IN: CampaignIds';    
        List<CampaignMember> listCampaignMembers = new List<CampaignMember>((List<CampaignMember>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCampaignMembers);
        return listCampaignMembers; 
    }
    
    public static List<CampaignMember> getListByCampaignIds(List<Id> CampaignIds){
        
        String methodName = 'getListByCampaignIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[CampaignMemberIds] :' + CampaignIds);

        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM CampaignMember WHERE CampaignId IN: CampaignIds';    
        List<CampaignMember> listCampaignMembers = new List<CampaignMember>((List<CampaignMember>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCampaignMembers);
        return listCampaignMembers; 
    }
    
   public static List<CampaignMember> getListBySubscriberIds(Set<String> SubscriberIds){
        
        String methodName = 'getListBySubscriberIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[CampaignMemberIds] :' + SubscriberIds);

        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM CampaignMember WHERE TECH_ID_Subscriber__c IN: SubscriberIds';    
        List<CampaignMember> listCampaignMembers = new List<CampaignMember>((List<CampaignMember>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCampaignMembers);
        return listCampaignMembers; 
    }
    
    public static List<CampaignMember> getListByAttendeeEmail(List<String> AttendeeEmails){
        
        String methodName = 'getListBySubscriberIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[CampaignMemberIds] :' + AttendeeEmails);

        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM CampaignMember WHERE Email IN: AttendeeEmails';    
        List<CampaignMember> listCampaignMembers = new List<CampaignMember>((List<CampaignMember>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCampaignMembers);
        return listCampaignMembers; 
    }
    
    
    public static CampaignMember getCMByUpdateAttendee(WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber updateSubscriber){
        
        String methodName = 'getCMByUpdateAttendee';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[updateSubscriber] :' + updateSubscriber);
        
        String Email = updateSubscriber.Email;
        String FirstName = updateSubscriber.FirstName; 
        String LastName = updateSubscriber.LastName;
        String CampaignId = updateSubscriber.CampaignId;  
            
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM CampaignMember WHERE (Contact.Email =:Email or Contact.PersonalEmail__c =: Email or Lead.Email =: Email or Lead.PersonalEmail__c =:Email) and FirstName =:FirstName and LastName =:LastName and CampaignId=:CampaignId';    
        System.debug('## JLC ## Class DM017 // getCMByUpdateAttendee // QUERY = ' + Database.query(soqlQuery));
        List<CampaignMember> listCampaignMembers = new List<CampaignMember>((List<CampaignMember>)Database.query(soqlQuery));
       
        if(listCampaignMembers != null && listCampaignMembers.size() > 0){
           CampaignMember tempReturn = listCampaignMembers.get(0);
           System.debug('## JLC ## Class DM017 // getCMByUpdateAttendee // CAMPAIGN MEMBER RETURNED EVENT EMAIL= ' + tempReturn.Event_Email__c );
           ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + tempReturn);
            return tempReturn;
       }
        
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + null);
        return null; 
    } 
    
    
   public static List<CampaignMember> getListByContactIds(List<String> contactIds){
        
        String methodName = 'getListByContactIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[contactIds] :' + contactIds);
       //JLC Added for #14601
        Set<String> excludeStatus = new Set<String>{'closed', 'cancelled', 'rejected'};
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM CampaignMember WHERE ContactId IN: contactIds and Campaign.Status not in :excludeStatus';
        List<CampaignMember> listCampaignMembers = new List<CampaignMember>((List<CampaignMember>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCampaignMembers);
        return listCampaignMembers; 
    }

    public static List<CampaignMember> getListByLeadIds(List<String> leadIds){
        
        String methodName = 'getListByLeadIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[leadIds] :' + leadIds);

        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM CampaignMember WHERE LeadId IN: leadIds';    
        List<CampaignMember> listCampaignMembers = new List<CampaignMember>((List<CampaignMember>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCampaignMembers);
        return listCampaignMembers; 
    } 
    
 /*   public static Map<CampaignMember, List<String>> getMapIdByCampMember(Set<id> CampaignMemberIds){
        
        String methodName = 'getMapIdByCampMember';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[CampaignIds] :' + CampaignMemberIds);

        List<CampaignMember> listCampaignMembers = getListByIds(CampaignMemberIds);
        
        Map<CampaignMember, List<String>> mapEventByCampaignMember = new Map<CampaignMember, List<String>>();
        for(CampaignMember camp: listCampaignMembers){
            if(mapEventByCampaignMember != null && mapEventByCampaignMember.get(camp) != null){
                mapEventByCampaignMember.
            }else{
                mapEventByCampaignMember.put(camp, new list<String>{camp.CampaignId});
            }            
        }
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + mapEventByCampaignMember);
        return mapEventByCampaignMember; 
    }  */
   
}