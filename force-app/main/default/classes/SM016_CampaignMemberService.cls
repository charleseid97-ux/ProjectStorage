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
        for (CampaignMember cm : newItems)
            if (cm.Status != null && cm.Status.equalsIgnoreCase('Attended')  && !cm.Status.equals(oldItems.get(cm.id).Status) && String.isNotBlank(cm.ContactId) && cm.TECH_IS_MEMBER_TO_BE_DELETED__c)
                contactList.add(new Contact(Id = cm.ContactId, Last_Event_attendance_Type__c = cm.campaign.Type, Last_Event_attendance__c = cm.campaign.End_Date_Time__c));

        if (contactList.size() > 0) Database.update(contactList, false);
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
        List<SObject> objectToUpdateList = new List<SObject>();

        for(CampaignMember member : members){

            if(member.subscriber__c != oldMap.get(member.Id).Subscriber__c && member.subscriber__c != member.TECH_ParentEventOptOut__c){

                if(String.isNotBlank(member.ContactId)) objectToUpdateList.add(new Contact(Id= member.ContactId, Subscriber__c = member.subscriber__c));
                else objectToUpdateList.add(new Lead(Id= member.LeadId, HasOptedOutOfEmail = member.subscriber__c));
            }
        }

        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [objectToUpdateList] : ' + objectToUpdateList);

        if(objectToUpdateList.size() > 0) update objectToUpdateList;
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