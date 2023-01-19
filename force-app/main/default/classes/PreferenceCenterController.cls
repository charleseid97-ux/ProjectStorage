/*
* Created By : Noor Goolamnabee 
* Description : Controller for the Lightning Web Component lwc_preferencecenter
* Date Created : 26/07/2022
* Test Class : PreferenceCenterControllerTest
*/
public with sharing class PreferenceCenterController {
    //START : Wrapper Classes
    //Description : Wrapping ALert Type Object for conditional rendering in the component
    public class AlertTypeStructure {
        String alertTypeId;
        String alertTypeName;
        Boolean alertTypeIsPublished;
        Boolean prospaceAlertCreated;
    }
    //Description : Wrapping ALert Types and Prospace Alerts to avoid several calls to Server/APEX
    public class AlertTypesWithProspaceAlert {
        List<AlertTypeStructure> alertTypeStructureList;
        List<Web_Communication__c> prospaceAlertList;
    }
    //END : Wrapper Classes
    
    //Description: Returns an Alert Type List
    public static List<AlertType__c> getAlertTypes(String contactId){
        List<AlertType__c> alertTypeList = new List<AlertType__c>();
        try {
            if(String.isNotBlank(contactId)){
                List<Contact> prospaceContact = [SELECT  WebsiteCountryLanguage__c 
                                                 FROM Contact
                                                 WHERE Id =: Id.valueOf(contactId) 
                                                 AND TECH_WebSiteID__c != NULL 
                                                 AND Synchrostatus__c = 'Success' WITH SECURITY_ENFORCED];
                if(!prospaceContact.isEmpty()) {
                    String conWebsiteCountryLang = '%' + prospaceContact[0].WebsiteCountryLanguage__c + '%';
                    alertTypeList = [SELECT Id, Name, isPublication__c, TECH_WebSiteID__c, Site__c 
                                     FROM AlertType__c 
                                     WHERE Site__c LIKE :conWebsiteCountryLang WITH SECURITY_ENFORCED];
                }
            } else {
                System.debug('NGO : getAlertTypes : Parameter : contactId may be BLANK.');
            }   
        } catch (Exception exceptionHandler) {
            debugForCatchExceptions(exceptionHandler, 'getAlertTypes');
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
        return alertTypeList;
    }
    
    //Description: Returns a Prospace Alerts List
    public static List<Web_Communication__c> getProspaceAlerts(String contactId){
        List<Web_Communication__c> prospaceAlertList = new List<Web_Communication__c>();
        try {
            if(String.isNotBlank(contactId)){
                prospaceAlertList = [SELECT Id, Fund__r.Name, ShareClass__r.Name, AlertTypeRecord__c, Synchro_Status__c, ShareClass__r.ISIN_Code__c 
                                     FROM Web_Communication__c 
                                     WHERE Contact__c = :Id.valueOf(contactId) 
                                     AND Contact__r.TECH_WebSiteID__c != NULL 
                                     AND Contact__r.Synchrostatus__c = 'Success' WITH SECURITY_ENFORCED];
            } else {
                System.debug('NGO : getProspaceAlerts : Parameter : contactId may be BLANK.');
            }         
        } catch (Exception exceptionHandler) {
            debugForCatchExceptions(exceptionHandler, 'getProSpaceAlerts');
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
        return prospaceAlertList;
    }
    
    //Description: Returns a JSON String comprising of a List of Alert Types and List of Prospace Alerts
    @AuraEnabled(cacheable=true)
    public static String getAlertTypesWithProspaceAlert(String contactId){
        AlertTypesWithProspaceAlert alertTypesWithProspaceAlertList = new AlertTypesWithProspaceAlert();
        List<AlertTypeStructure> alertTypeStructureFinalList = new List<AlertTypeStructure>();
        
        if(String.isNotBlank(contactId)){
            //Getting the Alert Types and Prospace Alerts Lists
            List<AlertType__c> alertTypeInitialList = getAlertTypes(contactId);
            List<Web_Communication__c> prospaceAlertInitialList = getProspaceAlerts(contactId);            
            Set<Id> prospaceRelatedAlertTypeIDSet = new Set<Id>();
            
            //Obtaining the existing Alert Types IDs linked to Prospace Alerts
            for(Web_Communication__c eachProspace : prospaceAlertInitialList){
                prospaceRelatedAlertTypeIDSet.add(eachProspace.AlertTypeRecord__c);
            }
            //Building the wrapped Alert Type Object
            for(AlertType__c eachAlertType : alertTypeInitialList){
                AlertTypeStructure newAlertTypeStructureObj = new AlertTypeStructure();
                newAlertTypeStructureObj.alertTypeId = eachAlertType.Id;
                newAlertTypeStructureObj.alertTypeName = eachAlertType.Name;
                newAlertTypeStructureObj.alertTypeIsPublished = eachAlertType.isPublication__c;
                newAlertTypeStructureObj.prospaceAlertCreated = prospaceRelatedAlertTypeIDSet.contains(eachAlertType.Id) ? true : false; //Checking for existing Alert Types linked to Prospace Alert
                alertTypeStructureFinalList.add(newAlertTypeStructureObj);
            }
            //Building the final Wrapper Class for Alert Types and Prospace Alerts
            alertTypesWithProspaceAlertList.alertTypeStructureList = alertTypeStructureFinalList;
            alertTypesWithProspaceAlertList.prospaceAlertList = prospaceAlertInitialList;
        }
        //Returning a serialized JSON object of the final Wrapper Class
        return JSON.serialize(alertTypesWithProspaceAlertList);
    }
    //- Description: Creates Prospace Alerts
    //- Parameters : 
    //-		contactId: Contact Id from the Contact's Record Page
    //-		alertTypeId : Alert Type Id from the Toggle Buttons
    //-		fundId : Fund Id from the Standard Lookup Field
    //-		shareClassId : Share Class Id from the custom component : lwc_lookupfield_filtercriteria
    @AuraEnabled
    public static Boolean createProspaceAlerts(String contactId, String alertTypeId, String fundId, String shareClassId, Boolean isPublication){
        Boolean isProspaceAlertCreated = false;
        List<Web_Communication__c> webCommunicationList = new List<Web_Communication__c>();
        List<Web_Communication__c> existingProspaceAlertsList = new List<Web_Communication__c>();
        try {
            //Checking for existing Prospace Alerts
            if(!isPublication && String.isNotBlank(contactId) && String.isNotBlank(alertTypeId) && String.isNotBlank(fundId) && String.isNotBlank(shareClassId)){
                existingProspaceAlertsList = [SELECT Id FROM Web_Communication__c 
                                              WHERE Contact__c =: Id.valueOf(contactId) 
                                              AND AlertTypeRecord__c =: Id.valueOf(alertTypeId) 
                                              AND Fund__c =: Id.ValueOf(fundId) 
                                              AND ShareClass__c =: Id.valueOf(shareClassId) WITH SECURITY_ENFORCED];
                
            } else {
                existingProspaceAlertsList = [SELECT Id FROM Web_Communication__c 
                                              WHERE Contact__c =: Id.valueOf(contactId) 
                                              AND AlertTypeRecord__c =: Id.valueOf(alertTypeId) WITH SECURITY_ENFORCED];
            }
            if(existingProspaceAlertsList.size() == 0){
                Web_Communication__c newWebCommunication = new Web_Communication__c();
                if(isPublication){
                    newWebCommunication.Contact__c = Id.valueOf(contactId);
                    newWebCommunication.AlertTypeRecord__c = Id.valueOf(alertTypeId);
                } else {
                    if(String.isNotBlank(contactId) && String.isNotBlank(alertTypeId) && String.isNotBlank(fundId) && String.isNotBlank(shareClassId)){
                        newWebCommunication.Contact__c = Id.valueOf(contactId);
                        newWebCommunication.AlertTypeRecord__c = Id.valueOf(alertTypeId);
                        newWebCommunication.Fund__c = Id.valueOf(fundId);
                        newWebCommunication.ShareClass__c = Id.valueOf(shareClassId);  
                    }
                }
                webCommunicationList.add(newWebCommunication);
                Database.SaveResult[] saveResultList = Database.insert(webCommunicationList, true);
                //SaveResult to ensure that Prospace Alert has been successfully created
                for (Database.SaveResult eachSaveResult : saveResultList) {
                    //If a Prospace Alert has been created, a Boolean is returned to initiate follow up actions like notifying users. 
                    if (eachSaveResult.isSuccess() && eachSaveResult.getId() != NULL) {
                        isProspaceAlertCreated = true;
                    } else {            
                        for(Database.Error eachError : eachSaveResult.getErrors()) {                 
                            System.debug('The following error has occurred ==> ' + eachError.getStatusCode() + ': ' + eachError.getMessage());
                            System.debug('Pro Space Alert fields that affected this error: ' + eachError.getFields());
                        }
                    } 
                }
            } else {
                isProspaceAlertCreated = false;
            }
        } catch (Exception exceptionHandler) { 
            debugForCatchExceptions(exceptionHandler, 'createProspaceAlerts');
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
        return isProspaceAlertCreated;
    }
    //- Description: Deletes a Prospace Alert
    //- Parameter : prospaceAlertId - Selected Prospace Alert Type Id to delete
    @AuraEnabled
    public static Boolean deleteProspaceAlerts(String prospaceAlertId, String alertTypeId, Boolean isPublication){
        Boolean isProspaceAlertDeleted = false;
        try {
            List<Web_Communication__c> webCommunicationQueryList = new List<Web_Communication__c>();
            
            if(!isPublication && String.isNotBlank(prospaceAlertId)){
                webCommunicationQueryList = [SELECT Id FROM Web_Communication__c WHERE Id =: Id.valueOf(prospaceAlertId) WITH SECURITY_ENFORCED];
            } else {
                webCommunicationQueryList = [SELECT Id FROM Web_Communication__c WHERE AlertTypeRecord__c =: Id.valueOf(alertTypeId) WITH SECURITY_ENFORCED];
            }
            
            if(webCommunicationQueryList.size() > 0){
                Database.DeleteResult[] deleteResultList = Database.delete(webCommunicationQueryList, true);
                for(Database.DeleteResult eachDeleteResult : deleteResultList) {
                    if (eachDeleteResult.isSuccess() && eachDeleteResult.getId() != NULL) {
                        isProspaceAlertDeleted = true;
                    }
                    else {               
                        for(Database.Error eachError : eachDeleteResult.getErrors()) {                 
                            System.debug('The following error has occurred => ' + eachError.getStatusCode() + ' : ' + eachError.getMessage());
                        }
                    }
                }
            } else {
                System.debug('NGO : deleteProspaceAlerts : List : webCommunicationQueryList may be EMPTY.');
            }
        } catch (Exception exceptionHandler) { 
            debugForCatchExceptions(exceptionHandler, 'deleteProSpaceAlerts');
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
        return isProspaceAlertDeleted;
    }
    //- Description: Creates all Prospace Alerts for all the Alert Types
    //- Parameters : 
    // 		- recordId :  Contact Id from Contact Record Page
    // 		- selectedAlertTypesList : List of Alert Types Ids
    @AuraEnabled
    public static void createAllProspaceAlerts(String recordId, List<String> selectedAlertTypesList) {
        id convertedRecordId = Id.valueOf(recordId);
        Contact contactQueryObj = new Contact();
        Lead leadQueryObj = new Lead();
        String sObjectName = convertedRecordId.getSObjectType().getDescribe().getName();
        try {
            if(sObjectName == 'Contact'){
                contactQueryObj = [SELECT Id, WebsiteCountry__c, Prospace_Status__c, TECH_WebSiteID__c FROM Contact WHERE Id = :convertedRecordId WITH SECURITY_ENFORCED];
                if(String.isNotBlank(contactQueryObj.TECH_WebSiteID__c) && contactQueryObj.Prospace_Status__c == 'Validated'){
                    if(selectedAlertTypesList.size() > 0){
                        SM029_WebCommunication.addAllContactAlerts(contactQueryObj, selectedAlertTypesList);
                    } else {
                       System.debug('NGO : createAllProspaceAlerts : CONTACT : selectedAlertTypesList Parameter is EMPTY.'); 
                    }
                }
            } else {
                leadQueryObj = [SELECT Id, WebsiteCountry__c, Prospace_Status__c, TECH_WebSiteID__c FROM Lead WHERE Id = :convertedRecordId WITH SECURITY_ENFORCED];
                if(String.isNotBlank(leadQueryObj.TECH_WebSiteID__c) && leadQueryObj.Prospace_Status__c == 'Validated'){
                    if(selectedAlertTypesList.size() > 0){
                        SM029_WebCommunication.addAllLeadAlerts(leadQueryObj, selectedAlertTypesList);
                    } else {
                        System.debug('NGO : createAllProspaceAlerts : LEAD : selectedAlertTypesList Parameter is EMPTY.'); 
                    }
                }
            }
        } catch (Exception exceptionHandler) { 
            debugForCatchExceptions(exceptionHandler, 'createAllProspaceAlerts');
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
    }
    //- Description: Deletes all Prospace Alerts for all the Alert Types
    //- Parameters : 
    // 		- recordId :  Contact Id from Contact Record Page
    // 		- selectedAlertTypesList : List of Alert Types Ids
    @AuraEnabled
    public static void deleteAllProspaceAlerts(String recordId, List<String> selectedAlertTypesList) {    
        id convertedRecordId = Id.valueOf(recordId);
        Contact contactQueryObj = new Contact();
        Lead leadQueryObj = new Lead();
        String sObjectName = convertedRecordId.getSObjectType().getDescribe().getName();
        try {
            if(sObjectName == 'Contact'){
                contactQueryObj = [SELECT Id, WebsiteCountry__c, Prospace_Status__c, TECH_WebSiteID__c FROM Contact WHERE Id = :convertedRecordId WITH SECURITY_ENFORCED];
                if(String.isNotBlank(contactQueryObj.TECH_WebSiteID__c)){
                    if(selectedAlertTypesList.size() > 0){
                        SM029_WebCommunication.deleteAllProspaceAlerts(contactQueryObj, selectedAlertTypesList);
                    } else {
                        System.debug('NGO : deleteAllProspaceAlerts : CONTACT : selectedAlertTypesList Parameter is EMPTY.'); 
                    }
                }
            } else {
                leadQueryObj = [SELECT Id, WebsiteCountry__c, Prospace_Status__c, TECH_WebSiteID__c FROM Lead WHERE Id = :convertedRecordId WITH SECURITY_ENFORCED];
                if(String.isNotBlank(leadQueryObj.TECH_WebSiteID__c)){
                    if(selectedAlertTypesList.size() > 0){
                        SM029_WebCommunication.deleteAllProspaceAlerts(leadQueryObj, selectedAlertTypesList);
                    } else {
                        System.debug('NGO : deleteAllProspaceAlerts : LEAD : selectedAlertTypesList Parameter is EMPTY.'); 
                    }
                }
            }
        } catch (Exception exceptionHandler) { 
            debugForCatchExceptions(exceptionHandler, 'deleteAllProspaceAlerts');
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
    }
    //START : Marketing Emails Section ----------------------------------------------------------------------------------------------------------------------------------
    //STARt : Wrapper Classes
    //Description : Used to create a JSON with Communication Types Checkboxes with their values
    public class CommunicationType {
        String checkboxAPI;
        Boolean checkboxValue;
    }
    //Description : Used to create a JSON with Interest Checkboxes with their values
    public class SubInterest {
        String SubCheckboxLabel;
        String SubCheckboxAPI;
        Boolean SubCheckboxValue;
    }
    public class InterestUnwrap {
        String checkboxAPI;
        Boolean checkboxValue;
    }
    //END : Wrapper Classes
    //Description : To obtain the value of HasOptedOutOfEmail for the  Marketing Emails Section Opt Out Toggle Button
    @AuraEnabled(cacheable=true)
    public static List<Contact> getContactInfo(String contactId){
        List<Contact> contactsList = new List<Contact>();
        try {
            contactsList = [SELECT Id, HasOptedOutOfEmail FROM Contact WHERE Id = : Id.valueOf(contactId) WITH SECURITY_ENFORCED LIMIT 1];
        } catch (Exception exceptionHandler) { 
            debugForCatchExceptions(exceptionHandler, 'getContactInfo');
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
        return contactsList;
    }
    //Description : Updates the Email Opt Out Field on Contact
    //Parameters :
    //    - contactId : Contact Id from the Contact Detail Page
    //    - isToggleChecked : The value from the "Opt out of all Email" Toggle Button
    @AuraEnabled
    public static void optOutOfEmailsContact(String contactId, Boolean isToggleChecked){
        try {
            if(String.isNotBlank(contactId)){
                Contact contactToUpdate = [SELECT Id, HasOptedOutOfEmail FROM Contact WHERE Id = :Id.valueOf(contactId) WITH SECURITY_ENFORCED];
                if(contactToUpdate != NULL){
                    contactToUpdate.HasOptedOutOfEmail = isToggleChecked;
                    Database.update(contactToUpdate, true);
                }
            } else {
                System.debug('NGO : optOutOfEmailsContact : Parameter : contactId is BLANK.');
            } 
        } catch (Exception exceptionHandler) {
            debugForCatchExceptions(exceptionHandler, 'optOutOfEmailsContact');
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
    }
    //- Description: Returns a JSON containing Contact's Communication Type's checkboxes with their Labels, API Names and Values
    //- Parameter : contactId :  Contact Id from Contact Record Page
    @AuraEnabled(cacheable=true)
    public static String generateCommunicationTypesJSON(String contactId){
        List<String> checkboxesDescribeList = new List<String>();
        List<CommunicationType> CommunicationTypesList = new List<CommunicationType>();
        
        Contact communicationTypesCheckboxes = [SELECT Id, Monthly_Newsletter__c, Events__c, Fund_Update__c, ESG_Newsletter__c, Regulatory_Newsletter__c
                                                FROM Contact
                                                WHERE Id = : Id.valueOf(contactId) WITH SECURITY_ENFORCED ];
        
        try {
            Map<String, Schema.SObjectField> contactFieldsMap = Schema.getGlobalDescribe().get('Contact').getDescribe().Fields.getMap();            
            if (contactFieldsMap != null){
                //Looping in the Schemas of Contact Object to obtain the Fields' information
                for (Schema.SObjectField eachObjectField : contactFieldsMap.values()){
                    //Storing the obtained fields' results
                    Schema.DescribeFieldResult fieldResult = eachObjectField.getDescribe(); 
                    //Handling only Custom Fields and Fields whose Help Text Field is not EMPTY. 
                    if(fieldResult.isCustom() && String.isNotBlank(fieldResult.getInlineHelpText()) && fieldResult.getInlineHelpText().containsIgnoreCase('Communication Type')){
                        //Concatenating the field's Label and API Name
                        checkboxesDescribeList.add(fieldResult.getName() + ';' + fieldResult.getLabel());  
                    }
                }
                //START : Building the Communication Type Wrapper Object
                for(String eachCheckbox : checkboxesDescribeList){
                    CommunicationType communicationType = new CommunicationType();
                    communicationType.checkboxAPI = eachCheckbox.removeStart(';');
                    communicationType.checkboxValue = Boolean.valueOf(communicationTypesCheckboxes.get(eachCheckbox.substringBefore(';')));
                    CommunicationTypesList.add(communicationType);
                }
                //END : Building the Communication Type Wrapper Object
            }
        } catch (Exception exceptionHandler) { 
            debugForCatchExceptions(exceptionHandler, 'generateCommunicationTypeJSON');
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
        return JSON.serialize(CommunicationTypesList);
    }
    //Description : Updates the Communication Types Checkboxes
    //Parameters :
    //    - contactId : Contact Id from the Contact Detail Page
    //    - commTypeCheckboxAPI : The Communication Type's Checkbox's API Name
    //    - isCommTypeSelected : The Communication Type's Toggle Button's Checked Status
    @AuraEnabled
    public static void updateContactCommunicationTypes(String contactId, String commTypeCheckboxAPI, Boolean isCommTypeSelected){
        try {
            if(String.isNotBlank(contactId) && String.isNotBlank(commTypeCheckboxAPI)){
                Contact contactToUpdate = [SELECT Id, Monthly_Newsletter__c, Events__c, Fund_Update__c, ESG_Newsletter__c, Regulatory_Newsletter__c
                                           FROM Contact 
                                           WHERE Id = : Id.valueOf(contactId) WITH SECURITY_ENFORCED];
                //Dynamically obtaining the checkbox and updating it
                contactToUpdate.put(commTypeCheckboxAPI, isCommTypeSelected);
                Database.update(contactToUpdate, true);
            } else {
                System.debug('NGO : updateContactCommunicationTypes : Parameters : contactId or commTypeCheckboxAPI may be BLANK.');
            }
        } catch (Exception exceptionHandler) {
            debugForCatchExceptions(exceptionHandler, 'updateContactCommunicationTypes');
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
    }
    //- Description: Returns a JSON containing Contact's Interest's checkboxes with their Labels, API Names and Values
    //- Parameter : contactId :  Contact Id from Contact Record Page
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> generateInterestsMAP(String contactId){
        List<String> checkboxesDescribeList = new List<String>();
        String checkboxLabel = '';
        Map<String, List<subInterest>> mainToSubInterestsMap = new Map<String, List<subInterest>>();
        Map<String, List<String>> mainToSubInterestsStrMap = new Map<String, List<String>>();
        
        Contact interestsMainFields = [SELECT Id, European_Equities__c, Fixed_Income_Strategy__c, Emerging_Equities__c, Thematic_Equities__c, 
                                       Diversified_Strategy__c, Patrimoine_Strategy__c, Alternative_Strategy__c, Market_Analysis__c, Sustainable_Investing__c, Corporate__c
                                       FROM Contact 
                                       WHERE Id = : Id.valueOf(contactId) WITH SECURITY_ENFORCED];
        
        try {
            Map<String, Schema.SObjectField> contactFieldsMap = Schema.getGlobalDescribe().get('Contact').getDescribe().Fields.getMap(); 
            if (contactFieldsMap != null){
                for (Schema.SObjectField eachObjectField : contactFieldsMap.values()){
                    Schema.DescribeFieldResult fieldResult = eachObjectField.getDescribe();
                    if(fieldResult.isCustom() && String.isNotBlank(fieldResult.getInlineHelpText())){
                        //Handling Interests' Checkboxes
                        if(fieldResult.getInlineHelpText().containsIgnoreCase('Interest')){
                            if(fieldResult.getInlineHelpText().containsIgnoreCase('main')){
                                //Populating the Maps with checkboxes whose help text contains 'main'
                                mainToSubInterestsMap.put(fieldResult.getLabel() + ';' + fieldResult.getName() + ';' + interestsMainFields.get(fieldResult.getName()), new List<SubInterest>());
                                mainToSubInterestsStrMap.put(fieldResult.getLabel() + ';' + fieldResult.getName() + ';' + interestsMainFields.get(fieldResult.getName()), new List<String>());
                            } else {  
                                //Handling the Checkboxes' labels that are too long for Salesforce Label Field
                                switch on fieldResult.getName() {
                                    when 'Carmignac_Long_Short_Eur_Equities_CLSEE__c' { 
                                        checkboxLabel = 'Carmignac Long Short European Equities (CLSEE/PLSEE)';
                                    }
                                    when 'Carmignac_Emerging_Patrimoine_CEMP_UKCEM__c' {
                                        checkboxLabel = 'Carmignac Emerging Patrimoine (CEMP/UKCEMP)';
                                    }
                                    when 'Carmignac_ProfReactif_CPR100_CPR75_CPR50__c' {
                                        checkboxLabel = 'Carmignac Profil Réactif (CPR 100/CPR 75/CPR 50)';
                                    }
                                    when else {
                                        checkboxLabel = fieldResult.getLabel();
                                    }
                                }
                                checkboxesDescribeList.add(fieldResult.getInlineHelpText().substringAfter(' ') + ';' + checkboxLabel + '#' + fieldResult.getName());
                            } 
                        }
                    }
                }
                //Getting the sub interests checkboxes
                Contact interestsFields = [SELECT Id, Carmignac_Grande_Europe_CGE__c, FP_Carmignac_European_Leaders_UKCEL__c, Carmignac_Global_Bond_CGB_UKCGB__c, Carmignac_S_curit_CSC_PSC__c, 
                                           Carmignac_Flexible_Bond_CFB__c, Carmignac_Credit_CCR__c, Carmignac_EM_Debt_CEMD__c, Carmignac_Credit_2025_CC25__c, Carmignac_Credit_2027_CC27__c,
                                           Carmignac_Emergents_CE_PE_UKCE__c, Carmignac_Emerging_Discovery_CED_UKCED__c, Carmignac_China_New_Economy_CCNE_PCNE__c, Carmignac_Investissement_CI_PI__c,
                                           Carmignac_Climate_Transition_CC__c, Carmignac_Family_Governed_CFG__c, Carmignac_Grandchildren_CGC_UKCGEC__c, Carmignac_Human_Xperience_CHX__c, 
                                           Carmignac_ProfReactif_CPR100_CPR75_CPR50__c, Carmignac_Patrimoine_CP_PP_UKCP__c, Carmignac_Patrimoine_Europe_CPE__c, Carmignac_Emerging_Patrimoine_CEMP_UKCEM__c,
                                           Carmignac_Long_Short_Eur_Equities_CLSEE__c, Carmignac_Investissement_Latitude_CIL__c
                                           FROM Contact
                                           WHERE Id = : Id.valueOf(contactId) WITH SECURITY_ENFORCED];
                //START : Building the Interest Wrapper Object
                for(String fieldLabel : checkboxesDescribeList){
                    for(/*mainInterest*/String eachInterest : mainToSubInterestsMap.keySet()){
                        //Checking for the matching Main Interest Labels to populate the appropriate sub interests list in the map
                        if(fieldLabel.substringBefore(';').containsIgnoreCase(eachInterest.substringBefore(';'))){
                            SubInterest subInterest = new SubInterest();
                            subInterest.SubCheckboxLabel = fieldLabel.substringBetween(';', '#');
                            subInterest.SubCheckboxAPI = fieldLabel.substringAfter('#');
                            subInterest.SubCheckboxValue = Boolean.valueOf(interestsFields.get(fieldLabel.substringAfter('#')));
                            mainToSubInterestsMap.get(eachInterest).add(subInterest);
                        }
                    }
                }
                
                for(String eachInterest : mainToSubInterestsMap.keySet()){
                    for(String eachKey : mainToSubInterestsStrMap.keySet()){
                        if(eachInterest == eachKey){
                            mainToSubInterestsStrMap.get(eachKey).add(JSON.serialize(mainToSubInterestsMap.get(eachInterest))); 
                        }
                    }
                }
                //END : Building the Interest Wrapper Object
            }
        } catch (Exception exceptionHandler) { 
            debugForCatchExceptions(exceptionHandler, 'generateInterestsMAP');
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
        return mainToSubInterestsStrMap; 
    }
    @AuraEnabled
    public static void updateInterests(String contactId, String mainInterest, String subInterest){
        try {
            if(String.isNotBlank(contactId) && String.isNotBlank(mainInterest) && String.isNotBlank(subInterest)){
                
                Contact interestsFields = [SELECT Id, European_Equities__c, Fixed_Income_Strategy__c, Emerging_Equities__c, Thematic_Equities__c, 
                                               Diversified_Strategy__c, Patrimoine_Strategy__c, Alternative_Strategy__c, Market_Analysis__c, Sustainable_Investing__c, Corporate__c,
                                               Carmignac_Grande_Europe_CGE__c, FP_Carmignac_European_Leaders_UKCEL__c, Carmignac_Global_Bond_CGB_UKCGB__c, Carmignac_S_curit_CSC_PSC__c, 
                                               Carmignac_Flexible_Bond_CFB__c, Carmignac_Credit_CCR__c, Carmignac_EM_Debt_CEMD__c, Carmignac_Credit_2025_CC25__c, Carmignac_Credit_2027_CC27__c,
                                               Carmignac_Emergents_CE_PE_UKCE__c, Carmignac_Emerging_Discovery_CED_UKCED__c, Carmignac_China_New_Economy_CCNE_PCNE__c, Carmignac_Investissement_CI_PI__c,
                                               Carmignac_Climate_Transition_CC__c, Carmignac_Family_Governed_CFG__c, Carmignac_Grandchildren_CGC_UKCGEC__c, Carmignac_Human_Xperience_CHX__c, 
                                               Carmignac_ProfReactif_CPR100_CPR75_CPR50__c, Carmignac_Patrimoine_CP_PP_UKCP__c, Carmignac_Patrimoine_Europe_CPE__c, Carmignac_Emerging_Patrimoine_CEMP_UKCEM__c,
                                               Carmignac_Long_Short_Eur_Equities_CLSEE__c, Carmignac_Investissement_Latitude_CIL__c
                                               FROM Contact 
                                               WHERE Id = : Id.valueOf(contactId) WITH SECURITY_ENFORCED];
                
                //START : Updating the Checkboxes
                List<InterestUnwrap> mainInterestUnwrappedList = (List<InterestUnwrap>)System.JSON.deserialize(mainInterest, List<InterestUnwrap>.class);
                List<InterestUnwrap> subInterestUnwrappedList = (List<InterestUnwrap>)System.JSON.deserialize(subInterest, List<InterestUnwrap>.class);
                System.debug('TEST : mainInterestUnwrappedList => ' + mainInterestUnwrappedList);
                //Main Interests
                for(InterestUnwrap eachInterest : mainInterestUnwrappedList){
                    interestsFields.put(eachInterest.checkboxAPI, eachInterest.checkboxValue);
                }
                
                //Sub Interests
                for(InterestUnwrap eachInterest : subInterestUnwrappedList){
                   interestsFields.put(eachInterest.checkboxAPI, eachInterest.checkboxValue); 
                }
                Database.update(interestsFields, true);
                //END : Updating the Checkboxes
            } else {
                System.debug('NGO : updateInterests : Parameters : contactId, mainInterest, subInterest may be BLANK.');
            }
        } catch (Exception exceptionHandler) {
            debugForCatchExceptions(exceptionHandler, 'updateInterests');
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
    }
    @AuraEnabled
    public static void updateMainInterestOnly(String contactId, String interestCheckboxAPI, Boolean isInterestSelected){
        try {
            if(String.isNotBlank(contactId) && String.isNotBlank(interestCheckboxAPI)){
                Contact contactToUpdate = [SELECT Id, Market_Analysis__c, Sustainable_Investing__c, Corporate__c
                                           FROM Contact 
                                           WHERE Id = : Id.valueOf(contactId) WITH SECURITY_ENFORCED];
                //Dynamically obtaining the checkbox and updating it
                contactToUpdate.put(interestCheckboxAPI, isInterestSelected);
                Database.update(contactToUpdate, true);
            } else {
                System.debug('NGO : updateContactCommunicationTypes : Parameters : contactId or interestCheckboxAPI may be BLANK.');
            }
        } catch (Exception exceptionHandler) {
            debugForCatchExceptions(exceptionHandler, 'updateMainInterestOnly');
            throw new AuraHandledException(exceptionHandler.getMessage());
        }
    }
    //END : Marketing Emails Section ------------------------------------------------------------------------------------------------------------------------------------
    //START : Utility Methods
    //FOR DEBUG PURPOSES
    //Description : This method prints out the error messages from the catch part of the try and catch statement in the above methods
    public static void debugForCatchExceptions(Exception exceptionHandlerParam, String methodName){
        System.debug(methodName + ' : Exception type caught: ' + exceptionHandlerParam.getTypeName());    
        System.debug(methodName + ' : Message: ' + exceptionHandlerParam.getMessage());    
        System.debug(methodName + ' : Line number: ' + exceptionHandlerParam.getLineNumber());    
        System.debug(methodName + ' : Stack trace: ' + exceptionHandlerParam.getStackTraceString());
    }
    //END : Utility Methods
}