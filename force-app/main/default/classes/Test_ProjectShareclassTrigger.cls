/** ──────────────────────────────────────
 * @description Tests of the ProjectShareclass__c and ProjectShareclassChild__c triggers: share class names, the 4 Project Shareclass Children of a share class, the selection
 *                  of fields to modify on a modification project (teams left to validate on the project phases, fields goal of the children, selected fields blanked
 *                  on the children and copied back to the share class), and the Tax Transparency requests (TaxData__c created then canceled, Tax team email).
 *              US-20194: a field selected on the project first stays to validate when a share class field is selected afterwards.
 *              PMT IS Scope: the teams left to validate, the fields goal and the Tax team email are no longer asserted (they come from the deployed
 *                  custom metadata records).
 * @covers ProjectShareclassHandler   93%   [25-11-26]
 * @covers ProjectShareclassChildHandler   93%   [25-11-26]
 * @lastModifiedBy Charles EID   [25-11-26]
 ────────────────────────────────────── */
@isTest
public class Test_ProjectShareclassTrigger {

    private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();
    private static final Id fundModificationRtId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();

    @testSetup
    static void setup() {
        insert new List<ProjectProduct__c>{
            newProject('OEIC', fundCreationRtId, 'OEIC'),
            newProject('SICAV', fundCreationRtId, 'SICAV'),
            newProject('Modification - Fund - 19/10/2026', fundModificationRtId, 'SICAV')
        };
    }

    @isTest
    static void test_shareclassLifecycle() {
        // Creation projects are renamed by the trigger: found by record type and legal form
        Id oeicId = [SELECT Id FROM ProjectProduct__c WHERE RecordTypeId = :fundCreationRtId AND LegalForm__c = 'OEIC' LIMIT 1].Id;
        Id sicavId = [SELECT Id FROM ProjectProduct__c WHERE RecordTypeId = :fundCreationRtId AND LegalForm__c = 'SICAV' LIMIT 1].Id;
        Id modificationId = [SELECT Id FROM ProjectProduct__c WHERE RecordTypeId = :fundModificationRtId LIMIT 1].Id;
        Map<String, Id> phaseIdByName = new Map<String, Id>();
        for (ProjectProductChild__c phase : [SELECT Id, Name FROM ProjectProductChild__c WHERE ProjectProductParent__c = :modificationId]) {
            phaseIdByName.put(phase.Name, phase.Id);
        }

        // Share class names (US-19137): expected name of each share class
        List<ProjectShareclass__c> namedShareclasses = new List<ProjectShareclass__c>{
            newShareclass(oeicId, 'Accumulating', 'A', 'EUR', 'True', null),
            newShareclass(oeicId, 'Income', 'B', 'USD', 'False', null),
            newShareclass(sicavId, 'Accumulating', 'I', 'GBP', 'False', null),
            newShareclass(sicavId, 'Distributing', 'F', 'CHF', 'True', 'Monthly'),
            newShareclass(sicavId, 'Income', 'X', 'JPY', 'False', 'Quarterly'),
            newShareclass(sicavId, 'Accumulating', 'MyInvestor', 'EUR', 'True', null)
        };
        List<String> expectedNames = new List<String>{ 'A EUR Acc Hdg', 'B USD Inc', 'I GBP Acc', 'F CHF Mdis Hdg', 'X JPY Qinc', 'MyInvestor' };

        // Share class created from the project screen (linked to every phase), then a Fund field selected on the project: NAVFrequency__c (Proposal)
        ShareclassNavigatorController.createAndLinkShareclass(phaseIdByName.get('Engineering'), 'A', 'EUR', 'Accumulating', 'Annually', 'False');
        update new ProjectProduct__c(Id = modificationId, TECH_FieldsToModify__c = 'NAVFrequency__c');

        Test.startTest();

        insert namedShareclasses;

        // Then 2 share class fields selected for modification: DividendFrequency__c (Engineering) and LegalType__c (Proposal)
        ProjectShareclass__c modifiedShareclass = [SELECT Id FROM ProjectShareclass__c WHERE ProjectProduct__c = :modificationId LIMIT 1];
        modifiedShareclass.TECH_FieldsToModify__c = 'DividendFrequency__c;LegalType__c';
        update modifiedShareclass;

        Test.stopTest();

        List<ProjectShareclass__c> savedShareclasses = [SELECT Name__c FROM ProjectShareclass__c WHERE Id IN :namedShareclasses];
        Map<Id, ProjectShareclass__c> savedById = new Map<Id, ProjectShareclass__c>(savedShareclasses);
        for (Integer i = 0; i < namedShareclasses.size(); i++) {
            System.assertEquals(expectedNames[i], savedById.get(namedShareclasses[i].Id).Name__c);
        }

        Set<String> childNames = new Set<String>();
        for (ProjectShareclassChild__c child : [SELECT Name FROM ProjectShareclassChild__c WHERE ProjectShareclasses__c = :namedShareclasses[0].Id]) {
            childNames.add(child.Name);
        }
        System.assertEquals(new Set<String>{ 'Design & Proposal', 'Engineering', 'Filing', 'SetUp' }, childNames, 'One Project Shareclass Child per stage, Design and Proposal sharing one');

        // The selected fields are blanked on the children, and the blank value is copied back to the share class
        ProjectShareclass__c savedModifiedShareclass = [SELECT DividendFrequency__c FROM ProjectShareclass__c WHERE Id = :modifiedShareclass.Id];
        System.assertEquals(null, savedModifiedShareclass.DividendFrequency__c);
    }

    @isTest
    static void test_taxTransparency() {
        Id projectId = [SELECT Id FROM ProjectProduct__c WHERE RecordTypeId = :fundCreationRtId AND LegalForm__c = 'SICAV' LIMIT 1].Id;
        ProjectShareclass__c shareclass = PMTTestFactoryData.createProjectShareclass(projectId, null);

        Test.startTest();

        // Empty -> 2 selections: 2 TaxData__c requested and the Tax team notified
        shareclass.TaxTransparency__c = 'AT;BE TIS';
        update shareclass;
        List<TaxData__c> createdTaxData = [SELECT Country__c, Type__c, Status__c, Source__c, ProjectProduct__c
                                           FROM TaxData__c
                                           WHERE ProjectShareclass__c = :shareclass.Id];

        // AT removed: its TaxData__c is canceled
        shareclass.TaxTransparency__c = 'BE TIS';
        update shareclass;

        Test.stopTest();

        Set<String> keys = new Set<String>();
        for (TaxData__c td : createdTaxData) {
            keys.add(td.Country__c + '|' + td.Type__c + '|' + td.Status__c);
            System.assertEquals(projectId, td.ProjectProduct__c);
            System.assertEquals('PMT', td.Source__c);
        }
        System.assertEquals(new Set<String>{ 'AT|Transparency|Requested', 'BE|BE TIS|Requested' }, keys);
        Map<String, String> statusByCountry = new Map<String, String>();
        for (TaxData__c td : [SELECT Country__c, Status__c FROM TaxData__c WHERE ProjectShareclass__c = :shareclass.Id]) {
            statusByCountry.put(td.Country__c, td.Status__c);
        }
        System.assertEquals('Canceled', statusByCountry.get('AT'));
        System.assertEquals('Requested', statusByCountry.get('BE'));
    }

    private static ProjectProduct__c newProject(String name, Id recordTypeId, String legalForm) {
        return new ProjectProduct__c(
            Name = name,
            RecordTypeId = recordTypeId,
            VehicleType__c = 'Funds',
            ProjectStartDate__c = Date.today().addDays(-20),
            EndDate__c = Date.today(),
            RiskAssociated__c = 'Equity;Interest rate;Credit;Currency',
            InvestmentObjective__c = 'Sample Objective',
            InvestmentStrategy__c = 'Sample Strategy',
            DomiciledIn__c = 'FR',
            ProjectStatus__c = 'Closed',
            ProductName__c = 'toto',
            LegalForm__c = legalForm,
            LettreRequise__c = 'No'
        );
    }

    private static ProjectShareclass__c newShareclass(Id projectId, String dividendPolicy, String type, String currencyCode, String hedging, String frequency) {
        return new ProjectShareclass__c(
            ProjectProduct__c = projectId,
            DividendPolicy__c = dividendPolicy,
            Type__c = type,
            Currency__c = currencyCode,
            CurrencyHedging__c = hedging,
            DividendFrequency__c = frequency
        );
    }
}