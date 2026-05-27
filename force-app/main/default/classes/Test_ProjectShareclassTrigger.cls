@isTest
public class Test_ProjectShareclassTrigger {
    
    private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c
        .getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();
    
    
    
    
    @IsTest(SeeAllData=true)
    static void test_ShareClassCreation() {
        System.debug('[DEBUG TEST Share Class Trigger]');
        
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);
        List<ProjectProductChild__c> childs = [SELECT Id,ProjectProductParent__c FROM ProjectProductChild__c where ProjectProductParent__c=:proj.Id];
        Test.startTest();
        ProjectShareclass__c shareClass = PMTTestFactoryData.createProjectShareclass(proj.Id, 'DividendFrequency__c;Type__c;DividendPolicy__c;InvestmentStatusInvestors__c');
        List<ProjectChildJunction__c> junctionsToInsert = new List<ProjectChildJunction__c>();
        for (ProjectProductChild__c sibling : childs) {
            junctionsToInsert.add(new ProjectChildJunction__c(
                ProjectProductChild__c = sibling.Id,
                ProjectShareclass__c = shareClass.Id
            ));
            
        }
        insert junctionsToInsert;
        List<ProjectShareclassChild__c> scchilds = [Select Id From ProjectShareclassChild__c where ProjectShareclasses__c = :shareClass.Id];
        
        List<ProjectChildJunction__c> junctions = [SELECT Id FROM ProjectChildJunction__c WHERE ProjectShareclass__c =:shareClass.Id ];
        
        Milestone__c milestone = [SELECT Id FROM Milestone__c WHERE Project_product__c = :proj.Id AND Name = 'SPC Final' LIMIT 1];
        milestone.Status__c='Completed';
        update milestone;
        shareClass.TECH_FieldsToModify__c = 'DividendFrequency__c';
        update shareClass;
        system.assertNotEquals(0, scchilds.size());
        Test.stopTest();
        
    }
    
    @IsTest(SeeAllData=true)
    static void test_TaxTransparency_CreateCancel_AndEmail() {
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);
        
        ProjectShareclass__c shareClass = PMTTestFactoryData.createProjectShareclass(
            proj.Id,
            'DividendFrequency__c;Type__c'
        );
        
        // Ancienne valeur vide -> nouvelle valeur remplie = création TaxData + email
        Test.startTest();
        
        shareClass.TaxTransparency__c = 'AT;BE TIS';
        update shareClass;
        
        List<TaxData__c> createdTaxData = [
            SELECT Id, Country__c, Type__c, Status__c, Source__c,
            ProjectProduct__c, ProjectShareclass__c
            FROM TaxData__c
            WHERE ProjectShareclass__c = :shareClass.Id
            AND Source__c = 'PMT'
        ];
        
        System.assertEquals(2, createdTaxData.size(), '2 TaxData doivent être créés');
        
        Set<String> keys = new Set<String>();
        for (TaxData__c td : createdTaxData) {
            keys.add(td.Country__c + '|' + td.Type__c + '|' + td.Status__c);
            System.assertEquals(proj.Id, td.ProjectProduct__c);
            System.assertEquals(shareClass.Id, td.ProjectShareclass__c);
            System.assertEquals('PMT', td.Source__c);
        }
        
        System.assert(keys.contains('AT|Transparency|Requested'));
        System.assert(keys.contains('BE|BE TIS|Requested'));
        
        // Nouvelle valeur retire FR -> le TaxData FR doit passer à Canceled
        shareClass.TaxTransparency__c = 'BE TIS';
        update shareClass;
        
        TaxData__c canceledFr = [
            SELECT Id, Country__c, Type__c, Status__c
            FROM TaxData__c
            WHERE ProjectShareclass__c = :shareClass.Id
            AND Country__c = 'AT'
            AND Type__c = 'Transparency'
            LIMIT 1
        ];
        
        System.assertEquals('Canceled', canceledFr.Status__c);
        
        // Si la custom metadata email existe et est active, l’email doit être invoqué
        Integer activeConfigCount = [
            SELECT COUNT()
            FROM TaxEmailConfiguration__mdt
            WHERE Country__c = 'ALL'
            AND Scenario__c = 'InternalTaxTransparencyNotification'
            AND IsActive__c = true
        ];
        
        if (activeConfigCount > 0) {
            System.assert(
                Limits.getEmailInvocations() > 0,
                'Un email Tax Transparency doit être préparé/envoyé'
            );
        }
        
        Test.stopTest();
    }
    private static ProjectProduct__c createProjectProduct(String legalForm) {
        Id rtParent = PMTTestFactoryData.getRecordTypeId(
            'ProjectProduct__c',
            'FundCreation'
        );
        
        ProjectProduct__c product = new ProjectProduct__c(
            Name = 'Test' + legalForm,
            RecordTypeId = rtParent,
            VehicleType__c = 'Funds',
            ProjectStartDate__c = Date.today().addDays(-20),
            EndDate__c = Date.today(),
            RiskAssociated__c = 'Equity;Interest rates;Credit;Currency',
            InvestmentObjective__c = 'Sample Objective',
            InvestmentStrategy__c = 'Sample Strategy',
            DomiciledIn__c = 'FR',
            ProjectStatus__c = 'Closed',
            Product_Name__c = 'toto',
            SFDRCategory__c = '0',
            LegalForm__c = legalForm
        );
        
        insert product;
        return product;
    }
    
    private class ShareClassNameTestCase {
        Id projectProductId;
        String dividendPolicy;
        String typeValue;
        String curr;
        String hedging;
        String frequency;
        String expectedValue;
        
        ShareClassNameTestCase(
            Id projectProductId,
            String dividendPolicy,
            String typeValue,
            String curr,
            String hedging,
            String frequency,
            String expectedValue
        ) {
            this.projectProductId = projectProductId;
            this.dividendPolicy = dividendPolicy;
            this.typeValue = typeValue;
            this.curr = curr;
            this.hedging = hedging;
            this.frequency = frequency;
            this.expectedValue = expectedValue;
        }
    }
    
    private static void assertGeneratedNames(List<ShareClassNameTestCase> testCases) {
        List<ProjectShareclass__c> shareClasses = new List<ProjectShareclass__c>();
        
        for (ShareClassNameTestCase tc : testCases) {
            shareClasses.add(new ProjectShareclass__c(
                ProjectProduct__c = tc.projectProductId,
                DividendPolicy__c = tc.dividendPolicy,
                Type__c = tc.typeValue,
                Currency__c = tc.curr,
                CurrencyHedging__c = tc.hedging,
                DividendFrequency__c = tc.frequency
            ));
        }
        
        insert shareClasses;
        
        Map<Id, ProjectShareclass__c> resultsById = new Map<Id, ProjectShareclass__c>([
            SELECT Id, Name__c
            FROM ProjectShareclass__c
            WHERE Id IN :shareClasses
        ]);
        
        for (Integer i = 0; i < shareClasses.size(); i++) {
            System.assertEquals(
                testCases[i].expectedValue,
                resultsById.get(shareClasses[i].Id).Name__c
            );
        }
    }
    
    @isTest
    static void testGeneratedNames() {
        ProjectProduct__c pOEIC = createProjectProduct('OEIC');
        ProjectProduct__c pSICAV = createProjectProduct('SICAV');
        
        assertGeneratedNames(new List<ShareClassNameTestCase>{
            new ShareClassNameTestCase(
                pOEIC.Id, 'Accumulating', 'A', 'EUR', 'True', null, 'A EUR Acc Hdg'
            ),
                new ShareClassNameTestCase(
                    pOEIC.Id, 'Income', 'B', 'USD', 'False', null, 'B USD Inc'
                ),
                new ShareClassNameTestCase(
                    pSICAV.Id, 'Accumulating', 'I', 'GBP', 'False', null, 'I GBP Acc'
                ),
                new ShareClassNameTestCase(
                    pSICAV.Id, 'Distributing', 'F', 'CHF', 'True', 'Monthly', 'F CHF Mdis Hdg'
                ),
                new ShareClassNameTestCase(
                    pSICAV.Id, 'Income', 'X', 'JPY', 'False', 'Quarterly', 'X JPY Qinc'
                ),
                new ShareClassNameTestCase(
                    pSICAV.Id, 'Accumulating', 'MyInvestor', 'EUR', 'True', null, 'MyInvestor'
                )
                }
        );
        
    }
}