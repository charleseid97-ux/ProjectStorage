public class SM026_ResetProSpacePasswordLTController {
    
    private static String  CLASS_NAME = SM026_ResetProSpacePasswordLTController.class.getName();

    
    @AuraEnabled
    public static boolean checkWebsiteId(Id aContactId) {
        
        String methodName = 'checkWebsiteId';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [aContactId] : ' + aContactId);
        
        String objectType = aContactId.getSObjectType().getDescribe().getName();
        
        if(objectType == 'Contact'){
            List<Contact> recordList = [SELECT Id, TECH_WebSiteID__c FROM Contact WHERE Id = :aContactId LIMIT 1];
            if(recordList[0].TECH_WebSiteID__c != null && recordList[0].TECH_WebSiteID__c != ''){
                return true;
            }else{
                return false;
            }
        }else{
            List<Lead> recordList = [SELECT Id, TECH_WebSiteID__c FROM Lead WHERE Id = :aContactId LIMIT 1];
            if(recordList[0].TECH_WebSiteID__c != null && recordList[0].TECH_WebSiteID__c != ''){
                return true;
            }else{
                return false;
            }
            
        }

    }
    
    
    @AuraEnabled
    public static void resetProspacePass(Id aContactId) {
        
        String methodName = 'resetProspacePass';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [aContactId] : ' + aContactId);
        
        String objectType = aContactId.getSObjectType().getDescribe().getName();
        System.debug(objectType);
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [objectType] : ' + objectType);

        if(objectType == 'Contact'){
            
            ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [aContactId] : ' + aContactId);

            List<Contact> contactList = SM026_Contact_Website.retrieveContacts(new Set<Contact>{new Contact(Id = aContactId)});
            
            if(!String.isBlank(contactList[0].TECH_WebSiteID__c)){
                
                try{
                    ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [contactList] : ' + contactList);
                    SM026_Contact_Website.processResetContactPassword(contactList);
                }catch(DmlException e){
                    String err = e.getDmlMessage(0);
                    if(err.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'))
                    {
                        String erro = err.Substring(err.indexof('FIELD_CUSTOM_VALIDATION_EXCEPTION, ')+35,err.indexof(': []'));
                        throw new AurahandledException(erro);
                        
                    }
                }
            }
        }else{
            SM026_Lead_Website leadWebObj = new SM026_Lead_Website();
            Set<Id> leadIdSet = new Set<Id>();
            leadIdSet.add(aContactId);
            ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [leadIdSet] : ' + leadIdSet);

            List<Lead> leadList = SM026_Lead_Website.retrieveLeads(leadIdSet);
            ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [leadList] : ' + leadList);

            if(!String.isBlank(leadList[0].TECH_WebSiteID__c)){
                
                try{
                    ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [leadList] : ' + leadList); 
                    leadWebObj.processResetLeadPassword(leadList);
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
        
        
        
    }
    
}