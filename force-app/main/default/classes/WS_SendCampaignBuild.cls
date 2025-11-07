/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 31-10-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
public  class WS_SendCampaignBuild {


    public static Map<String, Object> buildJson(Campaign campaign) {
        Map<String, Object> jsonMap = new Map<String, Object>();
        system.debug('build');
        // Ajout des champs simples
        if(!Test.isRunningTest()){

            jsonMap.put('new_owner_id', campaign.Owner.Lyyti_Id__c!=null ? Integer.valueOf(campaign.Owner.Lyyti_Id__c): LyytiCredentials__mdt.getInstance('Authentication').OwnerId__c);
        }
        system.debug('build 1');
        jsonMap.put('event_to_copy_id', campaign.Lyyti_Template__c!=null ? Integer.valueOf(campaign.Lyyti_Template__c):1634722);
system.debug('build 2');        
        String startDateTimeString = campaign.Event_Local_Start_Time__c;
        String timeZoneSidId = 'Europe/Paris';  // ou le fuseau horaire approprié
        DateTime startDt = convertStringToDateTime(startDateTimeString, timeZoneSidId);

        String endDateTimeString = campaign.Event_Local_End_Time__c;
        DateTime endDt = convertStringToDateTime(endDateTimeString, timeZoneSidId);
        //System.debug('DateTime converti : ' + dt);
        //System.debug('DateTime converti (dans le fuseau horaire local) : ' + dt.format('yyyy-MM-dd HH:mm:ss', UserInfo.getTimeZone().getID()));
	system.debug('build 3');  
        jsonMap.put('start_time_utc', dateTimeToUnixTimestamp(startDt));
        jsonMap.put('end_time_utc', dateTimeToUnixTimestamp(endDt));
        //jsonMap.put('enrollment_open_utc', dateTimeToUnixTimestamp(campaign.Start_Date_Time__c));
        //jsonMap.put('enrollment_deadline_utc', dateTimeToUnixTimestamp(campaign.End_Date_Time__c));
        
        // Gestion du champ multi-picklist Language__c
        List<String> languages = formatLanguages(campaign.Language__c);
        //List<String> languages = campaign.Language__c != null ? campaign.Language__c.split(';') : new List<String>();
        jsonMap.put('language', languages);
        
        // Gestion du nom multilingue
        Map<String, String> names = new Map<String, String>();
        for (String lang : languages) {
            names.put(lang.toLowerCase(), campaign.Name);
        }
        jsonMap.put('name', names);
        
        // Ajout des champs booléens
        jsonMap.put('copy_confirmation_page', true);
        jsonMap.put('copy_participant_types', true);
        
        return jsonMap;
    }
    
    private static Long dateTimeToUnixTimestamp(DateTime dt) {
        if (dt == null) return null;
        return dt.getTime() / 1000; // Convertit en secondes
    }
    
    public String getJsonString(Campaign camp) {
        Map<String, Object> jsonMap = buildJson(camp);
        return JSON.serialize(jsonMap);
    }
    private static List<String> formatLanguages(String languagesString) {
        List<String> formattedLanguages = new List<String>();
        if (String.isNotBlank(languagesString)) {
            for (String lang : languagesString.split(';')) {
                String formattedLang = lang.trim().toLowerCase();
                if (formattedLang.length() == 2) {  // Vérifie si c'est un code de langue à 2 lettres
                    formattedLanguages.add(formattedLang);
                }
            }
        }
        return formattedLanguages;
    }

    public static DateTime convertStringToDateTime(String dateTimeString, String timeZoneSidId) {
        // Séparer la date et l'heure
        String[] parts = dateTimeString.split(' ');
        String datePart = parts[0];
        String timePart = parts[1];
    
        // Séparer l'année, le mois et le jour
        String[] dateParts = datePart.split('/');
        Integer year = Integer.valueOf(dateParts[0]);
        Integer month = Integer.valueOf(dateParts[1]);
        Integer day = Integer.valueOf(dateParts[2]);
    
        // Séparer les heures et les minutes
        String[] timeParts = timePart.split(':');
        Integer hour = Integer.valueOf(timeParts[0]);
        Integer minute = Integer.valueOf(timeParts[1]);
    
        // Créer un DateTime dans le fuseau horaire spécifié
        DateTime dt = DateTime.newInstance(year, month, day, hour, minute, 0);
        TimeZone tz = TimeZone.getTimeZone(timeZoneSidId);
        Integer offsetTotalMinutes = tz.getOffset(dt) / (60 * 1000);
        
        // Ajuster le DateTime pour le fuseau horaire local de l'organisation
        return dt.addMinutes(offsetTotalMinutes);
    }
    
    public static Long convertToEpochTime(DateTime dt) {
        return dt.getTime() / 1000;
    }
   
}