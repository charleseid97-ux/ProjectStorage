/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 04-04-2025
 * @last modified by  : Khadija EL GDAOUNI
**/
public with sharing class ProspaceAlertsController {

    public class ProspaceAlertStructure {
        String checkboxAPI;
        String checkboxLabel;
        Boolean checkboxValue;
        String checkboxCategory;
        String checkboxWebsiteId;
    }

    private static Map<String, Boolean> getProspaceAlertActives(String recordId) {
        Map<String, Boolean> prospaceAlertActives = new Map<String, Boolean>();
        String soqlAlertType = 'SELECT id, AlertType__c,AlertTypeRecord__c, AlertTypeRecord__r.Name, isActive__c FROM Web_Communication__c WHERE ';
        soqlAlertType += Id.valueOf(recordId).getSObjectType().getDescribe().getName() + '__c = \'' + recordId + '\'';
        
        for (Web_Communication__c prospaceAlert : Database.query(soqlAlertType)) {
            Boolean currentValue;
            if(prospaceAlert.AlertTypeRecord__c !=null){
                if(prospaceAlert.AlertTypeRecord__r.Name.contains('Nav')){
                    currentValue = prospaceAlertActives.get('Nav');
                }else if(prospaceAlert.AlertTypeRecord__r.Name == 'Weekly Report' || prospaceAlert.AlertTypeRecord__r.Name == 'Monthly Factsheet'){
                    currentValue = prospaceAlertActives.get('Report');
                }else{
                    currentValue = prospaceAlertActives.get(prospaceAlert.AlertTypeRecord__r.Name);
                }
                
                if (currentValue == null || currentValue == false) {
                    if(prospaceAlert.AlertTypeRecord__r.Name.contains('Nav')){
                        system.debug('NAV : '+ prospaceAlert.AlertTypeRecord__r.Name + ' : '+ prospaceAlert.isActive__c);
                        prospaceAlertActives.put('Nav', prospaceAlert.isActive__c);
                    }else if(prospaceAlert.AlertTypeRecord__r.Name == 'Weekly Report' || prospaceAlert.AlertTypeRecord__r.Name == 'Monthly Factsheet'){
                        prospaceAlertActives.put('Report', prospaceAlert.isActive__c);
                    }else{
                        prospaceAlertActives.put(prospaceAlert.AlertTypeRecord__r.Name, prospaceAlert.isActive__c);
                    }
                    
                }
            }
            
        }

        return prospaceAlertActives;
    }

    @AuraEnabled(cacheable=true)
    public static String getTooglesValues(String recordId) {
        List<ProspaceAlertStructure> prospaceAlertList = new List<ProspaceAlertStructure>();
        Map<String, Boolean> prospaceAlertActives = getProspaceAlertActives(recordId);
        
        for (ProspaceAlertType__mdt alertType : [SELECT id, MasterLabel, DeveloperName, category__c, order__c, websiteId__c FROM ProspaceAlertType__mdt WHERE Is_Active__c = true  ORDER BY category__c, order__c]) {
            ProspaceAlertStructure structure = new ProspaceAlertStructure();
            structure.checkboxAPI = alertType.DeveloperName;
            

            if(alertType.MasterLabel.contains('Nav')){
                system.debug('Active Nav :'+prospaceAlertActives.get('Nav'));
                structure.checkboxLabel = 'Nav';
                structure.checkboxValue = prospaceAlertActives.get('Nav') != null ? prospaceAlertActives.get('Nav') : false;
                structure.checkboxWebsiteId = '1,2,3';
            }else if(alertType.MasterLabel == 'Weekly Report' || alertType.MasterLabel == 'Monthly Factsheet'){
                system.debug('Active Report :'+prospaceAlertActives.get('Report'));
                structure.checkboxLabel = 'Report';
                structure.checkboxValue = prospaceAlertActives.get('Report') != null ? prospaceAlertActives.get('Report') : false;
                structure.checkboxWebsiteId = '4,6';
            }else{
                structure.checkboxLabel = alertType.MasterLabel;
                structure.checkboxValue = prospaceAlertActives.get(alertType.MasterLabel) != null ? prospaceAlertActives.get(alertType.MasterLabel) : false;
                structure.checkboxWebsiteId = alertType.websiteId__c;
            }
            
            structure.checkboxCategory = alertType.category__c;
            

            prospaceAlertList.add(structure);
        }

        return JSON.serialize(prospaceAlertList);
    }

    @AuraEnabled
    public static Boolean subscriptionAlertPublication(String recordId, String alertType, Boolean checked) {
        List<Web_Communication__c> prospaceAlertList = [SELECT id, isActive__c FROM Web_Communication__c WHERE Contact__c =: Id.valueOf(recordId) and AlertType__c =: alertType ORDER BY CreatedDate DESC LIMIT 1];
        if (prospaceAlertList.size() > 0) {
            Web_Communication__c prospaceAlert = prospaceAlertList[0];
            prospaceAlert.isActive__c = checked;
            return Database.update(prospaceAlert, false).isSuccess();
        }
        else {
            Web_Communication__c prospaceAlert = new Web_Communication__c(
                Contact__c = recordId,
                AlertType__c = alertType,
                isActive__c = checked
            );
            return Database.insert(prospaceAlert, false).isSuccess();
        }
    }

    @AuraEnabled
    public static void desactiveProspaceAlertType(String recordId, String alertType) {
        List<Web_Communication__c> prospaceAlertList = new List<Web_Communication__c>();
        Set<String> alertTypeSet = new Set<String>();

        for(String item: alertType.split(',')){
            alertTypeSet.add(item.trim());
        }
        
        for (Web_Communication__c prospaceAlert : [SELECT id, isActive__c FROM Web_Communication__c WHERE Contact__c =: Id.valueOf(recordId) AND AlertType__c IN: alertTypeSet and isActive__c =: true]) {
            prospaceAlert.isActive__c = false;
            prospaceAlertList.add(prospaceAlert);
        }

        Database.update(prospaceAlertList, false);
    }
}