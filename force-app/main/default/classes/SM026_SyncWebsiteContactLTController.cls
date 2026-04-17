public class SM026_SyncWebsiteContactLTController {
    
    private static String  CLASS_NAME = SM026_SyncWebsiteContactLTController.class.getName();
    
    
    @AuraEnabled
    public static void syncProspaceDetails(Id aContactId) {
        
        String methodName = 'syncProspaceDetails';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [aContactId] : ' + aContactId);
        
        //System.debug('object is '+ aContactId.getsobjecttype());
        
        String objectType = aContactId.getSObjectType().getDescribe().getName();
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [objectType] : ' + objectType);
        
        if(objectType == 'Contact'){
            syncWebsiteContactDetails(aContactId);
        }else{
            syncWebsiteLeadDetails(aContactId);
        }
        
    }
    
    
    @AuraEnabled
    public static void syncWebsiteContactDetails(Id aContactId) {
        
        String methodName = 'syncWebsiteContactDetails';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [aContactId] : ' + aContactId);
        
        List<Contact> contactList = SM026_Contact_Website.retrieveContacts(new Set<Contact>{new Contact(Id = aContactId)});
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [contactList] : ' + contactList);
        
        //commented: to prevent standard fields to erase website fields
        //contactList = processContact.populateContactWebsiteFields(contactList);
        Contact contactToProcess = contactList[0];
        if(contactToProcess.WebsiteLogin__c == null ||
           contactToProcess.LastNameWebsite__c == null ||
           contactToProcess.WebsiteLanguage__c == null ||
           contactToProcess.WebsiteCountry__c == null ||
           contactToProcess.WebsiteCompany__c == null ||
           contactToProcess.WebsiteSalutation__c == null ||
           contactToProcess.FirstNameWebsite__c == null ||
           contactToProcess.WebsiteJobTitle__c == null ||
           contactToProcess.Address1__c == null ||
           contactToProcess.City__c == null ||
           contactToProcess.PostalCode__c == null ||
           contactToProcess.Country__c == null ||
           contactToProcess.PhoneNumber__c == null){
               String erro = Label.Website_Sync_Failed;
               throw new AurahandledException(erro);
           }else{
               
               try{
                   ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [contactList] : ' + contactList);
                   SM026_Contact_Website.processSelectedContacts(contactList);
               }catch(DmlException e){
                   String err = e.getDmlMessage(0);
                   if(err.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'))
                   {
                       String erro = err.Substring(err.indexof('FIELD_CUSTOM_VALIDATION_EXCEPTION, ')+35,err.indexof(': []'));
                       
                       throw new AurahandledException(erro);
                       
                   }
               }
           }
        
        
        
    }
    
    @AuraEnabled
    public static void syncWebsiteLeadDetails(Id aLeadId) {
        
        String methodName = 'syncWebsiteLeadDetails';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [aLeadId] : ' + aLeadId);
        
        SM026_Lead_Website processLead = new SM026_Lead_Website();
        Set<Id> leadIdSet = new Set<Id>();
        leadIdSet.add(aLeadId);
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [leadIdSet] : ' + leadIdSet);
        
        List<Lead> LeadList = SM026_Lead_Website.retrieveLeads(leadIdSet);
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [LeadList] : ' + LeadList);
        
        try{
            processLead.processSelectedLeads(LeadList);
            ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [LeadList] : ' + LeadList);
            
        }catch(DmlException e){
            String err = e.getDmlMessage(0);
            if(err.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'))
            {
                String erro = err.Substring(err.indexof('FIELD_CUSTOM_VALIDATION_EXCEPTION, ')+35,err.indexof(': []'));
                
                throw new AurahandledException(erro);
                
            }
        }
        
    }
    
    
    
}