/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 20-07-2023
 * @last modified by  : Thanina YAYA
**/
public with sharing class CTL_SearchSubscriptionProduct {
    
    public CTL_SearchSubscriptionProduct() {}

    @AuraEnabled(cacheable=true)
    public static List<Share_Class__c> getShareClasses() {
        return ([SELECT Id, Name, Fund__c, Fund__r.Product_Name__c,Fund__r.Name,   Validity__c, ISIN_Code__c,Country__c
                            FROM Share_Class__c
                            WHERE Validity__c = TRUE order by Fund__r.Product_Name__c  asc ,Name asc]);
    }

    @AuraEnabled(cacheable=true)
    public static List<Product__c> getFundWithShareClasses() {
        return ([SELECT Id,Name,Product_Name__c,(SELECT Id, Name,ISIN_Code__c, Country__c FROM Share_Classes__r WHERE Validity__c =true ORDER BY Name ASC) 
                    FROM Product__c WHERE Validity__c=true AND RecordType.Name='Fund'  ORDER BY Product_Name__c ASC]);
    }

    @AuraEnabled(cacheable=true)
    public static List<Share_Class__c> getShareClassesByCountry(String countryCode) {
        if (String.isNotBlank(countryCode)) {
            return ([SELECT Id, Name,Fund__c,Fund__r.Product_Name__c,Fund__r.Name,ISIN_Code__c,Country__c,
                                                            Fund__r.Strategy__c,Fund__r.Strategy__r.Name,Fund__r.Strategy__r.Product_Name__c
                                                    FROM Share_Class__c
                                                    WHERE Validity__c = TRUE AND Fund__c!=null AND Fund__r.Strategy__c!=null AND  
                                                            (Country__c INCLUDES (:countryCode) OR Country__c=null OR Country__c='') order by Fund__r.Strategy__r.Product_Name__c,Fund__r.Product_Name__c  asc ,Name asc]);
        }
        else {
            return ([SELECT Id, Name, Fund__c, Fund__r.Product_Name__c,Fund__r.Name,ISIN_Code__c,Country__c,
                        Fund__r.Strategy__c,Fund__r.Strategy__r.Name,Fund__r.Strategy__r.Product_Name__c
                FROM Share_Class__c
                WHERE Validity__c = TRUE AND Fund__c!=null AND Fund__r.Strategy__c!=null AND (Country__c=null OR Country__c='')order by Fund__r.Strategy__r.Product_Name__c,Fund__r.Product_Name__c  asc ,Name asc]);
        }
    }

    @AuraEnabled
    public static void saveProspaceAlerts(List<Web_Communication__c> alerts){
        if(alerts.size() > 0) {
            upsert alerts;
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<ProspaceAlertType__mdt> getAlertTypes(String cat){
        return ([SELECT LWCLabel__c, MasterLabel,DeveloperName,WebsiteId__c,Order__c FROM ProspaceAlertType__mdt WHERE Category__c = :cat ORDER BY Order__c ASC]);
    }

    @AuraEnabled(cacheable=true)
    public static List<Share_Class__c> getShareClassesByCountryWithSub(String countryCode,String cat,String contId, Integer counter){
        //WebCommunications AlertTypeRecord__r.Name,AlertTypeRecord__r.TECH_WebSiteID__c,AlertType__c, Contact__c,IsActive__c
        //get list picklist possible value
        ProspaceAlertType__mdt[] alerts = getAlertTypes(cat);
        Set<String> alertVal= new Set<String>();
        Set<String> alertDevName= new Set<String>();
        for(ProspaceAlertType__mdt mdt:alerts) {
            alertVal.add(mdt.MasterLabel);
            alertDevName.add(mdt.DeveloperName);
        }

        //if(String.isNotBlank(countryCode)) 
        return ([SELECT Id, Name,Fund__c,Fund__r.Product_Name__c,Fund__r.Name,ISIN_Code__c,Country__c,
                                                            Fund__r.Strategy__c,Fund__r.Strategy__r.Name,Fund__r.Strategy__r.Product_Name__c,
                                                            (SELECT AlertTypeRecord__r.Name,AlertTypeRecord__r.TECH_WebSiteID__c,AlertType__c,IsActive__c FROM WebCommunications__r
                                                            WHERE  (Contact__c = :contId) AND ((AlertTypeRecord__r.Name IN :alertVal) OR (AlertType__c IN :alertDevName) OR (AlertType__c IN :alertVal)))
                                                    FROM Share_Class__c
                                                    WHERE Validity__c = TRUE AND Fund__c!=null AND Fund__r.Strategy__c!=null AND  
                                                            (Country__c INCLUDES (:countryCode) ) order by Fund__r.Strategy__r.Product_Name__c,Fund__r.Product_Name__c  asc ,Name asc]);
        /*else 
        return ([SELECT Id, Name, Fund__c, Fund__r.Product_Name__c,Fund__r.Name,ISIN_Code__c,Country__c,
                        Fund__r.Strategy__c,Fund__r.Strategy__r.Name,Fund__r.Strategy__r.Product_Name__c,
                        (SELECT AlertTypeRecord__r.Name,AlertTypeRecord__r.TECH_WebSiteID__c,AlertType__c,IsActive__c FROM WebCommunications__r
                         WHERE  (Contact__c = :contId) AND ((AlertTypeRecord__r.Name IN :alertVal) OR (AlertType__c IN :alertDevName) OR (AlertType__c IN :alertVal)))
                FROM Share_Class__c
                WHERE Validity__c = TRUE AND Fund__c!=null AND Fund__r.Strategy__c!=null AND (Country__c=null OR Country__c='')order by Fund__r.Strategy__r.Product_Name__c,Fund__r.Product_Name__c  asc ,Name asc]);*/
    }
}