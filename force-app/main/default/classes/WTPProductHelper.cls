public with sharing class WTPProductHelper 
{
    public static Map<Id, List<Case_Product__c>> getCaseToProductMap(Set<Id> caseIds)
    {
        List<Case_Product__c> lstCaseProductFromCase = [
                SELECT Id, Share_Class__r.Validity__c, Share_Class__c,
                        Work_Together_Process__c, Work_Together_Process__r.Owner.Email
                FROM Case_Product__c
                WHERE Work_Together_Process__c =: caseIds
        ];

        Map<Id, List<Case_Product__c>> caseToProduct = new Map<Id, List<Case_Product__c>>();

        for(Case_Product__c product : lstCaseProductFromCase)
        {
            if(caseToProduct.get(product.Work_Together_Process__c) == null)
            {
                caseToProduct.put(product.Work_Together_Process__c, new List<Case_Product__c>{product});
            }
            else
            {
                caseToProduct.get(product.Work_Together_Process__c).add(product);
            }
        }
        return caseToProduct;
    }
    public static Set<Id> getCasesIds(List<Case_Product__c> lstCaseProduct)
    {
        Set<Id> caseIds = new Set<Id>();

        for(Case_Product__c product : lstCaseProduct)
        {
            caseIds.add(product.Work_Together_Process__c);
        }
        return caseIds;
    }  
    public static void sendEmails(List<Case_Product__c> toNotify, String templateName)
    {
        Map<Messaging.SingleEmailMessage, Contact> mailContacts =
            new Map<Messaging.SingleEmailMessage, Contact>();

        EmailTemplate emailTemplate = [SELECT Id, DeveloperName 
                                        FROM EmailTemplate 
                                        WHERE DeveloperName =: templateName];

        for(Case_Product__c caseProduct : toNotify)
        {
            Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();
            mail.setTemplateId(emailTemplate.Id);
            mail.setWhatId(caseProduct.Share_Class__c);
            Contact contact = new Contact(LastName = 'Temporary Contact', Email = caseProduct.Work_Together_Process__r.Owner.Email, Source__c = 'Event', Language__c = 'French');
            String[] ccAddresses = new String[] {Label.WTPccAddresses};
            mail.setccAddresses(ccAddresses);
            mailContacts.put(mail, contact);
        }
        if (mailContacts.size() > 0) insert mailContacts.values();
        for (Messaging.SingleEmailMessage mail : mailContacts.keySet())
        {
            mail.setTargetObjectId(mailContacts.get(mail).Id);
        }
        System.debug('SLI mailContacts '+ mailContacts);
        if(!Test.IsRunningTest())
        {
	        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>(mailContacts.keySet()));
        }
        if (mailContacts.size() > 0) delete mailContacts.values();
        
    }
    
    public static List<Case_Product__c> getToNotify(List<Id> shareClassesIds)
    {
        List<Case_Product__c> ToNotify = new List<Case_Product__c>();

		List<Case_Product__c> lstCaseProductFromShare = [SELECT Id, Share_Class__r.Validity__c, Share_Class__c,
                                                    Work_Together_Process__c, Work_Together_Process__r.Owner.Email
                                                FROM Case_Product__c
                                                WHERE Share_Class__c =: shareClassesIds
                                                AND Share_Class__r.Validity__c = FALSE];

        Set<Id> caseIds = WTPProductHelper.getCasesIds(lstCaseProductFromShare);

        Map<Id, List<Case_Product__c>> caseToProductsMap = WTPProductHelper.getCaseToProductMap(caseIds);

        for(Case_Product__c product : lstCaseProductFromShare)
        {
            if(caseToProductsMap.get(product.Work_Together_Process__c).size() > 1)
            {
                Set<Id> shareClassesSet = new Set<Id>(shareClassesIds);
                for(Case_Product__c caseProduct : caseToProductsMap.get(product.Work_Together_Process__c))
                {
                    if(shareClassesSet.contains(caseProduct.Share_Class__c))
                    {
                        ToNotify.add(caseProduct);
                    }
                }
            }
        }
        return ToNotify;
    }
}