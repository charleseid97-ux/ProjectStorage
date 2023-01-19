/*
* Created By : Noor Goolamnabee 
* Description : Test Class for the Controller of the Lightning Web Component lwc_preferencecenter
* Date : 2/08/2022
* APEX Class : PreferenceCenterController
* Coverage : 16%
*/
@isTest
private class PreferenceCenterControllerTest {
    //Data Setup
    @testSetup static void setup() {
        //START : Handling Try-Catch Exceptions
        //Querying the profile to assign to the user
        Profile profileToAssign = [SELECT Id FROM Profile WHERE Name='Minimum Access - Salesforce' LIMIT 1];
        //Creating User with Minimum Access to validate Catch Blocks
        User userTechTest = new User
            (
                alias = 'Test11'
                , email = 'TestCarmignacUser' + System.now().getTime() + '@carmignac.com'
                , emailencodingkey = 'ISO-8859-1'
                , Phone = '+3312345678'
                , firstname = 'CarmignacUser'
                , lastname = 'Test'
                , languagelocalekey = 'fr'
                , localesidkey = 'fr_FR_EURO'
                , ProfileId = profileToAssign.Id
                , timezonesidkey = 'Europe/Paris'
                , username = 'TestCarmignacUser' + System.now().getTime() + '-crm@carmignac.com'
                , TECH_UserEmail__c = 'TEST_UserEmail' + System.now().getTime()
                , Position__c = 'Business Developer'
                , IsActive = true
            );
        Database.insert(userTechTest, true);
        //END : Handling Try-Catch Exceptions
        //START : Data Creation through a Valid User
        User carmignacTestUser = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(carmignacTestUser) {
            
            Id_Tech_Sun_Legacy__c techSunLegacySetting = new Id_Tech_Sun_Legacy__c(
                Sun_ID__c = 250, 
                Name = 'Sun_ID'
            );
            
            TestFactory.createCustomSettings();
            //Funds
            Product__c newProduct = new Product__c();
            newProduct.RecordTypeId = Product__c.sObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
            newProduct.Name = 'Prod123';
            newProduct.Product_Name__c = 'Product Test';
            newProduct.Validity__c = true;
            Database.insert(newProduct, true);
            
            Share_Class__c newShareClass = new Share_Class__c();
            newShareClass.Name = 'Test SC';
            newShareClass.Fund__c = newProduct.Id;
            newShareClass.ISIN_Code__c = 'FR0011100000';
            newShareClass.Country__c = 'FR';
            newShareClass.Validity__c = true;
            Database.insert(newShareClass, true);
            
            Account newAccount = TestFactory.getSimpleAccount();
            Database.insert(newAccount, true);
            
            Contact newContact = TestFactory.getSimpleNoProfileContact(newAccount.Id, 'TestFName', 'LastNameTestCarmignac', '65432345', 'TechwbesiteId', 'mail@mail1.com', 'mail@mail1.com', 'mail@mail1.com');
            newContact.WebsiteRole__c = '5';
            newContact.TrialStatus__c = '5';
            newContact.FirstNameWebsite__c = 'testWebsiteFirstname';
            newContact.LastNameWebsite__c = 'testWebsitelastame';
            newContact.WebsiteCompany__c = 'testWebsitecompany';
            newContact.WebsiteSalutation__c = 'testWebsiteSalutation';
            newContact.WebsiteJobTitle__c = 'testWebsiteJob';
            newContact.WebsiteLogin__c = 'testWebsiteLogin@test.com';
            newContact.PostalCode__c = '25624';
            newContact.PhoneNumber__c = '0123456789';
            newContact.MobileNumber__c = '0123456787';
            newContact.Address1__c = 'TestAddress';
            newContact.City__c = 'TestCity';
            newContact.Country__c = 'FR';
            newContact.WebsiteCountry__c = 'FR';
            newContact.WebsiteLanguage__c = 'French';
            newContact.Prospace_Status__c = 'Validated';
            newContact.Synchrostatus__c = 'Success';
            newContact.TECH_WebSiteID__c = '123455';
            Database.insert(newContact, true);
            
            Lead newLead = TestFactory.getSimpleProSpaceLead();
            newLead.recordTypeId = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('Website Lead').getRecordTypeId();
            newLead.TECH_WebSiteID__c = '85236';
            newLead.Status = 'Pending Qualification';
            newLead.LeadSource = 'Website';
            newLead.Lead_Sub_Source__c = 'Web self-registration';
            newLead.Prospace_Status__c = 'Validated';
            newLead.WebsiteCountry__c = 'FR';
            Database.insert(newLead, true);
            
            //Alert Types
            AlertType__c alertTypeTheme = new AlertType__c();
            alertTypeTheme.name = 'daily_nav';
            alertTypeTheme.TECH_WebSiteID__c = '3';
            alertTypeTheme.site__c = 'FR.Italian;FR.French;FR.English';
            alertTypeTheme.isPublication__c = false;
            
            AlertType__c alertTypeTheme1 = new AlertType__c();
            alertTypeTheme1.name = 'Event';
            alertTypeTheme1.TECH_WebSiteID__c = '4';
            alertTypeTheme1.site__c = 'FR.Italian;FR.French;FR.English';
            alertTypeTheme1.isPublication__c = true;
            
            Database.insert(new List<AlertType__c>{alertTypeTheme, alertTypeTheme1}, true);
            
            //Prospace Alerts
            Web_Communication__c webComm = new Web_Communication__c();
            webComm.TECH_ISINCode__c = 'FR0011100000';
            webComm.AlertTypeRecord__c = alertTypeTheme.Id;
            webComm.Contact__c = newContact.Id;
            webComm.TECH_CommunicationWebsiteId__c = '1111';
            webComm.ShareClass__c = newShareClass.Id;
            webComm.Fund__c = newProduct.Id;
            
            Web_Communication__c webComm1 = new Web_Communication__c();
            webComm1.TECH_ISINCode__c = 'FR0011100011';
            webComm1.AlertTypeRecord__c = alertTypeTheme.Id;
            webComm1.Lead__c = newLead.Id;
            webComm1.ShareClass__c = newShareClass.Id;
            webComm1.Fund__c = newProduct.Id;
            webComm1.TECH_CommunicationWebsiteId__c = '22222';
            
            Database.insert(new List<Web_Communication__c>{webComm, webComm1}, true);
            
        }
        //NED : Data Creation through a Valid User
    }
    
    //Description : Validates the TRY outcome of the getAlertTypesWithProspaceAlert method of the controller
    static testMethod void validategetAlertTypesWithProspaceAlert() {
        String contactId = getContactId();
        PreferenceCenterController.getAlertTypesWithProspaceAlert(contactId); 
    }
    
    //Description : Validates the TRY outcome of the createProspaceAlerts for Nav and Reports and Publication Section
    static testMethod void validatecreateProspaceAlerts(){
        String contactId = getContactId();
        String alertTypeId = getAlertTypeId(false);
        String fundId = getFundId();
        String shareClassId =  getShareClassId();
        String alertTypePubId = getAlertTypeId(true);
        PreferenceCenterController.createProspaceAlerts(contactId, alertTypeId, fundId, shareClassId, false);
        PreferenceCenterController.createProspaceAlerts(contactId, alertTypePubId, '', '', true);
    }
    
    static testMethod void validatedeleteProspaceAlerts(){
        Web_Communication__c webCommQuery = [SELECT Id, Contact__c, AlertTypeRecord__c, Fund__c, ShareClass__c 
                                             FROM Web_Communication__c 
                                             WHERE TECH_ISINCode__c = 'FR0011100011'];
        //Nav and Reports
        PreferenceCenterController.deleteProspaceAlerts(webCommQuery.Id, webCommQuery.AlertTypeRecord__c, false);
        //Publication
        PreferenceCenterController.deleteProspaceAlerts(webCommQuery.Id, webCommQuery.AlertTypeRecord__c, true);
    }
    
    static testMethod void validatecreateAllProspaceAlerts(){
        String contactId = getContactId();
        String alertTypeId = getAlertTypeId(false);
        String leadId = getLeadId();
        PreferenceCenterController.createAllProspaceAlerts(contactId, new List<String>{alertTypeId});
        PreferenceCenterController.createAllProspaceAlerts(leadId, new List<String>{alertTypeId});
    }
    
    static testMethod void validatedeleteAllProspaceAlerts(){
        String contactId = getContactId();
        String alertTypeId = getAlertTypeId(false);
        String leadId = getLeadId();
        PreferenceCenterController.deleteAllProspaceAlerts(contactId, new List<String>{alertTypeId});
        PreferenceCenterController.deleteAllProspaceAlerts(leadId, new List<String>{alertTypeId});
    }
    
    
    
    //Description : Validates the CATCH outcome of the getAlertTypesWithProspaceAlert method of the controller
    static testMethod void validateCatchExceptions() {
        user testUserForCatchExcept = [SELECT Id FROM User WHERE Alias = 'Test11'];
        test.startTest();
        System.runAs(testUserForCatchExcept) {
            try{
                validategetAlertTypesWithProspaceAlert();
            } catch (Exception exceptionHandler) {
                //Validating the Exceptions thrown by the controller methods
                System.assertEquals('Script-thrown exception', exceptionHandler.getMessage()); 
            }
        }
        test.stopTest();
    }
    
    static testMethod void validatecreateProspaceAlertsCatchException() {
        user testUserForCatchExcept = [SELECT Id FROM User WHERE Alias = 'Test11'];
        test.startTest();
        System.runAs(testUserForCatchExcept) {
            try{
                 validatecreateProspaceAlerts();
            } catch (Exception exceptionHandler) {
                System.assertEquals('Script-thrown exception', exceptionHandler.getMessage()); 
            }
        }
        test.stopTest(); 
    }
    
    static testMethod void validatedeleteProspaceAlertsCatchException() {
        user testUserForCatchExcept = [SELECT Id FROM User WHERE Alias = 'Test11'];
        test.startTest();
        System.runAs(testUserForCatchExcept) {
            try{
                validatedeleteProspaceAlerts();   
            } catch (Exception exceptionHandler) {
                System.assertEquals('Script-thrown exception', exceptionHandler.getMessage()); 
            }
        }
        test.stopTest();
    }
    
    static testMethod void validatecreateAllProspaceAlertsCatch() {
        user testUserForCatchExcept = [SELECT Id FROM User WHERE Alias = 'Test11'];
        test.startTest();
        System.runAs(testUserForCatchExcept) {
            try{
                validatecreateAllProspaceAlerts();
            } catch (Exception exceptionHandler) {
                System.assertEquals('Script-thrown exception', exceptionHandler.getMessage()); 
            }
        }
        test.stopTest(); 
    }
    
    static testMethod void validatedeleteAllProspaceAlertsCatch() {
        user testUserForCatchExcept = [SELECT Id FROM User WHERE Alias = 'Test11'];
        test.startTest();
        System.runAs(testUserForCatchExcept) {
            try{
                validatedeleteAllProspaceAlerts();
            } catch (Exception exceptionHandler) {
                System.assertEquals('Script-thrown exception', exceptionHandler.getMessage()); 
            }
        }
        test.stopTest(); 
    }
    
    static testMethod void validategetProspaceAlertsCatch() {
        user testUserForCatchExcept = [SELECT Id FROM User WHERE Alias = 'Test11'];
        test.startTest();
        System.runAs(testUserForCatchExcept) {
            try{
                PreferenceCenterController.getProspaceAlerts('12322');
            } catch (Exception exceptionHandler) {
                System.assertEquals('Script-thrown exception', exceptionHandler.getMessage()); 
            }
        }
        test.stopTest(); 
    }
	
//START : MARKETING EMAIL Section
    static testMethod void validategetContactInfo(){
        String contactId = getContactId();
        PreferenceCenterController.getContactInfo(contactId);
    }
    
    static testMethod void validategetContactInfoCatch() {
        user testUserForCatchExcept = [SELECT Id FROM User WHERE Alias = 'Test11'];
        test.startTest();
        System.runAs(testUserForCatchExcept) {
            try{
                validategetContactInfo();
            } catch (Exception exceptionHandler) {
                System.assertEquals('Script-thrown exception', exceptionHandler.getMessage()); 
            }
        }
        test.stopTest(); 
    }
    
    static testMethod void validateoptOutOfEmailsContact(){
        String contactId = getContactId();
        PreferenceCenterController.optOutOfEmailsContact(contactId, true);
    }
    
    static testMethod void validateoptOutOfEmailsContactCatch() {
        user testUserForCatchExcept = [SELECT Id FROM User WHERE Alias = 'Test11'];
        test.startTest();
        System.runAs(testUserForCatchExcept) {
            try{
                validateoptOutOfEmailsContact();
            } catch (Exception exceptionHandler) {
                System.assertEquals('Script-thrown exception', exceptionHandler.getMessage()); 
            }
        }
        test.stopTest(); 
    }
    
    static testMethod void validategenerateCommunicationTypesJSON(){
        String contactId = getContactId();
        PreferenceCenterController.generateCommunicationTypesJSON(contactId);
    }
    
    static testMethod void valgenerateCommunicationTypesJSONCatch() {
        user testUserForCatchExcept = [SELECT Id FROM User WHERE Alias = 'Test11'];
        test.startTest();
        System.runAs(testUserForCatchExcept) {
            try{
                validategenerateCommunicationTypesJSON();
            } catch (Exception exceptionHandler) {
                System.assertEquals('Insufficient permissions: secure query included inaccessible field', exceptionHandler.getMessage()); 
            }
        }
        test.stopTest(); 
    }

    static testMethod void validateUpdateContactCommunicationTypes(){
        String contactId = getContactId();
        PreferenceCenterController.updateContactCommunicationTypes(contactId, 'Events__c', true);
    }
    
    static testMethod void validategenerateInterestsMAP(){
        String contactId = getContactId();
        PreferenceCenterController.generateInterestsMAP(contactId);
    }
    static testMethod void validateupdateInterests(){
        //updateInterests
        String contactId = getContactId();
        String mainInterest = '[{"checkboxAPI" : "European_Equities__c", "checkboxValue" : true}]';
        String subInterest = '[{"checkboxAPI" : "Carmignac_Grande_Europe_CGE__c", "checkboxValue" : true}]';
        PreferenceCenterController.updateInterests(contactId,mainInterest,subInterest);
    }
    
    static testMethod void validateupdateMainInterestOnly(){
        String contactId = getContactId();
        PreferenceCenterController.updateMainInterestOnly(contactId, 'Market_Analysis__c', true);
    }
//END : MARKETING EMAIL Section    
    
    //START : Utility Methods
    static String getContactId(){
        return [SELECT Id FROM Contact WHERE LastName = 'LastNameTestCarmignac'][0].Id;
    }
    static String getAlertTypeId(Boolean isPublished){
        return [SELECT Id FROM AlertType__c WHERE isPublication__c = :isPublished][0].Id;
    }
    static String getFundId(){
        return [SELECT Id FROM Product__c WHERE Name = 'Prod123'][0].Id;
    }
    static String getShareClassId(){
        return [SELECT Id FROM Share_Class__c WHERE Name = 'Test SC'][0].Id;
    }
    static String getLeadId(){
        return [SELECT Id FROM Lead WHERE TECH_WebSiteID__c = '85236'][0].Id;
    }
    //END : Utility Methods
    
}