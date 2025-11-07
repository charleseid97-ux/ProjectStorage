/**
 * Created by Noor Nabee on 2/13/2020.
 */

public with sharing class SM016_CampaignMemberService {

    private static String CLASS_NAME = SM016_CampaignMemberService.class.getName();
    //private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();
    //private static integer CST_NBRepriseApiAventri = 3;
    //private static List<String> invalidCampaignStatus = new List<String>{'Closed', 'Cancelled', 'Rejected', 'Archived', 'Event Cancelled'};


    /**
    * @author JLC
    * @date 2/13/2020
    * Flag campaign Member to be sent in Aventri
    * @param campaignMembers

    public static void flagCampaignMemberAsSubscriber(List<CampaignMember> campaignMembers) {
        ObjectUtil.debugLogBegin(CLASS_NAME, 'flagCampaignMemberAsSubscriber', ' [campaignMembers] : ' + campaignMembers);
        //Get campaigns associated to the campaign member
        Set<Id> campaignIds = new Set<Id>();
        for(CampaignMember member : campaignMembers){
            campaignIds.add(member.CampaignId);
        }

        Map<Id, Campaign> mapCampaignsByIds = new Map<Id, Campaign>([SELECT Id, Event_code_Etouches__c, TECH_Mailing_List_ID_Etouches__c, Status FROM  Campaign WHERE Id IN : campaignIds]);

        for (CampaignMember member : campaignMembers) {
            System.debug('//NGO flagCampaignMemberAsSubscriber member.Campaign.Status ' + member.Campaign.Status);
            System.debug('//NGO flagCampaignMemberAsSubscriber member.campaign.Event_code_Etouches__c ' + member.Campaign.Event_code_Etouches__c);
            System.debug('//NGO flagCampaignMemberAsSubscriber member.campaign.TECH_Mailing_List_ID_Etouches__c ' + member.Campaign.TECH_Mailing_List_ID_Etouches__c);
            System.debug('//NGO flagCampaignMemberAsSubscriber member.subscriber__c ' + member.Subscriber__c);
            if (checkCampaignValidStatus(mapCampaignsByIds.get(member.CampaignId).Status)
                    && String.isNotBlank(mapCampaignsByIds.get(member.CampaignId).Event_code_Etouches__c)
                    && String.isNotBlank(mapCampaignsByIds.get(member.CampaignId).TECH_Mailing_List_ID_Etouches__c)
                    && !member.Subscriber__c
                    ) {
                member.TECH_AsyncAction__c = 'Create';
            }
        }
    } */

    /*
    Check if campaign status is valid

    private static Boolean checkCampaignValidStatus(String status){
        return  !invalidCampaignStatus.contains(status);
    }*/

    /**
    * @author JLC
    * @date 2/13/2020
    * Flag campaign Member to be sent in Aventri
    * @param campaignMembers
    */
    /*public static void intializeCampaignMember(List<CampaignMember> campaignMembers) {

        Set<Id> contactIds = new Set<Id>();
        Set<Id> leadIds =new Set<Id>();

        for(CampaignMember member : campaignMembers){
            if(String.isBlank(member.ContactId))  leadIds.add(member.LeadId);
            else contactIds.add(member.ContactId);
        }

        Map<Id, Contact> contactMap = new Map<Id, Contact>([SELECT Id, Subscriber__c FROM  Contact WHERE Id IN : contactIds]);
        Map<Id, Lead> leadMap = new Map<Id, Lead>([SELECT Id, HasOptedOutOfEmail FROM  Lead WHERE Id IN : leadIds]);
        for (CampaignMember member : campaignMembers) {
            if((contactMap.containsKey(member.ContactId) && contactMap.get(member.ContactId).Subscriber__c )
                    || (leadMap.containsKey(member.LeadId) && leadMap.get(member.LeadId).HasOptedOutOfEmail))
                member.Subscriber__c = true; 
        }
    }*/

    /**
    * @author JLC
    * @date 4/19/2019
    * Optimized method to add exclusion
    * @param campaignMembersAttended
    */
    public static void updateLastFieldEvent(List<CampaignMember> newItems, Map<Id, CampaignMember> oldItems) {

        ObjectUtil.debugLogBegin(CLASS_NAME, 'updateLastFieldEvent', ' [campaignMembersAttended] : ' + newItems);

        List<Contact> contactList = new List<Contact>();
        for (CampaignMember cm : newItems) {
            if (cm.Status != null && cm.Status.equalsIgnoreCase('Attended')  && !cm.Status.equals(oldItems.get(cm.id).Status) && String.isNotBlank(cm.ContactId) && cm.TECH_IS_MEMBER_TO_BE_DELETED__c) {
                contactList.add(new Contact(Id = cm.ContactId, Last_Event_attendance_Type__c = cm.campaign.Type, Last_Event_attendance__c = cm.campaign.End_Date_Time__c));
            }
        }

        if (contactList.size() > 0) {
            Database.update(contactList, false);
        }
    }
    
    public static void checkUnicity(List<CampaignMember> newItems) {
        system.debug('Check Unicity Start');
        
        /*Map<Id, Set<String>> mapCampaignEmails = new Map<Id, Set<String>>();
        // Parcourir les nouveaux membres et les ajouter au map 
        for (CampaignMember cm : newItems) { 
            if (!mapCampaignEmails.containsKey(cm.CampaignId)) {
                mapCampaignEmails.put(cm.CampaignId, new Set<String>()); 
            } 
            if (mapCampaignEmails.get(cm.CampaignId).contains(cm.Event_Email__c)) {
                system.debug('duplicate '); 
                cm.addError('Error : Duplicates Campaign Member'); 
            } else {
                mapCampaignEmails.get(cm.CampaignId).add(cm.Event_Email__c); 
            } 
        } 
        // Récupérer les IDs de campagne uniques 
        Set<Id> campaignIds = mapCampaignEmails.keySet(); 
        
        Map<Id, Campaign> mapCampaigns = new Map<Id, Campaign>([SELECT Id, (SELECT Id, Event_Email__c
                                                                            FROM CampaignMembers)
                                                                FROM Campaign 
                                                                WHERE Id IN :campaignIds]);
        
        for(CampaignMember newCM :newItems){
            system.debug('newCM : '+newCM.Event_Email__c);
            for(CampaignMember cm : mapCampaigns.get(newCM.CampaignId).CampaignMembers){
                system.debug('cm : '+cm);
                if(newCM.Event_Email__c == cm.Event_Email__c){
                    system.debug('duplicate ');
                    newCM.addError('Error : Duplicates Campaign Member');
                }
            }
        }    */    
        
        system.debug('Check Unicity End');
    }
    
    public static void blockOptOutEvent(List<CampaignMember> newItems) {
        /*
        system.debug('blockOptOutEvent');
        Set<Id> contactIds = new Set<Id>();
        Set<Id> leadIds = new Set<Id>();
        
    	String recordTypeId = Schema.SObjectType.Campaign.getRecordTypeInfosByDeveloperName().get('Event_and_Meeting').getRecordTypeId();
		system.debug('rec id : '+recordTypeId.substring(0,15));
        
        for (CampaignMember cm : newItems) {
            if (cm.ContactId != null) {
                contactIds.add(cm.ContactId);
            }else if(cm.LeadId != null) {
                leadIds.add(cm.LeadId);
            }
        }

        Map<Id, Contact> contactsMap = new Map<Id, Contact>(
            [SELECT Id, Invitation_Opt_Out__c FROM Contact WHERE Id IN :contactIds]
        );
        Map<Id, Lead> leadsMap = new Map<Id, Lead>(
            [SELECT Id, Event_Opt_Out__c FROM Lead WHERE Id IN :leadIds]
        );
    
        for (CampaignMember cm : newItems) {
            system.debug('rec id : '+cm.Tech_CampaignRecordType__c);
            if (recordTypeId.substring(0,15) == cm.Tech_CampaignRecordType__c && ((cm.ContactId != null && contactsMap.containsKey(cm.ContactId)) || (cm.LeadId != null && leadsMap.containsKey(cm.LeadId)))) {
                Contact relatedContact = contactsMap.get(cm.ContactId);
                Lead relatedLead = leadsMap.get(cm.LeadId);
                if ((relatedContact!=null && relatedContact.Invitation_Opt_Out__c) || (relatedLead!=null && relatedLead?.Event_Opt_Out__c)) {
                    cm.addError('Error: You can\'t create a campaign member because the associated contact/Lead has opted out of events.');
                }
            }
        }
            system.debug('blockOptOutEvent');
*/
        }
    
    
    	public static void sendCallWSLyyti(List<CampaignMember> newItems, Map<Id, CampaignMember> oldItems) {
        
            Set<Id> cmIdsToSend = new Set<Id>();
            Set<Id> cmIdsToGet = new Set<Id>();
            
            // Récupérer les CampaignMembers avec LastModifiedBy
            Map<Id, CampaignMember> cmWithLastModifiedBy = new Map<Id, CampaignMember>([
                SELECT Id, LyytiId__c, LastModifiedBy.Username,Campaign.LyytiId__c, Campaign.Status
                FROM CampaignMember
                WHERE Id IN :newItems
            ]);
            
            if(oldItems != null){
                system.debug('>>>>>>>>>>> oldItems + '+oldItems);
                system.debug('>>>>>>>>>>> new + '+newItems);
                system.debug('>>>>>>>>>>> cmWithLastModifiedBy + '+cmWithLastModifiedBy);
                for(CampaignMember cm :newItems){
                    CampaignMember cmWithUser = cmWithLastModifiedBy.get(cm.Id);
                    if(cmWithUser.LastModifiedBy.Username != System.label.Username_Lyyti && cm.LyytiId__c != null && cm.status != 'Invited' && cm.status != 'Cancelled' && ((cm.status != oldItems.get(cm.Id).status && ((cm.status == 'Declined' && !cm.Cancelled__c) || cm.status != 'Declined')) || (cm.Cancelled__c && !oldItems.get(cm.Id).Cancelled__c)) ){
                        
                            cmIdsToSend.add(cm.Id);
                        
                    }
                }
            }else{
                system.debug('>>>>>>>>>>> newItems + '+newItems);
                for(CampaignMember cm :newItems){
                    CampaignMember cmWithUser = cmWithLastModifiedBy.get(cm.Id);
                	if(cm.LyytiId__c==null && cmWithUser.Campaign.LyytiId__c!=null ){
                        if(cmWithUser.LastModifiedBy.Username != System.label.Username_Lyyti){
                            //cmIdsToSend.add(cm.Id);
                        }else{
                            //Case : participant created by Lyyti
                            cmIdsToGet.add(cm.Id);
                        }
                    }
                }
            }
                
           
            if(cmIdsToSend.size()>0){
                system.debug('>>>>>>>>>>> cmIdsToSend + '+cmIdsToSend);
                callWS(cmIdsToSend, false);
            }
            if(cmIdsToGet.size()>0){
                system.debug('>>>>>>>>>>> cmIdsToGet + '+cmIdsToGet);
                callWS(cmIdsToGet, true);
            }
            
        }
    
        @future(callout=true)
        public static void callWS(Set<Id> memberIds, Boolean fromLyyti) {
            List<CampaignMember> cmToProcess = [SELECT Id, CampaignId, Campaign.LyytiId__c,FirstName,Campaign.Tech_ParticipantType__c,Cancelled__c,Category_Event_lookup__r.Name,
                                            LastName,Email,Status,LyytiId__c,Contact.Owner.Name,Lead.Owner.Name,Language__c,CompanyOrAccount,LastModifiedBy.Username,Category_name__c,
                                            Contact.Invitation_Opt_Out__c,Lead.Event_Opt_Out__c
                                            FROM CampaignMember 
                                            WHERE Id IN :memberIds LIMIT 50];
     
            List<CampaignMember> cmToUpdate = new List<CampaignMember>();
            if(fromLyyti){
                Set<Id> campaignIds = new Set<Id>();
                
                for (CampaignMember cm : cmToProcess) {
                    campaignIds.add(cm.CampaignId);
                }
                List<Campaign> campaigns = [SELECT Id, LyytiId__c,(SELECT Id, CampaignId, Campaign.LyytiId__c,FirstName,
                                                                LastName,Email,Status,LyytiId__c,Contact.Owner.Name,Lead.Owner.Name,Language__c,CompanyOrAccount  
                                                                FROM CampaignMembers WHERE ID IN :memberIds)
                                            FROM Campaign 
                                            WHERE Id IN :campaignIds];
                for (Campaign c : campaigns) {
                    WS_GetEventParticipants sender = new WS_GetEventParticipants(c);
                    sender.sendInDataToExternalService();
                    for(CampaignMember cm :c.CampaignMembers){
                        if(sender.idEmailMap.containsKey(cm.Email)){
                            if(cm.LyytiId__c==null){
                                CampaignMember cMember = new CampaignMember(Id=cm.Id, LyytiId__c=sender.idEmailMap.get(cm.Email));
                                cmToUpdate.add(cMember);
                            }
                        }
                    }
                }
            }else{
                cmToUpdate = getCMToUpdate(cmToProcess,null,null);
            }
            if(cmToUpdate.size()>0){
                update cmToUpdate;
            }
            
        }
    
        public static List<CampaignMember> getCMToUpdate(List<CampaignMember> cmToProcess, Integer participant_type, String campaignLyytiId){
            List<CampaignMember> cmToUpdate = new List<CampaignMember>();
            for (CampaignMember cm : cmToProcess) {
                if(cm.Campaign.LyytiId__c!=null && !cm.Contact.Invitation_Opt_Out__c && !cm.Lead.Event_Opt_Out__c){
                    system.debug('>>>>>>>>>>> cm + '+cm);
                    String lyytiId;
                    Boolean changeStatus = false;
    
                    if (cm.Status == 'Invited' && cm.LyytiId__c==null) {
                        /*
                        WS_SendCampaignMembers sender = new WS_SendCampaignMembers(cm, 'notreacted', participant_type, campaignLyytiId);            
                        sender.sendInDataToExternalService();
                        lyytiId = sender.uid !=null ? String.valueOf(sender.uid):null;
                        */
                    }else if (cm.Cancelled__c) {
    
                        WS_UpdateCampaignMembers sender = new WS_UpdateCampaignMembers(cm, 'cancelled', null);            
                        sender.sendInDataToExternalService();
                        changeStatus = true;
                        system.debug('changeStatus :'+changeStatus);
    
                    }else if (cm.Status == 'Declined') {
                        if(cm.LyytiId__c == null){
                            /*WS_SendCampaignMembers sender = new WS_SendCampaignMembers(cm, 'reactedno', participant_type, campaignLyytiId);            
                            sender.sendInDataToExternalService();
                            lyytiId = sender.uid !=null ? String.valueOf(sender.uid):null;*/
                        }else{
                            // call WS to update status
                            WS_UpdateCampaignMembers sender = new WS_UpdateCampaignMembers(cm, 'reactedno', null);            
                            sender.sendInDataToExternalService();
                        }
    
                    }else if (cm.Status == 'Attended') {
    
                        if(cm.LyytiId__c == null){
                            /*WS_SendCampaignMembers sender = new WS_SendCampaignMembers(cm, 'show', participant_type, campaignLyytiId);            
                            sender.sendInDataToExternalService();
                            lyytiId = sender.uid !=null ? String.valueOf(sender.uid):null;*/
                        }else{
                            // call WS to update status
                            WS_UpdateCampaignMembers sender = new WS_UpdateCampaignMembers(cm, 'show', null);            
                            sender.sendInDataToExternalService();
                        }
    
                    }else if (cm.Status == 'No Show') {
    
                        if(cm.LyytiId__c == null){
                            /*WS_SendCampaignMembers sender = new WS_SendCampaignMembers(cm, 'noshow', participant_type, campaignLyytiId);            
                            sender.sendInDataToExternalService();
                            lyytiId = sender.uid !=null ? String.valueOf(sender.uid):null;*/
                        }else{
                            // call WS to update status
                            WS_UpdateCampaignMembers sender = new WS_UpdateCampaignMembers(cm, 'noshow', null);            
                            sender.sendInDataToExternalService();
                        }
    
                    } else if (cm.Status == 'Confirmed') {
                        if(cm.LastModifiedBy.Username != System.label.Username_Lyyti){
                        if(cm.LyytiId__c == null){
                            /*WS_SendCampaignMembers sender1 = new WS_SendCampaignMembers(cm, 'notreacted', participant_type, campaignLyytiId);            
                            sender1.sendInDataToExternalService();
                            lyytiId = sender1.uid !=null ? String.valueOf(sender1.uid):null;

                            //WS_SendCampaignMembers sender = new WS_SendCampaignMembers(cm, 'reactedyes', participant_type, campaignLyytiId);            
                            //sender.sendInDataToExternalService();
                            //lyytiId = sender.uid !=null ? String.valueOf(sender.uid):null;
    
                            if (lyytiId != null) {
                                WS_UpdateCampaignMembers sender = new WS_UpdateCampaignMembers(cm, 'reactedyes', lyytiId);            
                                sender.sendInDataToExternalService();

                                WS_SendConfirmationLyyti sendConfirm = new WS_SendConfirmationLyyti(lyytiId);            
                                sendConfirm.sendInDataToExternalService();
                            }*/
                        }else{
    
                                // call WS to update status
                                WS_UpdateCampaignMembers sender = new WS_UpdateCampaignMembers(cm, 'reactedyes', null);            
                                sender.sendInDataToExternalService();
                                
                                WS_SendConfirmationLyyti sendConfirm = new WS_SendConfirmationLyyti(cm.LyytiId__c);            
                                sendConfirm.sendInDataToExternalService();
                        }
                        }
                        
                    }
                    
    
                    if(lyytiId!=null){
                        /*cm.LyytiId__c = lyytiId;
                        cmToUpdate.add(cm);*/
                    }
                    if(changeStatus){
                        system.debug('changeStatus 2 :'+changeStatus);
                        cm.Status = 'Declined';
                        cmToUpdate.add(cm);
                    }
                }
            }
            return cmToUpdate;
        }


    /**
    * @author JLC
    * @date 4/19/2019
    * call update subscriber on Aventri
    * @param newItems

    public static void callUpdateSubscriber(List<CampaignMember> newItems, Map<Id, CampaignMember> oldItems) {

        List<CampaignMember> campaignMemberList = new List<CampaignMember>();
        for (CampaignMember cm : (List<CampaignMember>) newItems) {
            //#15844
            //	TECH_IS_MEMBER_TO_BE_DELETED__c is used as it is a formula to get the campaign live status
            if (cm.TECH_ID_Subscriber__c == ((CampaignMember) oldItems.get(cm.Id)).TECH_ID_Subscriber__c && cm.TECH_ID_Subscriber__c != null && cm.TECH_IS_MEMBER_TO_BE_DELETED__c) {
                campaignMemberList.add(cm);
            }
        }
        if(campaignMemberList.size() > 0) System.enqueueJob(new SM016_CallUpdateSubscriberEtouchesAsync(campaignMemberList, 0, 99));
    }*/

    /*
     Update lead and Contact optOut from Campaign Member Event OptOut
    */
    public static void updateEventOptOut(List<CampaignMember> members, Map<Id, CampaignMember> oldMap) {
        String methodName = 'onBeforeInsertUpdate';

        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [members] : ' + members);
        Map<Id, SObject> objectToUpdateMap = new Map<Id, SObject>();

        for (CampaignMember member : members) {

            if (member.subscriber__c != oldMap.get(member.Id).Subscriber__c && member.subscriber__c != member.TECH_ParentEventOptOut__c) {

                if (String.isNotBlank(member.ContactId)) {
                    objectToUpdateMap.put(member.ContactId, new Contact(Id = member.ContactId, Subscriber__c = member.subscriber__c));
                }
                else {
                    objectToUpdateMap.put(member.LeadId, new Lead(Id = member.LeadId, Event_Opt_Out__c = member.subscriber__c));
                }
            }
        }

        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [objectToUpdateMap] : ' + objectToUpdateMap);

        if (objectToUpdateMap.values().size() > 0) {
            update objectToUpdateMap.values();
        }
    }


    /**
     * Method to call Aventri API to create subscriber
     *
     * @param campaign_member_to_send

    public static void callCreateSubscribereTouches(List<CampaignMember> campaign_member_to_send) {
        String methodName = 'callCreateSubscribereTouches';
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [List<Id> campaignMemberList] : ' + campaign_member_to_send);

        //Bypass all trigger when  updating campaignMember
        PAD.byPassCampaignMemberTriggerHandler = true;
        String categoryEtouchesId = '';
        datetime myDateTime = datetime.now();

        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[param_setting] : ' + param_setting);

        //Map<Id, String> subscriberIdMap = new Map<Id, String>();
        List<CampaignMember> updatedCampaignMembers =  new List<CampaignMember>();

        //Get Aventri access token
        String token = EM029_EtouchesToken.getNewToken();

        try {
            //Make callout to aventri for each campaign member
            for (CampaignMember cm : campaign_member_to_send) {
                try {
                    String eventID = cm.Campaign.Event_code_Etouches__c;
                    String mailingListId = cm.Campaign.TECH_Mailing_List_ID_Etouches__c;
                    // This line avoid to send Optedout contacts to eTouches
                    if (cm.Subscriber__c == null || cm.Subscriber__c == false) {

                        // ID SALESFORCE DE LA CATEGORY - campaign_member_to_send.Category_Event_lookup__c
                        if (cm.Category_Event_lookup__c != null) {
                            Category_Event__c getCategoryEvent = EM024_CategoryEvent.getRecordsByIds(new Set<Id>{
                                    cm.Category_Event_lookup__c
                            });
                            if (getCategoryEvent != null) {
                                categoryEtouchesId = getCategoryEvent.Tech_Category_Event_ID_Etouches__c;
                                ObjectUtil.debugLog(CLASS_NAME, methodName, '[temp.Category_Event_lookup__c] : ' + cm.Category_Event_lookup__c);
                                ObjectUtil.debugLog(CLASS_NAME, methodName, '[getCategoryEvent.Tech_Category_Event_ID_Etouches__c] : ' + getCategoryEvent.Tech_Category_Event_ID_Etouches__c);
                            }
                        }
                        
                        //Create Request
                        HttpRequest request = EM015_CampaignMember.getPostCreateSubscriber(param_setting, token, eventID, mailingListId, cm, categoryEtouchesId);
                        ObjectUtil.debugLog(CLASS_NAME, methodName, '[request] : ' + request);
                        //Send Request
                        HttpResponse response = EM015_CampaignMember.createSubscriber(request, null);
                        ObjectUtil.debugLog(CLASS_NAME, methodName, '[response] : ' + response);

                        String recordData = 'Campaign Member ID : ' + cm.Id;

                        if (response.getStatusCode() == 200) {
                            if (response.getBody().contains('email is not set') || response.getBody().contains('<error>')) {
                                EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(response, request, recordData, CLASS_NAME, methodName);
                                cm.TECH_AsyncAction__c = 'Error - Email not set';
                            } else {
                                if (response.getBody() == '') {
                                    cm.TECH_AsyncAction__c = getRetry(cm.TECH_AsyncAction__c);
                                } else {

                                    String techIdSubscriber = EtouchesXML.getSubscriberID(response);
                                    cm.TECH_ID_Subscriber__c = techIdSubscriber;
                                    cm.Last_Etouches_action_synchronized__c = String.valueof(myDateTime);
                                    cm.TECH_AsyncAction__c = 'Complete';
                                    //updatedCampaignMembers.add(new CampaignMember(Id = cm.Id, TECH_ID_Subscriber__c = techIdSubscriber, Last_Etouches_action_synchronized__c = String.valueof(myDateTime)));
                                }
                            }
                        } else {
                            EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(response, request, recordData, CLASS_NAME, methodName);
                            listLogError.add(newErro);
                        }

                    }
                } catch (Exception e) {
                    EM023_Log.errorToLog newErroException = new EM023_Log.errorToLog();
                    newErroException.dateCreate = Datetime.now();
                    newErroException.interfaceName = 'callCreateSubscribereTouches Catch Exception on' + cm.id;
                    newErroException.Data = e.getMessage();
                    newErroException.error = e.getStackTraceString();

                    listLogError.add(newErroException);
                }
            } // End foreach
            //Update the campaign members with the Subscriber
            //update updatedCampaignMembers;

        } catch (Exception e) {
            DateTime debutSauve = DateTime.now();
            EM023_Log.errorToLog newErroException = new EM023_Log.errorToLog();
            newErroException.dateCreate = Datetime.now();
            newErroException.interfaceName = 'callCreateSubscribereTouches Catch Exception' + debutsauve.Time();
            newErroException.Data = e.getMessage();
            newErroException.error = e.getStackTraceString();
            listLogError.add(newErroException);
        }

        EM023_Log.insertLogError(listLogError);
    }*/

    /**
     * Get updated status for retry
     *
     * @param status
     *
     * @return

    public static String getRetry(String status){

        Integer max = 3;

        if(status.equalsIgnoreCase('Create')){
            return 'Retry-1';
        }else if(status.contains('Retry')){

            String tries = status.split('-')[1];
            Integer index = Integer.valueOf(tries);
            if(index < max){
                index ++;
                return 'Retry-'+index;
            }else{
                return 'Error After '+max+' tries';
            }
        }
        return 'Error';
    }*/


    /**
     * Method to call Aventri API to delete subscriber
     *
     * @param campaign_member_to_delete

    public static void callDeleteSubscriber(List<String> campaign_member_to_delete) {

        String methodName = 'callDeleteSubscriber';

        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [List<String>  campaign_member_to_delete ] : ' + campaign_member_to_delete);

        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);

        String token = EM029_EtouchesToken.getNewToken();

        for (String cmId : campaign_member_to_delete) {
            HttpRequest request = EM015_CampaignMember.getPutUpdateDeleteSubscriber(param_setting, token, cmId);
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [request] : ' + request);

            HttpResponse response = EM015_CampaignMember.updateSubscriber(request, null);
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [response] : ' + response);

            String recordData = ' Deleted Campaign member ID : ' + cmId;

            if (response.getStatusCode() == 200) {
                if (response.getBody().contains('<error>')) {
                    EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(response, request, recordData, CLASS_NAME, methodName);
                    listLogError.add(newErro);
                }
            } else {
                EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(response, request, recordData, CLASS_NAME, methodName);
                listLogError.add(newErro);
            }

            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [response status] : ' + response.getStatusCode());
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [response body] : ' + response.getBody());
        }

        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [listLogError] : ' + listLogError);
        EM023_Log.insertLogError(listLogError);
    }*/


    /**
     * Method to call Aventri API to update subscriber
     *
     * @param campaign_member_to_send

    public static void callSubscriberUpdate(List<CampaignMember> campaign_member_to_send) {

        String methodName = 'callSubscriberUpdate';
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [campaign_member_to_send] : ' + campaign_member_to_send);

        String token = EM029_EtouchesToken.getNewToken();

        //List<CampaignMember>  campaign_member_to_send = new  List<CampaignMember>();

        //1 : getListCampaignMember
        //campaign_member_to_send= EM015_CampaignMember.getListCampaignMember(campaignMemberListId);

        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);

        if (campaign_member_to_send.size() > 0) {
            String categoryEtouchesId;
            String recordData = 'Compain Member Id : ';

            for (CampaignMember cM : campaign_member_to_send) {

                //2: ID SALESFORCE DE LA CATEGORY - campaign_member_to_send.Category_Event_lookup__c
                if (cM.Category_Event_lookup__c != null) {
                    Category_Event__c getCategoryEvent = EM024_CategoryEvent.getRecordsByIds(new Set<Id>{
                            cM.Category_Event_lookup__c
                    });
                    categoryEtouchesId = getCategoryEvent.Tech_Category_Event_ID_Etouches__c;
                    ObjectUtil.debugLog(CLASS_NAME, methodName, ' [temp.Category_Event_lookup__c] : ' + cM.Category_Event_lookup__c);
                    ObjectUtil.debugLog(CLASS_NAME, methodName, ' [getCategoryEvent.Tech_Category_Event_ID_Etouches__c] : ' + getCategoryEvent.Tech_Category_Event_ID_Etouches__c);
                } else {
                    categoryEtouchesId = '';
                }

                //3 : Update Subscriber in Etouches
                HttpRequest request = EM015_CampaignMember.getPutUpdateSubscriber(param_setting, token, cM, categoryEtouchesId);
                ObjectUtil.debugLog(CLASS_NAME, methodName, ' [request] : ' + request);

                HttpResponse response = EM015_CampaignMember.updateSubscriber(request, null);
                ObjectUtil.debugLog(CLASS_NAME, methodName, ' [response] : ' + response);

                if (response.getStatusCode() == 200) {
                    if (response.getBody().contains('<error>')) {
                        recordData += ' ' + cM.Id;
                        EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(response, request, recordData, CLASS_NAME, methodName);
                        listLogError.add(newErro);
                    }
                } else {
                    recordData += ' ' + cM.Id;
                    EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(response, request, recordData, CLASS_NAME, methodName);
                    listLogError.add(newErro);
                }
            }

            EM023_Log.insertLogError(listLogError);
        }
    }*/
}