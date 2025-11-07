/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 19-06-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
@isTest
public class CaseTriggerTest {

    private static final Id translationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Translation Request').getRecordTypeId();
    private static final Id subTranslationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Sub Translation Request').getRecordTypeId();
    private static final Id subPublicationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Sub Publication Request').getRecordTypeId();

    @TestSetup
    static void testSetup() {
        // Create a Case record
        Case wtp = new Case(Subject = 'Parent Case', RecordTypeId = translationRecordTypeId, Website_Type__c = 'Article', Website_SubType__c='Events', target_languages__c='Spanish',Translation_Request_Type__c = 'Publication and Translation',
        Document_Type__c = 'Biography', Sub_Target_language__c='Parent Case', TargetWebsite__c = 'Spain (ES);International (ES)', Source_Language__c = 'French'
        );
        insert wtp;
    }

    @isTest static void testFunction() {
        Map<Id, Case> newMap = new Map<Id, Case>();
        CaseTriggerHandler cth = new CaseTriggerHandler();
        cth.BeforeDelete(newMap);
        cth.BeforeInsert(new List<Case>());
        cth.BeforeUpdate(newMap, newMap);
        cth.AfterDelete(newMap);
        cth.AfterUndelete(newMap);
        cth.IsDisabled();
    }
    
    @isTest static void testCaseWithNDA() {
        NDA__c nda = new NDA__c();
        nda.Active__c = True;
        nda.Name = 'New NDA Test';
        nda.Status__c = 'Pending signature';
        insert nda;
        
        Account acc = new Account();
        acc.Name = 'New Account Test';
        acc.BusinessDevelopmentRegion__c = 'BP_FR';
        acc.BillingCountry = 'France';
        acc.LegalForm__c = 'Individual Person';
        insert acc;
        
        Case c = new Case();
        c.AccountId = acc.id;
        c.Type = 'Data Solution';
        c.Status = 'New';
        c.Origin = 'Email';
        c.Due_date__c = date.today().addDays(22);
        c.NDA__c = nda.id;
        insert c;
        
        //Add Share Class
        //Add case Product
        
        NDA__c secondNDA = new NDA__c();
        nda.Active__c = True;
        nda.Name = 'Second NDA';
        nda.Status__c = 'Pending signature';
        insert secondNDA;
        
        c.NDA__c = secondNDA.id;
        update c;
        
        delete c;
        
        //check company name on both nda
        //check nda product on both nda
    }

    @isTest static void switchTranslationToPublication_Test() {
        Case parentCase = [SELECT Id FROM Case WHERE Subject = 'Parent Case' LIMIT 1];
        Case subTrans = [SELECT Id FROM Case WHERE ParentId = :parentCase.Id LIMIT 1];
        subTrans.Status ='Closed'; 
        Test.startTest();
        update subTrans;
        Test.stopTest();
        Case subPub = [SELECT Id,RecordTypeId FROM Case WHERE ParentId = :parentCase.Id LIMIT 1];
        system.assertEquals(subPublicationRecordTypeId, subPub.RecordTypeId);
    }

    @isTest static void createChildCasesPubOnly_Test() {
        // Create a Case record
        Case wtp = new Case(Subject = 'Parent Case', RecordTypeId = translationRecordTypeId, Website_Type__c = 'Article', Website_SubType__c='Events', target_languages__c='Spanish',Translation_Request_Type__c = 'Publication Only',
         Sub_Target_language__c='Parent Case', TargetWebsite__c = 'Spain (ES);International (ES)'
        );
        
        Test.startTest();
        insert wtp;
        Test.stopTest();
        List<Case> subPub = [SELECT Id FROM Case WHERE ParentId = :wtp.Id];
        System.assertNotEquals(0, subPub.size());
    }

    @isTest static void createChildCasesTransOnly_Test() {
        // Create a Case record
        Case wtp = new Case(Subject = 'Parent Case', RecordTypeId = translationRecordTypeId, target_languages__c='English',Translation_Request_Type__c = 'Translation Only',
        Document_Type__c = 'Biography', Sub_Target_language__c='Parent Case', TargetWebsite__c = 'France (EN)', Source_Language__c = 'English'
        );
        
        Test.startTest();
        insert wtp;
        Test.stopTest();
        List<Case> subTrans = [SELECT Id FROM Case WHERE ParentId = :wtp.Id ];
        System.assertNotEquals(0, subTrans.size());
    }
}