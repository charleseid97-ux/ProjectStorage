/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 29-10-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
public class WS_SendCampaignMembersBuild {
    public String buildBody(CampaignMember campaignMember, String status, Integer participant_type){
        // Création du Map principal
        Map<String, Object> jsonMap = new Map<String, Object>();

        // Ajout des champs simples
        jsonMap.put('firstname', campaignMember.FirstName);
        jsonMap.put('lastname', campaignMember.LastName);
        jsonMap.put('email', campaignMember.Email);        
        jsonMap.put('info1', campaignMember.Contact.Owner.Name!=null?campaignMember.Contact.Owner.Name:campaignMember.Lead.Owner.Name);
        jsonMap.put('info2', campaignMember.Category_Event_lookup__r.Name);
        jsonMap.put('status', status);
        jsonMap.put('saved', 1);
        if(participant_type!=null){
            jsonMap.put('participant_type_id', participant_type);
        }else{
            jsonMap.put('participant_type_id', campaignMember.Campaign.Tech_ParticipantType__c!=null ? (Integer)campaignMember.Campaign.Tech_ParticipantType__c:null);
        }
        jsonMap.put('organiser_notes', 'To be sent');

        // Création et ajout du Map pour standard_answers
        Map<String, String> standardAnswers = new Map<String, String>();
        standardAnswers.put('9', campaignMember.CompanyOrAccount);
        jsonMap.put('standard_answers', standardAnswers);

        // Sérialisation du Map en JSON
        String jsonString = JSON.serialize(jsonMap);
        System.debug('JSON string: ' + jsonString);
        return jsonString;
        /*CampaignMemberWrapper wrapper = new CampaignMemberWrapper();
        wrapper.firstname = campaignMember.FirstName;
        wrapper.lastname = campaignMember.LastName;
        wrapper.email = campaignMember.Email;
        wrapper.saved = true;
        //wrapper.language = formatLanguages(campaignMember.Language__c);
        wrapper.status =status;
        wrapper.info1 = campaignMember.Contact.Owner.Name;
        //wrapper.standard_answers.put('9', new CampaignMemberWrapper.StandardAnswer(campaignMember.CompanyOrAccount));
        
        //wrapper.standard_answers.put('9', campaignMember.CompanyOrAccount);
        wrapper.participant_type_id = campaignMember.Campaign.Tech_ParticipantType__c!=null ? (Integer)campaignMember.Campaign.Tech_ParticipantType__c:null;
        wrapper.organiser_notes = 'To be sent';
        CampaignMemberWrapper.NameWrapper nameWrp= new CampaignMemberWrapper.NameWrapper();
        //system.debug(JSON.serialize(wrapper));
        system.debug('wrapper :'+wrapper);
        system.debug('JSON.serialize(wrapper) :'+JSON.serialize(wrapper));
        return JSON.serialize(wrapper);*/
    }

    /*private static String formatLanguages(String language) {
        if(language == 'French'){
            return 'fr';
        }else if(language == 'English'){
            return 'en';
        }else if(language == 'German'){
            return 'de';
        }else if(language == 'Spanish'){
            return 'es';
        }else if(language == 'Portuguese'){
            return 'pt';
        }else if(language == 'Italian'){
            return 'it';
        }else if(language == 'Dutch'){
            return 'nl';
        }else 
           return '';
        
    }*/

}