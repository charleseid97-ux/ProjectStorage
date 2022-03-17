public with sharing class WTPProductDelete
{
    @InvocableMethod
    public static void WTPProductDeletion(List<Id> shareClassesIds)
    {
        List<Id> toDelete = new List<Id>();

		List<Case_Product__c> lstCaseProductFromShare = [SELECT Id, Share_Class__r.Validity__c, Share_Class__c,
                                                    Work_Together_Process__c
                                                FROM Case_Product__c
                                                WHERE Share_Class__c =: shareClassesIds
                                                AND Share_Class__r.Validity__c = FALSE];

        Set<Id> caseIds = WTPProductHelper.getCasesIds(lstCaseProductFromShare);

        Map<Id, List<Case_Product__c>> caseToProductsMap = WTPProductHelper.getCaseToProductMap(caseIds);

        for(Case_Product__c product : lstCaseProductFromShare)
        {
            if(caseToProductsMap.get(product.Work_Together_Process__c).size() > 1)
            {
                toDelete.add(product.Id);
            }
        }
        List<Case_Product__c> ToNotify = WTPProductHelper.getToNotify(shareClassesIds);

        WTPProductHelper.sendEmails(toNotify, 'Share_Closure_12_Days_Notification');

        if(toDelete.size() > 0)
        {
            try
            {
                Database.delete(toDelete, false);
                System.debug('Case Product deleted successfully');
            }
            catch(Exception e)
            {
                System.debug('The following exception has occurred: ' + e);
            }
        }
    }
}