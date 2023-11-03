/**
* @author: Noor Goolamnabee
* @date : 12/07/2019
* @description : WebCommunicationTriggerHandler
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 12-JUL-2019  JLC         1.0    Init
*
*/
public class SM029_WebCommunicationTriggerHandler {
    
    public static void onBeforeInsert(List<Web_Communication__c> webCommList) {
        
        Map<Web_Communication__c, String> mapWebCom = new Map<Web_Communication__c, String>();
        Map<Web_Communication__c, Id> shareClassIdByWebComIdMap = new Map<Web_Communication__c, Id>();
        Map<Web_Communication__c, Id> contactIdByWebComIdMap = new Map<Web_Communication__c, Id>();
        Map<Web_Communication__c, Id> LeadIdByWebComIdMap = new Map<Web_Communication__c, Id>();
        List<Web_Communication__c> webComFilteredList = new List<Web_Communication__c>();
        List<Web_Communication__c> webComAlertsName = new List<Web_Communication__c>();

        for (Web_Communication__c wCom : webCommList) {
            
            if (String.isNotBlank(wCom.TECH_ISINCode__c) && String.isBlank(wCom.ShareClass__c)) {
                mapWebCom.put(wCom, wCom.TECH_ISINCode__c);
            }

            if (wCom.ShareClass__c != null) {
                shareClassIdByWebComIdMap.put(wCom, wCom.ShareClass__c);

                if (wCom.Contact__c != null) {
                    contactIdByWebComIdMap.put(wCom, wCom.Contact__c);
                } else if (wCom.Lead__c != null) {
                    LeadIdByWebComIdMap.put(wCom, wCom.Lead__c);
                }

                webComFilteredList.add(wCom);
            }
            
            if (String.isNotBlank(wCom.AlertType__c)) {
                webComAlertsName.add(wCom); //modif ici pour adapter au custom metaData
            }

        }
        
        if (webCommList.size() > 0 && (contactIdByWebComIdMap.size() > 0 || LeadIdByWebComIdMap.size() > 0)){
            SM029_WebCommunication.handleCountryError(webComFilteredList, contactIdByWebComIdMap, LeadIdByWebComIdMap, shareClassIdByWebComIdMap);
        }
        
        if (!mapWebCom.isEmpty()) {
            SM029_WebCommunication.updateShareClass(mapWebCom);
        }
        
        if (webComAlertsName.size() > 0) {
            SM029_WebCommunication.updateLookupAlertType(webComAlertsName);
        }
    }
    
    public static void onAfterInsert(List<Web_Communication__c> webCommList) {              
        //Treat only when sending one communication at a time --> not anymore        
        List<Web_Communication__c> activeWebCom = new List<Web_Communication__c>();
        
        for (Web_Communication__c webComm : webCommList) {
            if (webComm.isActive__c) {
                activeWebCom.add(webComm);
            }
        }
        
        //batch size was one, check if any performance problem
        System.enqueueJob(new SM029_SendSelectedWebCommAsync(activeWebCom, 0, 200));
    }

    public static void onAfterUpdate(List<Web_Communication__c> newList, Map<Id, Web_Communication__c> oldMap) {
        List<Web_Communication__c> webComList = new List<Web_Communication__c>();

        for (Web_Communication__c webComm : newList) {
            if (oldMap.get(webComm.Id).isActive__c != webComm.isActive__c) {
                webComList.add(webComm);
            }
        }

        if (webComList.size() > 0) {
            System.enqueueJob(new SM029_UpdateWebsiteCommunication(webComList, 0, 200));
        }
    }

    public static void onAfterDelete(List<Web_Communication__c> webCommList) {
        
        List<Web_Communication__c> webCommToDeleteList = new List<Web_Communication__c>();
        for (Web_Communication__c sWeb : webCommList) {
            if(!String.isEmpty(sWeb.TECH_CommunicationWebsiteId__c)) {
                webCommToDeleteList.add(sWeb);
            }
        }
        
        if (webCommToDeleteList.size() > 0){
            ID jobID = System.enqueueJob(new SM029_DeleteWebsiteWebCommAsync(webCommToDeleteList, 0, 200));
            System.debug('//enqueueJob  job 0 : ' +jobID);
        }
    }
}