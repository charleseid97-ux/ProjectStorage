/**
 * Created by noorgoolamnabee on 23/08/2022.
 */
@isTest
public with sharing class LookUpFilterCriteriaController_TEST {

    //Data SetUp
    @testSetup static void setup(){

        // Test User creation
        User u = TestFactory.getCarmignacUserTestApex();
        System.runAs(u) {

            Id_Tech_Sun_Legacy__c setting = new Id_Tech_Sun_Legacy__c (
                    Sun_ID__c = 250
                    , Name = 'Sun_ID'

            );

            TestFactory.createCustomSettings();
            Product__c prd = new Product__c();
            prd.RecordTypeId = Product__c.sObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
            prd.Name = 'Prod123';
            prd.Product_Name__c = 'Product Test';
            prd.Validity__c = true;
            Database.insert(prd, true);

            Share_Class__c sC = new Share_Class__c();
            sC.Name = 'Test SC';
            sC.Fund__c = prd.Id;
            sC.ISIN_Code__c = 'FR0011100000';
            sc.Country__c = 'FR';
            sc.Validity__c = true;

            Database.insert(sC, true);

            Account accountTest = TestFactory.getSimpleAccount();
            insert accountTest;


            Contact testContact2 = TestFactory.getSimpleNoProfileContact(accountTest.Id, 'TestFName', 'LastNameTestCarmignac', '65432345', 'TechwbesiteId', 'mail@mail1.com', 'mail@mail1.com', 'mail@mail1.com');
            testContact2.WebsiteRole__c = '5';
            testContact2.TrialStatus__c = '5';
            testContact2.FirstNameWebsite__c = 'testWebsiteFirstname';
            testContact2.LastNameWebsite__c = 'testWebsitelastame';
            testContact2.WebsiteCompany__c = 'testWebsitecompany';
            testContact2.WebsiteSalutation__c = 'testWebsiteSalutation';
            testContact2.WebsiteJobTitle__c = 'testWebsiteJob';
            testContact2.WebsiteLogin__c = 'testWebsiteLogin@test.com';
            testContact2.PostalCode__c = '25624';
            testContact2.PhoneNumber__c = '0123456789';
            testContact2.MobileNumber__c = '0123456787';
            testContact2.Address1__c = 'TestAddress';
            testContact2.City__c = 'TestCity';
            testContact2.Country__c = 'FR';
            testContact2.WebsiteCountry__c = 'FR';
            testContact2.WebsiteLanguage__c = 'French';
            testContact2.Prospace_Status__c = 'Validated';
            testContact2.Synchrostatus__c = 'Success';
            testContact2.TECH_WebSiteID__c = '123455';

            Database.insert(testContact2, true);

            //Insert lead
            Id RecordTypeIdLead = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('Website Lead').getRecordTypeId();

            Lead ld2 = TestFactory.getSimpleProSpaceLead();
            ld2.recordTypeId = RecordTypeIdLead;
            ld2.TECH_WebSiteID__c = '85236';
            ld2.Status = 'Pending Qualification';
            ld2.LeadSource = 'Website';
            ld2.Lead_Sub_Source__c = 'Web self-registration';
            ld2.Prospace_Status__c = 'Validated';
            ld2.WebsiteCountry__c = 'FR';

            Database.insert(ld2, true);

            AlertType__c theme1 = new AlertType__c();
            theme1.name = 'daily_nav';
            theme1.TECH_WebSiteID__c = '3';
            theme1.site__c = 'FR.Italian;FR.French;FR.English';
            theme1.isPublication__c = false;

            AlertType__c theme2 = new AlertType__c();
            theme2.name = 'Event';
            theme2.TECH_WebSiteID__c = '4';
            theme2.site__c = 'FR.Italian;FR.French;FR.English';
            theme2.isPublication__c = true;

            Database.insert(new List<AlertType__c>{theme1, theme2}, true);

            List<Web_Communication__c> WebCommList = new List<Web_Communication__c>();
            Web_Communication__c web = new Web_Communication__c();
            web.TECH_ISINCode__c = 'FR0011100000';
            web.AlertTypeRecord__c = theme1.Id;
            web.Contact__c = testContact2.Id;
            web.TECH_CommunicationWebsiteId__c = '1111';
            web.ShareClass__c = sC.Id;
            web.Fund__c = prd.Id;
            WebCommList.add(web);

            Web_Communication__c web2 = new Web_Communication__c();
            web2.TECH_ISINCode__c = 'FR0011100011';
            web2.AlertTypeRecord__c = theme1.Id;
            web2.Lead__c = ld2.Id;
            web2.ShareClass__c = sC.Id;
            web2.Fund__c = prd.Id;
            web2.TECH_CommunicationWebsiteId__c = '22222';
            WebCommList.add(web2);

            Database.insert(WebCommList, true);

        }
    }

    static testMethod void testPreferenceCenterController() {

        //String lookupObjectAPI, String lookupSearchKey, String additionalField, String dependentFieldQuery, String dependentField
        Contact c = [SELECT Id FROM Contact];

        Product__c fund = [SELECT Id FROM Product__c WHERE Name = 'Prod123' LIMIT 1];

        LookUpFilterCriteriaController.getLookUpFieldValues('Share_Class__c','Test', '','Fund__c',fund.Id, c.Id);
        //String referencedObjectAPI, String fieldAPI, String lookUpOriginObjectAPI
        LookUpFilterCriteriaController.getFieldAndObjectPluralLabels('Share_Class__c', 'Fund__c', 'Fund__c');
    }

}