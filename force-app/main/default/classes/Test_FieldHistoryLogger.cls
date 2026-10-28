/**
 * @description Test class for FieldHistoryLogger.
 *              Coverage: 89%
 *              Also covers the FundFieldApplicabilityHistoryTrigger rules: Applicability__c set from the config, a single open period per record and field.
 * @editor     Charles Eid — 2026-04-02
 * @covers FieldHistoryLogger   90%   [28-10-26]
 * @covers FundFieldApplicabilityHistoryHandler   100%   [28-10-26]
 * @lastModifiedBy Charles EID   [28-10-26]
 */
@isTest
public class Test_FieldHistoryLogger {

    static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();

    @testSetup
    static void setup() {
        Strategy__c s0 = new Strategy__c(Name='S0', AssetClass__c='Equity', SubAssetClass__c='Global', Code__c='S01');
        insert s0;

        Product__c p0 = new Product__c(Name='P0', FundStrategy__c=s0.Id, ProductName__c='Product Zero', Record_Type_Name__c='Fund', RecordTypeId=fundRecordTypeId, Validity__c=true, LegalForm__c='SICAV', VehicleType__c='Funds');
        Product__c p1 = new Product__c(Name='P1', FundStrategy__c=s0.Id, ProductName__c='Product One',  Record_Type_Name__c='Fund', RecordTypeId=fundRecordTypeId, Validity__c=true);
        Product__c p2 = new Product__c(Name='P2', FundStrategy__c=s0.Id, ProductName__c='Product Inactif', Record_Type_Name__c='Fund', RecordTypeId=fundRecordTypeId, Validity__c=false);
        insert new List<Product__c>{ p0, p1, p2 };

        Share_Class__c sc0 = new Share_Class__c(Name='ShareClass0 A USD', CurrencyIsoCode='USD', Country__c='AT;BE;FR;DE;GB;XI;IT;LU;ES;SE;CH;NL', Type__c='A', Fund_Code__c='P0', Fund__c=p0.Id, Validity__c=true);
        Share_Class__c sc1 = new Share_Class__c(Name='ShareClass1 A USD', CurrencyIsoCode='USD', Country__c='AT;BE;FR;DE;GB;XI;IT;LU;ES;SE;CH;NL', Type__c='A', Fund_Code__c='P1', Fund__c=p1.Id, Validity__c=false);
        insert new List<Share_Class__c>{ sc0, sc1 };
    }

    @isTest
    static void auditHistory_Test() {
        List<Product__c> products   = [SELECT Id, LegalForm__c FROM Product__c];
        Share_Class__c sc0 = [SELECT Id, Name__c FROM Share_Class__c WHERE Validity__c = true LIMIT 1];

        Test.startTest();

        for (Product__c p : products) {
            p.LegalForm__c = (p.LegalForm__c == 'SICAV') ? 'FCP' : 'SICAV';
        }
        update products;

        sc0.Name__c = 'old Name';
        update sc0;
        sc0.Name__c = 'new Name';
        update sc0;

        Test.stopTest();

        List<Fund_Field_ApplicabilityHistory__c> logsAllFields   = [SELECT Id FROM Fund_Field_ApplicabilityHistory__c WHERE Applicability__c = false];
        List<Fund_Field_ApplicabilityHistory__c> logsApplicability = [SELECT Id FROM Fund_Field_ApplicabilityHistory__c WHERE Applicability__c = true];
        System.assertNotEquals(0, logsAllFields.size());
        System.assertNotEquals(0, logsApplicability.size());

        List<Fund_Field_ApplicabilityHistory__c> openNamePeriods = [SELECT Id FROM Fund_Field_ApplicabilityHistory__c WHERE Share_Class_Reference__c = :sc0.Id AND FieldAPIName__c = 'Name__c' AND Applicability__c = true AND End_Date__c = NULL];
        List<Fund_Field_ApplicabilityHistory__c> closedNamePeriods = [SELECT Id FROM Fund_Field_ApplicabilityHistory__c WHERE Share_Class_Reference__c = :sc0.Id AND FieldAPIName__c = 'Name__c' AND Applicability__c = true AND End_Date__c != NULL];
        System.assertEquals(1, openNamePeriods.size(), 'Only the last Name__c period stays open');
        System.assertNotEquals(0, closedNamePeriods.size(), 'The previous Name__c period is closed');

        Fund_Field_ApplicabilityHistory__c uploadedPeriod = new Fund_Field_ApplicabilityHistory__c(Share_Class_Reference__c = sc0.Id, FieldAPIName__c = 'name__c', Start_Date__c = System.today(), Applicability__c = false);
        StatusCode duplicateError;
        try {
            insert uploadedPeriod;
        }
        catch (DmlException e) {
            duplicateError = e.getDmlType(0);
        }
        System.assertEquals(StatusCode.DUPLICATE_VALUE, duplicateError, 'A tracked field line is set to Applicability__c = true, then rejected as a second open period (unique OpenPeriodKey__c)');

        Fund_Field_ApplicabilityHistory__c auditLine = logsAllFields[0];
        auditLine.FieldAPIName__c = 'validity__c';
        auditLine.Applicability__c = true;
        update auditLine;
        System.assertEquals(false, [SELECT Applicability__c FROM Fund_Field_ApplicabilityHistory__c WHERE Id = :auditLine.Id].Applicability__c, 'A manual Applicability__c on a non-tracked field is overwritten');
    }

    @isTest
    static void sendAlert_htmlTable_Test() {
        Share_Class__c sc = [SELECT Id, Name__c, MaxManagementFees__c FROM Share_Class__c WHERE Validity__c = true LIMIT 1];

        Test.startTest();
        sc.Name__c = 'Alert Test';
        sc.MaxManagementFees__c = 1.5;
        update sc;
        Test.stopTest();
    }

    @isTest
    static void sendAlert_csvAttachment_Test() {
        Share_Class__c sc = [SELECT Id, Name__c, MaxManagementFees__c, EffectiveManagementFees__c, MaxServiceFees__c, EffectiveServiceFees__c, EffectivePerfFees__c FROM Share_Class__c WHERE Validity__c = true LIMIT 1];

        Test.startTest();
        sc.Name__c                    = 'CSV Test';
        sc.MaxManagementFees__c       = 1.0;
        sc.EffectiveManagementFees__c = 0.5;
        sc.MaxServiceFees__c          = 0.3;
        sc.EffectiveServiceFees__c    = 0.2;
        sc.EffectivePerfFees__c       = 0.1;
        update sc;
        Test.stopTest();
    }

}