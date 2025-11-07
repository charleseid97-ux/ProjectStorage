/**
 * Created by noorgoolamnabee on 08/11/2022.
 */

public with sharing class CampaignService {

    
     public static void sendCampaignLyyti(List<Campaign> newItems, Map<Id, Campaign> oldItems) {
        Set<Id> campaignIds = new Set<Id>();
        Set<Id> externalCampaign = new Set<Id>();
        
            for(Campaign c :newItems){
                if(c.Event_Lyyti__c && c.LyytiId__c==null){
                    campaignIds.add(c.Id);
                }else {
                    if(oldItems!=null){
                        if(!c.Event_Lyyti__c && c.LyytiId__c!=null && oldItems.get(c.Id).LyytiId__c==null && c.Tech_ParticipantType__c==null){
                    		externalCampaign.add(c.Id);
                		}
                    }else{
                        if(!c.Event_Lyyti__c && c.LyytiId__c!=null && c.Tech_ParticipantType__c==null){
                    		externalCampaign.add(c.Id);
                		}
                    }
                }
            }
      
            
        
        if(campaignIds.size()>0){
            callWS(campaignIds);
        }
        if(externalCampaign.size()>0){
            callWSGet(externalCampaign);
        }
    }

    @future(callout=true)
    public static void callWS(Set<Id> campaignIds) {
        List<Campaign> campaigns = [SELECT Id,Name,Lyyti_Template__c,Owner.Lyyti_Id__c,
                                    End_Date_Time__c,Start_Date_Time__c,Language__c,Event_Local_Start_Time__c,Event_Local_End_Time__c   
                                        FROM Campaign 
                                        WHERE Id IN :campaignIds];
        List<Campaign> campaignToUpdate = new List<Campaign>();
        for (Campaign c : campaigns) {
            // Créer une nouvelle instance de WS_SendCampaign pour chaque membre
            WS_SendCampaign sender = new WS_SendCampaign(c);
            
            // Appeler la méthode pour envoyer les données au service externe 62125408
            sender.sendInDataToExternalService();
            if(sender.eid!=null){
                c.LyytiId__c = String.valueOf(sender.eid);
                c.Tech_ParticipantType__c = sender.participant_type;
                campaignToUpdate.add(c);
            }
            
        }
        if(campaignToUpdate.size()>0){
            update campaignToUpdate;
        }
    }

    @future(callout=true)
    public static void callWSGet(Set<Id> campaignIds) {
        List<Campaign> campaigns = [SELECT Id, LyytiId__c,(SELECT Id, CampaignId, Campaign.LyytiId__c,FirstName,Cancelled__c,Category_name__c,Category_Event_lookup__r.Name,
                                                            LastName,Email,Status,LyytiId__c,Contact.Owner.Name,Lead.Owner.Name,Language__c,CompanyOrAccount,LastModifiedBy.Username,
                                                            Contact.Invitation_Opt_Out__c,Lead.Event_Opt_Out__c   
                                                            FROM CampaignMembers)
                                        FROM Campaign 
                                        WHERE Id IN :campaignIds];
        List<Campaign> campaignToUpdate = new List<Campaign>();
        List<CampaignMember> cmToUpdate = new List<CampaignMember>();
        Integer nbrOfCm = 0;
        for (Campaign c : campaigns) {
            // Créer une nouvelle instance de WS_SendCampaign pour chaque membre
            WS_GetEventParticipantType sender = new WS_GetEventParticipantType(c);
            
            // Appeler la méthode pour envoyer les données au service externe
            sender.sendInDataToExternalService();
            if(sender.participant_type!=null){
                /*List<CampaignMember> cmToSend = new List<CampaignMember>();
                for(CampaignMember cMember : c.CampaignMembers){
                    if(nbrOfCm >= 50){
                        break;
                    }
                    if(cMember.LyytiId__c==null){
                        cmToSend.add(cMember);
                        nbrOfCm++;
                    }
                }
                if(cmToSend.size()>0){
                	cmToUpdate.addAll(SM016_CampaignMemberService.getCMToUpdate(cmToSend, sender.participant_type, c.LyytiId__c));
                }*/
                c.Tech_ParticipantType__c = sender.participant_type;
                campaignToUpdate.add(c);
            }
            
        }
        if(campaignToUpdate.size()>0){
            update campaignToUpdate;
        }
        /*
        if(cmToUpdate.size()>0){
            update cmToUpdate;
        }*/
    }
    /**
     * @author Noor
     * @date 08/11/2022
     * @description Define Newsletter Campaign Name to format
     * @param items
     */
    public static void defineCampaignName(List<Campaign> items){

        List<Id> recordTypeToCheck = new List<Id> {
            RecordTypeUtil.getRecordTypeIdByDeveloperName(Campaign.SObjectType, 'Newsletters'),
            RecordTypeUtil.getRecordTypeIdByDeveloperName(Campaign.SObjectType, 'Marketing_Channel'),
            RecordTypeUtil.getRecordTypeIdByDeveloperName(Campaign.SObjectType, 'Conversion_point')
        };

        for (Campaign c : items) {
            if (recordTypeToCheck.contains(c.RecordTypeId)) {
                c.Name = generateCampaignName(c);
            }
        }
    }

    
    /**
     * @author Louise Delduc
     * @date 12/12/2022
     * @description Update Newsletter Campaign Name to format
     * @param items
     */
    public static void updateCampaignName(List<Campaign> newItems, Map<Id, Campaign> oldItems){

        //The DateTime is used to know when Carmignac started using this taxonomy for theses Campaign's record types
        //Campaign created before this date should not be modified to have this taxonomy
        Map<Id, DateTime> recordTypeToCheck = new Map<Id, DateTime> {
            RecordTypeUtil.getRecordTypeIdByDeveloperName(Campaign.SObjectType, 'Newsletters') => DateTime.newInstance(2022, 12, 08, 15, 0, 0),
            RecordTypeUtil.getRecordTypeIdByDeveloperName(Campaign.SObjectType, 'Marketing_Channel') => DateTime.newInstance(2023, 03, 30, 11, 0, 0),
            RecordTypeUtil.getRecordTypeIdByDeveloperName(Campaign.SObjectType, 'Conversion_point') => DateTime.newInstance(2023, 03, 30, 11, 0, 0)
        };
        
        for (Campaign c : newItems) {
            //If any of the fields used for the name is changed, then the campaign's name should be updated
            Boolean usedFieldChange = c.Description != oldItems.get(c.Id).Description ||
                					  c.Start_Date_Time__c != oldItems.get(c.Id).Start_Date_Time__c ||
                					  c.Language__c != oldItems.get(c.Id).Language__c ||
                					  c.Newsletter_Country__c != oldItems.get(c.Id).Newsletter_Country__c ||
                					  c.Name != oldItems.get(c.Id).Name;
            if (usedFieldChange && recordTypeToCheck.get(c.RecordTypeId) <= c.CreatedDate) {
                System.debug('Generate campaign name');
                c.Name = generateCampaignName(c);
            }
        }
    }

    public static String getFirstMultiPickListValue(String str) {
        return String.isNotBlank(str) ? str.split(';')[0] : '';
    }

    /**
     * @param c The campaign whose name must be generated
     *
     * @return name in format <CREATED DATE> - <DESCRIPTION> - <COUNTRY> - <LANGUAGE>
     */
    public static String generateCampaignName(Campaign c){

        Map<String, Global_Settings__mdt> settings = Utils.getGlobalSettingsByLabel();

        String name = (c.Start_Date_Time__c != null ? c.Start_Date_Time__c.format('YYYY-MM') : Datetime.now().format('YYYY-MM')) + ' - ' ;

        if (String.isNotBlank(c.Description)) {
            name += c.Description.left(60);
        }

        if (String.isNotBlank(c.Newsletter_Country__c)) {
            String firstCountryUnderscore = c.Newsletter_Country__c.replace(' ', '_');
            String firstCountry = getFirstMultiPickListValue(firstCountryUnderscore);
            if (settings.containsKey(firstCountry)) {
            	name += ' - ' + settings.get(firstCountry).Value__c;
            }
            if (String.isNotBlank(c.Language__c)) {
                name += '-';
            }
        }
        else if (String.isNotBlank(c.Language__c)) {
            name += ' - ';
        }

        if (String.isNotBlank(c.Language__c)) {
            name += getFirstMultiPickListValue(c.Language__c);
        }

        return name;
    }


}