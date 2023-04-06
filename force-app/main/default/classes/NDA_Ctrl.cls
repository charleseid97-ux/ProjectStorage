/**
* Created by user on 30/06/2022.
*/

public with sharing class NDA_Ctrl {

    /**
     * @author JLC
     * @date 5/07/2022
     * @description validate NDA when stage changes to In progress
     *              1/ check if the NDA has a work together process related to it
     *              2/ check if the Case_Product attached to the Work_Together_Process (related to the NDA) is the same to the NDA_Product attached to the NDA
     * @param newItems NDAs list
     * @param oldMap old value NDAs
     */
    public static void validateNDAWhenInProgress(List<NDA__c> newItems, Map<Id, NDA__c> oldMap){

        String STAGE_IN_PROGRESS = 'In progress';
        String STAGE_TO_UPDATE = 'To update';

        List<NDA__c> validateNDAs = new List<NDA__c>();
        Map<Id, Id> ndaParentMap = new Map<Id, Id>();

        for(NDA__c nda : newItems){
            //Consider only NDA who stage has been updated to In progress
            if(oldMap.get(nda.Id).Stage__c.equals(STAGE_TO_UPDATE) && nda.Stage__c.equals(STAGE_IN_PROGRESS)){
                validateNDAs.add(nda);
                if (nda.Related_NDA__c != null) {
                	ndaParentMap.put(nda.Id, nda.Related_NDA__c);
                }
            }
        }

        if(validateNDAs.size() > 0) {
            Map<Id, NDA__c> ndaMap = new Map<Id, NDA__c>([SELECT Id, (SELECT Id FROM Work_Together_Processes__r),
            (SELECT Id, Share_Class__c FROM NDA_Products__r) FROM NDA__c WHERE Id IN : validateNDAs]);
            Id classicRT = RecordTypeUtil.getRecordTypeIdByDeveloperName(NDA__c.SObjectType, 'NDA_Classic');
            Id via_PlatformRT = RecordTypeUtil.getRecordTypeIdByDeveloperName(NDA__c.SObjectType, 'NDA_via_Platform');
            //Id via_ServiceProviderRT = RecordTypeUtil.getRecordTypeIdByDeveloperName(NDA__c.SObjectType, 'NDA_via_Service_Provider');

            for (NDA__c nda : validateNDAs) {

                if(ndaMap.get(nda.Id).Work_Together_Processes__r.size() == 0) {
                    nda.addError('This NDA should have at least one related Work Together Process');
                }

                validateIfProductListIsSameClassic(validateNDAs, ndaMap);

                if(nda.RecordTypeId == via_PlatformRT) {
                    validateIfProductListIsSamePlatform(validateNDAs, ndaParentMap);
                }

            }
        }
    }

    /**
     * @author JLC
     * @date 5/07/2022
     * @description validate Case_Product attached to the Work_Together_Process (related to the NDA) is the same to the NDA_Product attached to the NDA
     * @param ndas nda where stage has been changed to In progress
     * @param ndaMap
     */
    public static void validateIfProductListIsSameClassic(List<NDA__c> ndas, Map<Id, NDA__c> ndaMap ){

		Map<Id, List<Id>> NDAProductMap = new Map<Id, List<String>>();

        for (NDA__c nda : ndaMap.values()) {
            List<Id> products = new List<Id>();
            
            for(NDA_Product__c nda_products : nda.NDA_Products__r) {
                products.add(nda_products.Share_Class__c);
            }

            NDAProductMap.put(nda.Id, products);
        }

        for (Case_Product__c cp : [SELECT Id, Share_Class__c, Work_Together_Process__r.NDA__c
                                                 FROM Case_Product__c 
                                                 WHERE Work_Together_Process__r.NDA__c IN: ndas
                                                 ORDER BY Work_Together_Process__r.CreatedDate DESC]) {

            if (!NDAProductMap.containsKey(cp.Work_Together_Process__r.NDA__c) || (NDAProductMap.containsKey(cp.Work_Together_Process__r.NDA__c) && !NDAProductMap.get(cp.Work_Together_Process__r.NDA__c).contains(cp.Share_Class__c))) {
                ndas[0].addError('Product list does not correspond to the product list of the WTPs');
            }
        }
    }

    /**
     * @author JLC
     * @date 5/07/2022
     * @description validate Case_Product attached to the Work_Together_Process (related to the NDA) is the same to the NDA_Product attached to the Parent NDA
     * @param ndas nda where stage has been changed to In progress
     * @param ndaMap
     */
    public static void validateIfProductListIsSamePlatform(List<NDA__c> ndas, Map<Id, Id> ndaParent ){

        Map<Id, NDA__c> ndaMap = new Map<Id, NDA__c>([SELECT Id, (SELECT Id FROM Work_Together_Processes__r),
        (SELECT Id, Share_Class__c FROM NDA_Products__r) FROM NDA__c WHERE Id IN : ndaParent.values()]);

        Map<Id, List<Id>> NDAProductMap = new Map<Id, List<String>>();
        
        for (NDA__c nda : ndaMap.values()) {
            List<Id> products = new List<Id>();
            
            for(NDA_Product__c nda_products : nda.NDA_Products__r) {
                products.add(nda_products.Share_Class__c);
            }

            NDAProductMap.put(nda.Id, products);
        }
        
        for(Case_Product__c cp : [SELECT Id, Share_Class__c, Work_Together_Process__r.NDA__c, Work_Together_Process__r.NDA__r.Related_NDA__c
                                    FROM Case_Product__c
                                    WHERE Work_Together_Process__r.NDA__c IN: ndas
                                    ORDER BY Work_Together_Process__r.CreatedDate DESC]) {

            if (!NDAProductMap.containsKey(cp.Work_Together_Process__r.NDA__r.Related_NDA__c) || (NDAProductMap.containsKey(cp.Work_Together_Process__r.NDA__r.Related_NDA__c) && !NDAProductMap.get(cp.Work_Together_Process__r.NDA__r.Related_NDA__c).contains(cp.Share_Class__c))) {
                ndas[0].addError('Master NDA Product list does not correspond to the product list of the WTPs');
            }
        }
    }

}