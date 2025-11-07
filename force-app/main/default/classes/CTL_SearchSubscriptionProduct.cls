/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 14-02-2025
 * @last modified by  : Khadija EL GDAOUNI
**/
public with sharing class CTL_SearchSubscriptionProduct {
    
    public CTL_SearchSubscriptionProduct() {}

    @AuraEnabled(cacheable=true)
    public static List<Share_Class__c> getShareClasses() {
        return ([SELECT Id, Name, Fund__c, Fund__r.Product_Name__c,Fund__r.Name,   TechIsActive__c, ISIN_Code__c,Country__c,Share_Class_Type__c
                            FROM Share_Class__c
                            WHERE TechIsActive__c = TRUE order by Fund__r.Product_Name__c  asc ,Name asc]);
    }
    @AuraEnabled(cacheable=false)
    public static PickListFieldsValues getDistinctValues() {
        List<String> optionsCurrencyIsoCode = new List<String>();
        List<String> optionsDividendPolicy = new List<String>();
        List<String> optionsSharestypes = new List<String>();
        for (Share_Class__c shareClass : [SELECT Currency__c, DividendPolicy__c, Type__c FROM Share_Class__c WHERE TechIsActive__c = TRUE ORDER BY Type__c ]) {

            if(shareClass.Currency__c != null){
                optionsCurrencyIsoCode.add(shareClass.Currency__c);
            }
            if(shareClass.DividendPolicy__c != null){
                optionsDividendPolicy.add(shareClass.DividendPolicy__c);
            }
            if(shareClass.Type__c != null){
                optionsSharestypes.add(shareClass.Type__c);
            }
        }

        PickListFieldsValues plValues = new PickListFieldsValues(optionsDividendPolicy, optionsSharestypes, optionsCurrencyIsoCode);

        return plValues;
    }

    @AuraEnabled(cacheable=true)
    public static List<Product__c> getFundWithShareClasses() {
        return ([SELECT Id,Name,Product_Name__c,(SELECT Id, Name,ISIN_Code__c, Country__c FROM Share_Classes__r WHERE TechIsActive__c =true ORDER BY Name ASC) 
                    FROM Product__c WHERE Validity__c=true AND RecordType.Name='Fund'  ORDER BY Product_Name__c ASC]);
    }

    @AuraEnabled(cacheable=true)
    public static List<Share_Class__c> getShareClassesByCountry(String countryCode) {
        if (String.isNotBlank(countryCode)) {
            return ([SELECT Id, Name,Fund__c,Fund__r.Product_Name__c,Fund__r.Name,ISIN_Code__c,Country__c,
                                                            Fund__r.Strategy__c,Fund__r.Strategy__r.Name,Fund__r.Strategy__r.Product_Name__c,Share_Class_Type__c
                                                    FROM Share_Class__c
                                                    WHERE TechIsActive__c = TRUE AND Fund__c!=null AND Fund__r.Strategy__c!=null AND  
                                                            (Country__c INCLUDES (:countryCode) OR Country__c=null OR Country__c='') order by Fund__r.Strategy__r.Product_Name__c,Fund__r.Product_Name__c  asc ,Name asc]);
        }
        else {
            return ([SELECT Id, Name, Fund__c, Fund__r.Product_Name__c,Fund__r.Name,ISIN_Code__c,Country__c,
                        Fund__r.Strategy__c,Fund__r.Strategy__r.Name,Fund__r.Strategy__r.Product_Name__c,Share_Class_Type__c
                FROM Share_Class__c
                WHERE TechIsActive__c = TRUE AND Fund__c!=null AND Fund__r.Strategy__c!=null AND (Country__c=null OR Country__c='')order by Fund__r.Strategy__r.Product_Name__c,Fund__r.Product_Name__c  asc ,Name asc]);
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
        List<Id> shareClassCountryids = new List<Id>();
        /*for (ShareclassRegistration_Website__c shareClassReg : [SELECT Share_Class__c FROM ShareclassRegistration_Website__c WHERE Country__c =:countryCode AND isDisplay__c = true ]) {
            shareClassCountryids.add(shareClassReg.Share_Class__c);
        }*/
        if(countryCode =='XI'){
            countryCode = 'LU';
        }
        for (Country__c c : [
            SELECT ShareClass__c 
            FROM Country__c 
            WHERE Country__c = :countryCode AND ShareClass__c != null
        ]) {
            shareClassCountryids.add(c.ShareClass__c);
        }

        return ([SELECT Id, Name,Fund__c,Fund__r.ProductName__c,Fund__r.Name,ISIN__c,Type__c,Currency__c ,DividendPolicy__c,Hedged__c,
                                                            Fund__r.FundStrategy__c,Fund__r.FundStrategy__r.Code__c,Fund__r.FundStrategy__r.Name,
                                                            (SELECT AlertTypeRecord__r.Name,AlertTypeRecord__r.TECH_WebSiteID__c,AlertType__c,IsActive__c FROM WebCommunications__r
                                                            WHERE  (Contact__c = :contId) AND ((AlertTypeRecord__r.Name IN :alertVal) OR (AlertType__c IN :alertDevName) 
                                                            OR (AlertType__c IN :alertVal)))
                                                    FROM Share_Class__c
                                                    WHERE id IN :shareClassCountryids AND TechIsActive__c = TRUE AND Fund__c!=null AND Fund__r.FundStrategy__c!=null 
                                                     order by Fund__r.FundStrategy__r.Name,Fund__r.ProductName__c  asc ,Name asc]);
    }

    @AuraEnabled(cacheable=true)
    public static List<Product__c> getFundsWithSub(String cat,String contId, Integer counter){
        //get list picklist possible value
        ProspaceAlertType__mdt[] alerts = getAlertTypes(cat);
        Set<String> alertVal= new Set<String>();
        Set<String> alertDevName= new Set<String>();
        for(ProspaceAlertType__mdt mdt:alerts) {
            alertVal.add(mdt.MasterLabel);
            alertDevName.add(mdt.DeveloperName);
        }
        

        return ([SELECT Id, Name,ProductName__c ,FundStrategy__c,FundStrategy__r.Code__c,FundStrategy__r.Name,
                                                            (SELECT AlertTypeRecord__r.Name,AlertTypeRecord__r.TECH_WebSiteID__c,AlertType__c,IsActive__c FROM WebCommunications__r
                                                            WHERE  (Contact__c = :contId) AND ((AlertTypeRecord__r.Name IN :alertVal) OR (AlertType__c IN :alertDevName) 
                                                            OR (AlertType__c IN :alertVal))),(SELECT Id,ISIN__c FROM Share_Classes__r where Primary_Portfolio_Share_Class__c=true)
                                                    FROM Product__c
                                                    WHERE FundStrategy__c!=null
                                                    ORDER BY FundStrategy__r.Name,ProductName__c  asc ]);
    }

    public class PickListFieldsValues {

        @AuraEnabled
        public List<String> optionsDividendPolicy;
        @AuraEnabled
        public List<String> optionsSharestypes;
        @AuraEnabled
        public List<String> optionsCurrencyIsoCode;
        public PickListFieldsValues( List<String> optionsDividendPolicy, List<String> optionsSharestypes, List<String> optionsCurrencyIsoCode){
            
            this.optionsDividendPolicy = optionsDividendPolicy;
            this.optionsSharestypes = optionsSharestypes; 
            this.optionsCurrencyIsoCode = optionsCurrencyIsoCode;
        }
    }
}