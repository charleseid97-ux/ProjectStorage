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
        String sObjectName = Id.valueOf(recordId).getSObjectType().getDescribe().getName();
        TimeZone tz = UserInfo.getTimezone();
        try {
            if (sObjectName.equals('Contact')) {
                List<ContactHistory> recordHist = [SELECT CreatedDate, NewValue FROM ContactHistory WHERE ContactId=:String.valueof(recordId) and Field='HasOptedOutOfEmail' ORDER BY CreatedDate Desc Limit 1];
                if (recordHist.size() > 0 && recordHist[0].NewValue == true) {
                    return recordHist[0].CreatedDate.format('dd-MM-yyyy HH:mm:ss', tz.toString());
                }
            }
            else {
                List<LeadHistory> recordHist = [SELECT CreatedDate, NewValue FROM LeadHistory WHERE LeadId=:String.valueof(recordId) and Field='HasOptedOutOfEmail' ORDER BY CreatedDate Desc Limit 1];
                if (recordHist.size() > 0 && recordHist[0].NewValue == true) {
                    return recordHist[0].CreatedDate.format('dd-MM-yyyy HH:mm:ss', tz.toString());
                }
            }
            return '';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}