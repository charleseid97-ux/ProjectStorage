/**
*@author GLC
*@Date Creation 11/5/2021
*@Date modification 
*@description update status field from KYC_Document__c object related list
*/
public class VFC01_KYDocuments{
    // current record id
    public ID pageID = ApexPages.currentPage().getParameters().get('id');
    public List<KYD_Document__c> getIDs;
    public Set<Id>setListIDs = new Set<Id>();
    public String documentIds{get;set;}

/**
*@author GLC
*@Date Creation 11/05/2021
*@Date modification
*@param standardSetController                 
*@return
*/     
    public VFC01_KYDocuments(ApexPages.StandardSetController controller){
        documentIds = ''; 
        getIDs = controller.getSelected();
        
        if (getIDs!=null)
                for(KYD_Document__c doc : getIDs){
                    setListIDs.add(doc.Id); 
                }
            
    }
/**
*@author GLC
*@Date Creation 11/05/2021
*@Date modification
*@param                 
*@return to current page location
*/ 
    public PageReference updateStatus(){
        String baseurl;
        String redirect;
        Map<Id,KYD_Document__c> updateKYCDocMap = new Map<Id,KYD_Document__c>([SELECT Id, Name 
                                                                                FROM KYD_Document__c 
                                                                                WHERE Id IN:setListIDs]);   
            //do your custom changes here
        if(setListIDs.size() > 0)
            
            for(KYD_Document__c docList: updateKYCDocMap.values()){
                docList.Status__c =Label.KYCDocStatus;
            }
            // update
            List<Database.SaveResult> results= Database.update(updateKYCDocMap.values(),false);
            for (Database.SaveResult result : results) {
                if (!result.isSuccess()){
                    for(Database.Error err : result.getErrors()){
                        System.debug('Error: '+ err.getStatusCode() + ' ' + err.getMessage());
                    }
                }
            }
        // redirect        
        baseurl = system.url.getSalesforceBaseUrl().toExternalForm();
        redirect = baseurl+'/'+ pageID;   
        PageReference pr = new PageReference(redirect);
        pr.setRedirect(true);
        return pr;
    }
/**
*@author GLC
*@Date Creation 11/05/2021
*@Date modification
*@param                 
*@return to current page location
*/ 
    public PageReference updateStatusToPending(){
        String baseurl;
        String redirect;
        Map<Id,KYD_Document__c> updateKYCDocMap = new Map<Id,KYD_Document__c>([SELECT Id, Name 
                                                                                FROM KYD_Document__c 
                                                                                WHERE Id IN:setListIDs]);   
            //do your custom changes here
        if(setListIDs.size() > 0)
            
            for(KYD_Document__c docList: updateKYCDocMap.values()){
                docList.Status__c =Label.KYDocStatusPending;
            }
            // update
            List<Database.SaveResult> results= Database.update(updateKYCDocMap.values(),false);
            for (Database.SaveResult result : results) {
                if (!result.isSuccess()){
                    for(Database.Error err : result.getErrors()){
                        System.debug('Error: '+ err.getStatusCode() + ' ' + err.getMessage());
                    }
                }
            }
        // redirect        
        baseurl = system.url.getSalesforceBaseUrl().toExternalForm();
        redirect = baseurl+'/'+ pageID;   
        PageReference pr = new PageReference(redirect);
        pr.setRedirect(true);
        return pr;
    }
    /**
    *@author GLC
    *@Date Creation 11/05/2021
    *@Date modification
    *@param                 
    *@return to current page location
    */ 
    public PageReference updateStatusToReceived(){
        String baseurl;
        String redirect;
        Map<Id,KYD_Document__c> updateKYCDocMap = new Map<Id,KYD_Document__c>([SELECT Id, Name 
                                                                                FROM KYD_Document__c 
                                                                                WHERE Id IN:setListIDs]);   
            //do your custom changes here
        if(setListIDs.size() > 0)
            
            for(KYD_Document__c docList: updateKYCDocMap.values()){
                docList.Status__c =Label.KYDocStatusReceived;
            }
            // update
            List<Database.SaveResult> results= Database.update(updateKYCDocMap.values(),false);
            for (Database.SaveResult result : results) {
                if (!result.isSuccess()){
                    for(Database.Error err : result.getErrors()){
                        System.debug('Error: '+ err.getStatusCode() + ' ' + err.getMessage());
                    }
                }
            }
        // redirect        
        baseurl = system.url.getSalesforceBaseUrl().toExternalForm();
        redirect = baseurl+'/'+ pageID;   
        PageReference pr = new PageReference(redirect);
        pr.setRedirect(true);
        return pr;
    }
}