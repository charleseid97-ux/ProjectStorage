/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 12-08-2023
 * @last modified by  : SILA Nicolas
**/
public with sharing class PreferenceCenterController {
    public class Preference {
        String checkboxAPI;
        String checkboxLabel;
        Boolean checkboxValue;
        String checkboxCategory;
    }

    //Description : Get the required json to generate the toggle on preference center page
    //Parameters : recordId : Record Id from the Record Page
    @AuraEnabled(cacheable=true)
    public static string generateTogglesJson(String recordId, String category) {
        String sObjectName = Id.valueOf(recordId).getSObjectType().getDescribe().getName();
        String soqlQuery = 'SELECT id';
        List<Preference_Center_Category__mdt> categoriesList = new List<Preference_Center_Category__mdt>();
        if (String.isBlank(category)) {
            categoriesList = [SELECT id, MasterLabel, DeveloperName, category__c, order__c FROM Preference_Center_Category__mdt ORDER BY category__c, order__c];
        } else {
            categoriesList = [SELECT id, MasterLabel, DeveloperName, category__c, order__c FROM Preference_Center_Category__mdt WHERE category__c=:category ORDER BY order__c];
        }
        List<Preference> preferencesList = new List<Preference>();

        for (Preference_Center_Category__mdt categorie : categoriesList) {
            soqlQuery += ', ' + categorie.DeveloperName + '__c';
        }
        soqlQuery += ' FROM ' + sObjectName + ' WHERE Id=\'' + ID.valueof(recordId) + '\' WITH SECURITY_ENFORCED';
        
        try {
            SObject record = Database.query(soqlQuery);
            for (Preference_Center_Category__mdt categorie : categoriesList) {
                Preference pref = new Preference();
                pref.checkboxAPI = categorie.DeveloperName + '__c';
                pref.checkboxLabel = categorie.MasterLabel;
                pref.checkboxValue = Boolean.valueof(record.get(categorie.DeveloperName + '__c'));
                pref.checkboxCategory = categorie.category__c;
                preferencesList.add(pref);
            }    
        } catch (Exception exceptionHandler) {
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
        return JSON.serialize(preferencesList);
    }

    @AuraEnabled
    public static string getSubInterests(String recordId, String apiName) {
        String sObjectName = Id.valueOf(recordId).getSObjectType().getDescribe().getName();
        Map<String, List<String>> countriesFunds = MetadataUtils.getPreferenceCenterFundsCountries();
        System.debug(countriesFunds);
        Map<String, String> subInterestMap = new Map<String, String>();
        List<Preference> subInterestList = new List<Preference>();
        String soqlQuery = 'SELECT id, WebsiteCountry__c';
        String devName = apiName.split('__c')[0];
        Preference_Center_Category__mdt prefCenterCat = [SELECT Childs__c FROM Preference_Center_Category__mdt WHERE DeveloperName = :devName LIMIT 1];
        System.debug(prefCenterCat);

        for (String str : prefCenterCat.Childs__c.split(';')) {
            List<String> subInterest = str.split(':');
            subInterestMap.put(subInterest[0], subInterest[1]);
            soqlQuery += ', ' + subInterest[0];
        }
        
        soqlQuery += ' FROM ' + sObjectName +' WHERE Id=\'' + Id.valueOf(recordId) + '\' WITH SECURITY_ENFORCED';
        try {
            System.debug(soqlQuery);
            SObject record = Database.query(soqlQuery);
            System.debug(record);
            for (String subInt : subInterestMap.keySet()) {
                System.debug('API: ' + subInt);
                String devNameInterest = subInt.substringBefore('__c');
                List<String> countriesFund = countriesFunds.get(devNameInterest);
                if (countriesFund == null || countriesFund.contains((String) record.get('WebsiteCountry__c')) || (String.isBlank((String) record.get('WebsiteCountry__c')) && countriesFund.contains('empty'))) {
                    Preference p = new Preference();
                    p.checkboxAPI = subInt;
                    p.checkboxLabel = subInterestMap.get(subInt);
                    p.checkboxValue = Boolean.valueOf(record.get(subInt));
                    p.checkboxCategory = 'Childs';
                    subInterestList.add(p);
                }
            }
        } catch (Exception exceptionHandler) {
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
        return JSON.serialize(subInterestList);
    }

    @AuraEnabled
    public static Boolean unsubscribeAllSubInterest(String recordId, String apiName) {
        try {
            String sObjectName = Id.valueOf(recordId).getSObjectType().getDescribe().getName();
            SObject record;
            if (sObjectName.equals('Contact')) {
                record = new Contact(id=String.valueOf(recordId));
            }
            else {
                record = new Lead(id=String.valueOf(recordId));
            }
            String devName = apiName.split('__c')[0];
            Preference_Center_Category__mdt prefCenterCat = [SELECT Childs__c FROM Preference_Center_Category__mdt WHERE DeveloperName = :devName LIMIT 1];
            for (String str : prefCenterCat.Childs__c.split(';')) {
                List<String> subInterest = str.split(':');
                record.put(subInterest[0], false);
            }
            record.put(apiName, false);
            return Database.update(record, true).isSuccess();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean updateRecord(String recordId, String apiName, Boolean apiValue) {
        return updateFields(recordId, new Map<String, String>{apiName => String.valueof(apiValue)});
    }

    @AuraEnabled
    public static Boolean updateFields(String recordId, Map<String, String> fields) {
        String sObjectName = Id.valueOf(recordId).getSObjectType().getDescribe().getName();
        SObject record;
        if (sObjectName.equals('Contact')) {
            record = new Contact(id=recordId);
        }
        else {
            record = new Lead(id=recordId);
        }
        for (String key : fields.keySet()) {
            System.debug('Key: ' + key + ' Value: ' + fields.get(key));
            record.put(key, Boolean.valueof(fields.get(key)));
        }
        try {
            return Database.update(record, true).isSuccess();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Boolean getOptOut(String recordId) {
        String sObjectName = Id.valueOf(recordId).getSObjectType().getDescribe().getName();
        try {
            if (sObjectName.equals('Contact')) {
                return [SELECT Id, HasOptedOutOfEmail FROM Contact WHERE id = :recordId WITH SECURITY_ENFORCED].HasOptedOutOfEmail;
            }
            else {
                return [SELECT Id, HasOptedOutOfEmail FROM Lead WHERE id = :recordId WITH SECURITY_ENFORCED].HasOptedOutOfEmail;
            }
        }
        catch (Exception exceptionHandler) {
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean optOutAndCommunicationType(String recordId) {
        String sObjectName = Id.valueOf(recordId).getSObjectType().getDescribe().getName();
        SObject record;
        if (sObjectName.equals('Contact')) {
            record = new Contact(id=Id.valueof(recordId));
        }
        else {
            record = new Lead(id=Id.valueOf(recordId));
        }
        List<Preference_Center_Category__mdt> categoriesList = [SELECT id, MasterLabel, DeveloperName, order__c FROM Preference_Center_Category__mdt WHERE category__c=:'Communication Type' ORDER BY order__c];
        System.debug(categoriesList);
        for (Preference_Center_Category__mdt categorie : categoriesList) {
            record.put(categorie.DeveloperName + '__c', false);
            system.debug(categorie);
        }
        record.put('HasOptedOutOfEmail', true);
        
        try {
            return Database.update(record, true).isSuccess();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getLastModifiedOptOut(String recordId) {
        Map<String, String> CodeToExplanationMap = new Map<String, String>{'5.0.0'=>'Unknown issue', '5.1.0'=>'Other address status'  , '5.1.1'=>'Bad destination mailbox address'  , '5.1.2'=>'Bad destination system address'  , '5.1.3'=>'Bad destination mailbox address syntax', '5.1.4'=>'Destination mailbox address ambiguous', '5.1.5'=>'Destination mailbox address valid', '5.1.6'=>'Mailbox has moved', '5.1.7'=>'Bad sender’s mailbox address syntax', '5.1.8'=>'Bad sender’s system address', '5.2.0'=>'Other or undefined mailbox status', '5.2.1'=>'Mailbox disabled, not accepting messages', '5.2.2'=>'Mailbox full', '5.2.3'=>'Message length exceeds administrative limit', '5.2.4'=>'Mailing list expansion problem', '5.3.0'=>'Other or undefined mail system status', '5.3.1'=>'Mail system full', '5.3.2'=>'System not accepting network messages', '5.3.3'=>'System not capable of selected features', '5.3.4'=>'Message too big for system', '5.4.0'=>'Other or undefined network or routing status', '5.4.1'=>'No answer from host', '5.4.2'=>'Bad connection', '5.4.3'=>'Routing server failure', '5.4.4'=>'Unable to route', '5.4.5'=>'Network congestion', '5.4.6'=>'Routing loop detected', '5.4.7'=>'Delivery time expired', '5.5.0'=>'Other or undefined protocol status', '5.5.1'=>'Invalid command', '5.5.2'=>'Syntax error', '5.5.3'=>'Too many recipients', '5.5.4'=>'Invalid command arguments', '5.5.5'=>'Wrong protocol version', '5.6.0'=>'Other or undefined media error' , '5.6.1'=>'Media not supported' , '5.6.2'=>'Conversion required and prohibited' , '5.6.3'=>'Conversion required but not supported' , '5.6.4'=>'Conversion with loss performed' , '5.6.5'=>'Conversion failed' , '5.7.0'=>'Other or undefined security status' , '5.7.1'=>'Delivery not authorized, message refused' , '5.7.2'=>'Mailing list expansion prohibited' , '5.7.3'=>'Security conversion required but not possible' , '5.7.4'=>'Security features not supported' , '5.7.5'=>'Cryptographic failure' , '5.7.6'=>'Cryptographic algorithm not supported' , '5.7.7'=>'Message integrity failure'  };

        String sObjectName = Id.valueOf(recordId).getSObjectType().getDescribe().getName();
        TimeZone tz = UserInfo.getTimezone();
        try {
            if (sObjectName.equals('Contact') || sObjectName.equals('Lead')) {
                String objectName = sObjectName.equals('Contact') ? 'Contact' : 'Lead';

                // Get the record and history data
                SObject record = Database.query('SELECT EmailBouncedReason, Name,pi__pardot_hard_bounced__c,OptOut_Reason__c,HasOptedOutOfEmail FROM ' + objectName + ' WHERE Id = :recordId LIMIT 1');
                
                if(record.get('HasOptedOutOfEmail') == false){
                    return '';
                }
                
                String reason = (String)record.get('EmailBouncedReason');
                String optOutReason = (String)record.get('OptOut_Reason__c');
                List<SObject> recordHist = new List<SObject>();
                String query = 'SELECT CreatedDate, NewValue, CreatedById FROM ' + objectName + 'History WHERE ' + objectName + 'Id = \'' + recordId + '\' AND Field = \'HasOptedOutOfEmail\' ORDER BY CreatedDate DESC LIMIT 1';
                recordHist = Database.query(query);

                
                if (recordHist.size() > 0 && (Boolean)recordHist[0].get('NewValue')) {
                    
                    String unsubDate =((DateTime)recordHist[0].get('CreatedDate')).format('dd-MM-yyyy HH:mm:ss', tz.toString());
                    String createdBy = getUserNameById((Id)recordHist[0].get('CreatedById'));

                    if(record.get('pi__pardot_hard_bounced__c') == true){
                        String msgError = 'Unknown Error';
                        for (String code : CodeToExplanationMap.keySet()){
                            
                            if(reason.contains(code)){
                                msgError = CodeToExplanationMap.get(code);
                            }
                        }
                        return 'Hardbounced on '+unsubDate+' due to ' +msgError ;
                    }
                    if (createdBy == 'B2BMA Integration') {
                        List<SObject> digitalInteraction = Database.query('SELECT Digital_Interaction__r.'+ sObjectName +'_lu__r.Name, Type__c FROM Digital_Interaction_Details__c WHERE Digital_Interaction__r.'+sObjectName+'_lu__c = \''+ recordId +'\' AND Type__c = \'Unsubscribe\' Order By Last Interaction Date DESC LIMIT 1');

                        if (digitalInteraction.size() > 0) {
                            return 'Client unsubscribed on ' + unsubDate;
                        }
                    
                    }else{

                        return createdBy+ ' opted out the client because of the following reason: '+optOutReason ;
                    }
                    
                }
                    if(record.get('pi__pardot_hard_bounced__c') == true){
                        String msgError = 'Unknown Error';
                        for (String code : CodeToExplanationMap.keySet()){
                            if(reason.contains(code)){
                                msgError = CodeToExplanationMap.get(code);
                            }
                        }
                        return 'Hardbounced due to ' +msgError ;
                    }
                
            }

            return '';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static String getUserNameById(Id userId) {
        User user = [SELECT Name FROM User WHERE Id = :userId LIMIT 1];
        return user.Name;
    }


}