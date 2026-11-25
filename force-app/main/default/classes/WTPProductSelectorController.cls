/** ──────────────────────────────────────
 * @description Controller of the wtpProductSelector LWC: tells whether a Work Together Process (Case) already has linked products, so the LWC opens the WTP_Product_Selector flow only while it has none.
 * @author Charles EID
 * @testClass WTPProductSelectorControllerTest
 * @coverage 100%   [25-11-26]
 ────────────────────────────────────── */
public with sharing class WTPProductSelectorController {

    @AuraEnabled
    public static Boolean hasLinkedProducts(Id wtpId) {
        return ![SELECT Id FROM Work_Together_Process_Product__c WHERE Work_Together_Process__c = :wtpId LIMIT 1].isEmpty();
    }
}
