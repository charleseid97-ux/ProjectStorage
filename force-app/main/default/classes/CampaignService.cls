/**
 * Created by noorgoolamnabee on 08/11/2022.
 */

public with sharing class CampaignService {


    /**
     * @author Noor
     * @date 08/11/2022
     * @description Define Newsletter Campaign Name to format
     * @param items
     */
    public static void defineCampaignName(List<Campaign> items){

        Id newsletterRT = RecordTypeUtil.getRecordTypeIdByDeveloperName(Campaign.SObjectType, 'Newsletters');
        
        for(Campaign c : items) {
            if(c.RecordTypeId == newsletterRT)
                c.Name = generateCampaignName(c);
        }
    }

    
    /**
     * @author Louise Delduc
     * @date 12/12/2022
     * @description Update Newsletter Campaign Name to format
     * @param items
     */
    public static void updateCampaignName(List<Campaign> newItems, Map<Id, Campaign> oldItems){

        Id newsletterRT = RecordTypeUtil.getRecordTypeIdByDeveloperName(Campaign.SObjectType, 'Newsletters');
        //This DateTime is the is used to know when Carmignac started using this taxonomy for Newsletter
        //Campaign created before this date should not be modified to have this taxonomy
        DateTime breakTime = DateTime.newInstance(2022, 12, 08, 15, 0, 0);
        
        for(Campaign c : newItems) {
            Boolean usedFieldChange = c.Description != oldItems.get(c.Id).Description ||
                					  c.Start_Date_Time__c != oldItems.get(c.Id).Start_Date_Time__c ||
                					  c.Language__c != oldItems.get(c.Id).Language__c ||
                					  c.Newsletter_Country__c != oldItems.get(c.Id).Newsletter_Country__c ||
                					  c.Name != oldItems.get(c.Id).Name;
            if(c.RecordTypeId == newsletterRT && c.CreatedDate >= breakTime && usedFieldChange) {
                System.debug('Generate campaign name');
                c.Name = generateCampaignName(c);
            }
        }
    }

    public static String getFirstMultiPickListValue(String str) {
        return String.isNotBlank(str) ? str.split(';')[0] : '';
    }

    /**
     * @param c
     *
     * @return name in format <CREATED DATE> - <DESCRIPTION> - <COUNTRY> - <LANGUAGE>
     */
    public static String generateCampaignName(Campaign c){

        Map<String, Global_Settings__mdt> settings = Utils.getGlobalSettingsByLabel();

        String name = (c.Start_Date_Time__c != null ? c.Start_Date_Time__c.format('YYYY-MM') : Datetime.now().format('YYYY-MM')) + ' - ' ;

        if(String.isNotBlank(c.Description))
            name += c.Description.left(60);

        if(String.isNotBlank(c.Newsletter_Country__c)) {
            String firstCountryUnderscore = c.Newsletter_Country__c.replace(' ', '_');
            String firstCountry = getFirstMultiPickListValue(firstCountryUnderscore);
        	if (settings.containsKey(firstCountry))
            	name += ' - ' + settings.get(firstCountry).Value__c;
            if (String.isNotBlank(c.Language__c))
                name += '-';
        }
        else if (String.isNotBlank(c.Language__c))
            name += ' - ';

        if(String.isNotBlank(c.Language__c))
            name += getFirstMultiPickListValue(c.Language__c);

        return name;
    }


}