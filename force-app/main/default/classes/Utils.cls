/**
 * Created by Noor on 3/15/2021.
 */

public with sharing class Utils {

    public static Map<String, LegalEntityRoleMapping__mdt> legalEntityRoleMapping {get; set;}

    public static Map<String, Global_Settings__mdt> globalSettings {get; set;}

    public static Map<String, String> agreementRoleMapping {get; set;}

    /**
     * @author Noor
     * @date 3/15/2021.
     * @description Get All settings in the Custom meta data for legalEntityRoleMapping
     *
     * @return
     */
    public static Map<String, LegalEntityRoleMapping__mdt> getLegalEntityRoleMapping() {
        if(legalEntityRoleMapping == null || legalEntityRoleMapping.isEmpty()) {
            legalEntityRoleMapping = new Map<String, LegalEntityRoleMapping__mdt>();
            for (LegalEntityRoleMapping__mdt  mdt : [SELECT Id, DeveloperName, Label, Source__c, Result__c FROM LegalEntityRoleMapping__mdt]) legalEntityRoleMapping.put(mdt.Label, mdt);
        }

        return legalEntityRoleMapping;
    }

    @AuraEnabled(Cacheable = true)
    public static String getURLBoard() {
        Map<String, Global_Settings__mdt> values = Global_Settings__mdt.getAll();
        return values.get('board').Value__c;
    }

    @AuraEnabled(Cacheable = true)
    public static String getURLProjection() {
        Map<String, Global_Settings__mdt> values = Global_Settings__mdt.getAll();
        return values.get('projection').Value__c;
    }

    /**
     * @author Noor
     * @date 16/01/2021
     * @description get all Custom metadata to map code type and agreement role
     * @return Map<String, Agreement_Role_Mapping__mdt>
     */
    public static Map<String, String> getAgreementRoleSettings() {
        if(agreementRoleMapping == null || agreementRoleMapping.isEmpty()) {
            agreementRoleMapping = new Map<String, String>();
            for (Agreement_Role_Mapping__mdt mdt : Agreement_Role_Mapping__mdt.getAll().values()) agreementRoleMapping.put(mdt.Label, mdt.AgreementRole__c);
        }
        return agreementRoleMapping;
    }

    /**
     * @author Noor
     * @date 16/01/2021
     * @description get all Global_Settings__mdt entries
     * @return Map<String, Global_Settings__mdt>
     */
    public static Map<String, Global_Settings__mdt> getGlobalSettings() {
        if(globalSettings == null || globalSettings.isEmpty()) {
            globalSettings = new Map<String, Global_Settings__mdt>();
            for (Global_Settings__mdt mdt : Global_Settings__mdt.getAll().values()) globalSettings.put(mdt.DeveloperName, mdt);
        }

        return globalSettings;
    }

    /**
    * @author Noor
    * @date 08/11/2022
    * @description get all Global_Settings__mdt entries by label
    * @return Map<String, Global_Settings__mdt>
    */
    public static Map<String, Global_Settings__mdt> getGlobalSettingsByLabel() {
        if(globalSettings == null || globalSettings.isEmpty()) {
            globalSettings = new Map<String, Global_Settings__mdt>();
            for (Global_Settings__mdt mdt : Global_Settings__mdt.getAll().values()) globalSettings.put(mdt.Label, mdt);
        }

        return globalSettings;
    }
}