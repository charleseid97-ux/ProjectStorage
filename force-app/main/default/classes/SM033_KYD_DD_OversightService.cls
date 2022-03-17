/**
 * Created by noorg on 04/06/2021.
 */

public with sharing class SM033_KYD_DD_OversightService {

    /**
     * @description if Level is changed (from low to high) update the related document list
     * @param newItems
     * @param oldItems
     */
    public static void updateKYDDocumentsLevel(Map<Id, KYD_Due_Diligence_Oversight__c> newItems, Map<Id, KYD_Due_Diligence_Oversight__c> oldItems) {
        System.debug('//NGO updateKYDDocumentsLevel '+newItems);
        List<KYD_Due_Diligence_Oversight__c> kydDDs = new List<KYD_Due_Diligence_Oversight__c>();

        for(KYD_Due_Diligence_Oversight__c kydDD : newItems.values())
            if(kydDD.Final_Risk__c != null && kydDD.Final_Risk__c != oldItems.get(kydDD.Id).Final_Risk__c) kydDDs.add(kydDD);

        System.debug('//NGO updateKYDDocumentsLevel kydDD '+kydDDs);
        if(!kydDDs.isEmpty()) upsert getDocumentList(kydDDs) ExternalId__c;
    }

    /**
     * //public static Map<String, Integer> levelMapValue = new Map<String, Integer>{'Low'=> 1, 'Medium'=> 2, 'High'=> 3};
     * @description Method to check if the Level has been changed to higher Value ie
     *                                  From Low -> Medium or High
     *                                  From Medium to -> High
     * @param newValue
     * @param oldValue
     *
     * @return

    private static boolean isLevelUpgraded(String newValue, String oldValue){
        //return  levelMapValue.get(newValue) > levelMapValue.get(oldValue);
        return true;
    } */

    /**
     * @description get list of document by due diligence oversight
     * @param kydDDs
     *
     * @return
     */
    private static List<KYD_Document__c> getDocumentList(List<KYD_Due_Diligence_Oversight__c> kydDDs){
        
        List<KYD_Document__c> documents = new List<KYD_Document__c>();
        System.debug('//NGO getDocumentList '+kydDDs);
        for(KYC_Document_Configuration__c configuration : [SELECT Id,EntityType__c,CollectiveFunds_personality__c,  KYD_Responsible__c,
                                                            RiskLevel__c, Name, Description__c, Mandatory__c, Format__c 
                                                            FROM KYC_Document_Configuration__c LIMIT 50000])
            for(KYD_Due_Diligence_Oversight__c kydOversight : kydDDs)
                if(isSameKey(kydOversight, configuration)) documents.add(createKYD(configuration, kydOversight));

        return documents;
    }

    /**
     * @description
     * @param kycDocumentConfiguration
     * @param kyd
     *
     * @return
     */
    private static KYD_Document__c createKYD(KYC_Document_Configuration__c kycDocumentConfiguration, KYD_Due_Diligence_Oversight__c kyd) {
        KYD_Document__c document = new KYD_Document__c();
        document.KYD_Due_Diligence_Oversight__c = kyd.Id;
        document.ExternalId__c = kyd.Id +'_'+kycDocumentConfiguration.Name;
        document.DocumentDescription__c = kycDocumentConfiguration.Description__c;
        document.Mandatory__c = kycDocumentConfiguration.Mandatory__c;
        document.DocumentFormat__c = kycDocumentConfiguration.Format__c;
        return document;
    }

    /**
     * @description
     * @param kyd
     * @param conf
     *
     * @return
     */
    private static boolean isSameKey(KYD_Due_Diligence_Oversight__c kyd, KYC_Document_Configuration__c conf) {
        //Key EntityType, KYD_Responsible, RiskLevel, CollectiveFunds_personality__c
        return kyd.EntityType__c.equals(conf.EntityType__c) && 
                kyd.KYD_Responsible__c.equals(conf.KYD_Responsible__c) && 
                 kyd.Final_Risk__c.equals(conf.RiskLevel__c) &&
                  kyd.CollectiveFunds_personality__c == conf.CollectiveFunds_personality__c;
    }

}