/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 10-11-2024
 * @last modified by  : SILA Nicolas
**/
@isTest
public class ContentDocumentLinkTriggerTest {

    private static final Id translationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Translation Request').getRecordTypeId();

    @TestSetup 
    static void testSetup() {
        // Create a Case record
        Case wtp = new Case(Subject = 'Parent Case', RecordTypeId = translationRecordTypeId, Website_Type__c = 'Article', Website_SubType__c='Events', target_languages__c='Spanish;French',Translation_Request_Type__c = 'Publication and Translation',
        Document_Type__c = 'Biography', Sub_Target_language__c='Parent Case', TargetWebsite__c = 'Spain (ES);International (ES)', Source_Language__c = 'French',Translation_mode__c='Full humain'
        );
        insert wtp;
        // Create a Contact record
        Contact c = new Contact(LastName='LAST',
                               FirstName='First',
                               email='first.last@invalid.com',
                               Agency_Translation_language__c='Spanish',
                               Source__c='Business Card');
        insert c;
        // ++++++++++++
        
        Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);
        Map<String, Id> accRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Account.SObjectType);

        List<Account> accList = new List<Account>{
                new Account(Name = 'Account FR Test', BusinessDevelopmentRegion__c = 'BP_FR'
                        , Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor')
                        , Billingcity = 'Chicago', BillingStreet = 'asd123', BillingPostalCode = '60606'
                        , BillingCountry = 'United States', In__c = 'Retail', Final_Distribution__c = 'Retail')
                , new Account(Name = 'Account ES Test', BusinessDevelopmentRegion__c = 'BP_ES'
                        , Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor')
                        , Billingcity = 'Barcelona', BillingStreet = 'xyz456', BillingPostalCode = '70301'
                        , BillingCountry = 'Spain', In__c = 'Retail', Final_Distribution__c = 'Retail')
                , new Account(Name = 'Account Fail Test', BusinessDevelopmentRegion__c = 'BP_LU', BillingCountry = 'Luxembourg')
        };
        insert accList;

        Grid__c franceGrid = new Grid__c(Name = 'France S5', ActiveGrid__c = true);
        insert franceGrid;

        Convention__c masterAgreement = new Convention__c(Name = 'tmpName', Grid__c = franceGrid.Id, Company__c = accList[0].Id,
                Countries_of_Distribution__c = 'AL', Code_Type__c = 'Distribution Agreement',
        
        RecordTypeId = agmRtMap.get('Request_Agreement'), OwnerId = UserInfo.getUserId());
        insert masterAgreement;
        
        Legal_Entity__c le = new Legal_Entity__c(
                Name = 'Test',
                LEI__c = '5067007V6269EHSP3295',
                TECH_brid__c = '5063007V6269EHOP329522'
        );

        insert le;

        KYD_Due_Diligence_Oversight__c kydDD = new KYD_Due_Diligence_Oversight__c(
                Name = 'Test',
                Active__c = true,
                LegalEntity__c = le.Id,
                Agreement__c = masterAgreement.Id
        );

        insert kydDD;

        KYC_Document_Configuration__c config = new KYC_Document_Configuration__c();
        config.RiskLevel__c = 'low';
        config.EntityType__c = 'Regulated & Listed Entities';
        config.KYD_Responsible__c = 'CGL';
        config.CollectiveFunds_personality__c = 'No';
        insert config;

        kydDD.Final_Risk__c = 'low';
        kydDD.EntityType__c = 'Regulated & Listed Entities';
        kydDD.KYD_Responsible__c = 'CGL';
        kydDD.CollectiveFunds_personality__c = 'No';
        update kydDD;
    }

    @isTest static void testFunction() {
        Map<Id, ContentDocumentLink> newMap = new Map<Id, ContentDocumentLink>();
        ContentDocumentLinkTriggerHandler cdth = new ContentDocumentLinkTriggerHandler();
        cdth.BeforeDelete(newMap);
        cdth.BeforeInsert(new List<ContentDocumentLink>());
        cdth.BeforeUpdate(newMap, newMap);
        cdth.AfterUpdate(newMap,newMap);
        cdth.AfterDelete(newMap);
        cdth.AfterUndelete(newMap);
        cdth.IsDisabled();
    }

    @isTest
    static void afterInsert_Test() {
        Case parentCase = [SELECT Id FROM Case LIMIT 1];
        Case subTrans = [SELECT Id FROM Case WHERE ParentId = :parentCase.Id LIMIT 1];
        Test.startTest();
        ContentVersion content=new ContentVersion(); 

        content.Title='Header_Picture1'; 

        content.PathOnClient='/' + content.Title + '.jpg'; 

        Blob bodyBlob=Blob.valueOf('Unit Test ContentVersion Body'); 

        content.VersionData=bodyBlob; 

        //content.LinkedEntityId=sub.id;

        content.origin = 'H';

        insert content;

        ContentDocumentLink contentlink=new ContentDocumentLink();

        contentlink.LinkedEntityId=parentCase.id;
        system.debug('contentlink.LinkedEntityId :'+contentlink.LinkedEntityId);
        contentlink.contentdocumentid=[select contentdocumentid from contentversion where id =: content.id].contentdocumentid;

        contentlink.ShareType = 'I';

        contentlink.Visibility = 'AllUsers'; 

        insert contentlink;

        Test.stopTest();
    }
    
    @isTest
    static void afterInsertkyd_Test() {
        KYD_Document__c parentkYD = [SELECT Id FROM KYD_Document__c LIMIT 1];
        Test.startTest();
        ContentVersion content = new ContentVersion(); 

        content.Title='Header_Picture1'; 

        content.PathOnClient='/' + content.Title + '.jpg'; 

        Blob bodyBlob=Blob.valueOf('Unit Test ContentVersion Body'); 

        content.VersionData=bodyBlob; 

        content.origin = 'H';

        insert content;

        ContentDocumentLink contentlink=new ContentDocumentLink();

        contentlink.LinkedEntityId=parentkYD.id;
        system.debug('contentlink.LinkedEntityId :'+contentlink.LinkedEntityId);
        contentlink.contentdocumentid=[select contentdocumentid from contentversion where id =: content.id].contentdocumentid;

        contentlink.ShareType = 'I';

        contentlink.Visibility = 'AllUsers'; 

        insert contentlink;

        Test.stopTest();
    }
}