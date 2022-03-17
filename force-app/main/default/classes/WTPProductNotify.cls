public with sharing class WTPProductNotify 
{
    @InvocableMethod
    public static void WTPProductNotify(List<Id> shareClassesIds)
    {
        List<Case_Product__c> ToNotify = WTPProductHelper.getToNotify(shareClassesIds);

        WTPProductHelper.sendEmails(toNotify, 'Share_Closure_7_Days_Notification');
    }
}