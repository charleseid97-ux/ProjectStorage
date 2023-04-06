public class CaseProductHelper {
    public static void addCaseProductToNDA(List<Case_Product__c> itemsList) {
        Map<String, NDA_Product__c> ndaProducts = new Map<String, NDA_Product__c>();

        for (Case_Product__c caseProduct : itemsList) {
            if (caseProduct.Work_Together_Process__r.NDA__c == null) {
                break;
            }
            
            NDA_Product__c ndaProduct = new NDA_Product__c();
            ndaProduct.Share_Class__c = caseProduct.Share_Class__c;
            ndaProduct.CurrencyIsoCode = caseProduct.CurrencyIsoCode;
            ndaProduct.NDA__c = caseProduct.Work_Together_Process__r.NDA__c;
            ndaProduct.ShareClass__c = caseProduct.Share_Class__c + '' + ndaProduct.NDA__c;
            ndaProducts.put(ndaProduct.ShareClass__c, ndaProduct);
            
            if (caseProduct.Work_Together_Process__r.NDA__r.Related_NDA__c != null) {
                NDA_Product__c ndaRelatedProduct = ndaProduct.clone(false, true, true, false);
                ndaRelatedProduct.NDA__c = caseProduct.Work_Together_Process__r.NDA__r.Related_NDA__c;
                ndaRelatedProduct.ShareClass__c = caseProduct.Share_Class__c + '' + ndaRelatedProduct.NDA__c;
                ndaProducts.put(ndaRelatedProduct.ShareClass__c, ndaRelatedProduct);
            }
        }
        
        for (NDA_Product__c existingProduct : [Select id, ShareClass__c from NDA_Product__c where ShareClass__c in :ndaProducts.keySet()]) {
            ndaProducts.remove(existingProduct.ShareClass__c);
        }
        
        insert ndaProducts.values();
    }
}