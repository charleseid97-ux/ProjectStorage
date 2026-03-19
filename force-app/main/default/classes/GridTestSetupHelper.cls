/** ──────────────────────────────────────
 * @description Centralized test data factory for all Grid-related test classes. 
 *              Provides @TestSetup method that creates realistic test data volume (3 strategies, 6 products, 24 share classes, 
 *              3 grids, 3 scopes, 3 agreements, 48 AUM records, 120 country registrations). 
 *              Includes helper methods for creating and retrieving test data by type, avoiding duplication across test classes 
 *              and ensuring data consistency.
 *              Disables AgreementTrigger in test context to avoid permission issues.
 * @author Charles EID
 * @usedBy GridDetailBuilderTest, GridBuilderControllerTest, GridValidationControllerTest,
 *         GridDetailTableControllerTest, GridExcelImportServiceTest, GridLifecycleTest
────────────────────────────────────── */
@IsTest
public with sharing class GridTestSetupHelper {

    // ------------------------------------ CONSTANTS ------------------------------------
    public static final String TEST_TEAM_FR = 'France';
    public static final String TEST_TEAM_UK = 'United Kingdom';
    public static final String TEST_TEAM_DE = 'Germany';

    public static final String SHARE_TYPE_A = 'A';
    public static final String SHARE_TYPE_AW = 'AW';
    public static final String SHARE_TYPE_E = 'E';
    public static final String SHARE_TYPE_F = 'F';

    public static final String LEGAL_STATUS_FCP = 'FCP';
    public static final String LEGAL_STATUS_SICAV = 'SICAV';

    public static final String CURRENCY_EUR = 'EUR';
    public static final String CURRENCY_USD = 'USD';

    public static final String ASSET_CLASS_EQUITY = 'Equity';
    public static final String ASSET_CLASS_FIXED_INCOME = 'Fixed Income';
    public static final String ASSET_CLASS_DIVERSIFIED = 'Diversified';

    public static final String GRID_NAME_S1 = 'S1';
    public static final String GRID_NAME_S5_PLUS = 'S5+';
    public static final String GRID_NAME_TEST = 'TestGrid';

    // ------------------------------------ @TestSetup ------------------------------------
    @TestSetup
    public static void setupTestData() {
        User u = TestFactory.getCarmignacUserTestApex();

        System.runAs(u) {
            // 1. Create Strategies (3)
            List<Strategy__c> strategies = new List<Strategy__c>{
                createStrategy('Equity Strategy', ASSET_CLASS_EQUITY, 'EQ'),
                createStrategy('Fixed Income Strategy', ASSET_CLASS_FIXED_INCOME, 'FI'),
                createStrategy('Diversified Strategy', ASSET_CLASS_DIVERSIFIED, 'DI')
            };
            insert strategies;

            // 2. Create Products/Funds (6 - 2 per strategy)
            List<Product__c> products = new List<Product__c>();
            for (Integer i = 0; i < strategies.size(); i++) {
                products.add(createProduct(strategies[i].Id, 'Product ' + (i*2 + 1), 'PROD' + (i*2 + 1), LEGAL_STATUS_FCP));
                products.add(createProduct(strategies[i].Id, 'Product ' + (i*2 + 2), 'PROD' + (i*2 + 2), LEGAL_STATUS_SICAV));
            }
            insert products;

            // 3. Create Share Classes (24 - 4 per product)
            List<Share_Class__c> shareClasses = new List<Share_Class__c>();
            Integer isinCounter = 1000;
            for (Product__c product : products) {
                shareClasses.add(createShareClass(product.Id, 'SC-A-' + product.InternalShortName__c, 'LU' + (isinCounter++), SHARE_TYPE_A, 1.5, CURRENCY_EUR));
                shareClasses.add(createShareClass(product.Id, 'SC-AW-' + product.InternalShortName__c, 'LU' + (isinCounter++), SHARE_TYPE_AW, 2.0, CURRENCY_EUR));
                shareClasses.add(createShareClass(product.Id, 'SC-E-' + product.InternalShortName__c, 'LU' + (isinCounter++), SHARE_TYPE_E, 1.0, CURRENCY_USD));
                shareClasses.add(createShareClass(product.Id, 'SC-INST-' + product.InternalShortName__c, 'LU' + (isinCounter++), SHARE_TYPE_F, 0.5, CURRENCY_EUR));
            }
            insert shareClasses;

            // 4. Create Country Registrations (for all share classes)
            List<Country__c> countries = new List<Country__c>();
            List<String> countryList = new List<String>{'FR', 'GB', 'DE', 'IT', 'CH'};
            for (Share_Class__c sc : shareClasses) {
                for (String countryCode : countryList) {
                    countries.add(createCountry(sc.Id, countryCode, 'REG', sc.ISIN__c));
                }
            }
            insert countries;

            // 5. Create Test Companies (Accounts)
            List<Account> companies = new List<Account>{
                createAccount('Test Company FR', 'Client', '123 Test Street', 'Paris', '75001', 'France', 'IFA', 'IFA', 'BP_FR'),
                createAccount('Test Company UK', 'Client', '456 Test Avenue', 'London', 'SW1A 1AA', 'United Kingdom', 'IFA', 'IFA', 'BP_UK'),
                createAccount('Test Company DE', 'Client', '789 Test Strasse', 'Berlin', '10115', 'Germany', 'IFA', 'IFA', 'BP_DA')
            };
            insert companies;

            // 6. Create Grids (3)
            List<Grid__c> grids = new List<Grid__c>{
                createGrid(GRID_NAME_S1, TEST_TEAM_FR, true, GridBuilderHelper.RT_STANDARD_GRID),
                createGrid(GRID_NAME_S5_PLUS, TEST_TEAM_UK, true, GridBuilderHelper.RT_STANDARD_GRID),
                createGrid(GRID_NAME_TEST, TEST_TEAM_DE, true, GridBuilderHelper.RT_STANDARD_GRID)
            };
            insert grids;

            // 7. Create GridScopes (3) — references Grids inserted above
            List<GridScope__c> scopes = new List<GridScope__c>{
                createGridScope(GRID_NAME_S1, grids[0].Id, 'AGR-FR', 'FR', 'FCP'),
                createGridScope(GRID_NAME_S5_PLUS, grids[1].Id, 'ALL', 'ALL', 'SICAV'),
                createGridScope(GRID_NAME_TEST, grids[2].Id, 'AGR-FR;AGR-DE', 'GB;DE', 'FCP;SICAV')
            };
            insert scopes;

            // 8. Create Agreements/Conventions (3)
            AgreementTriggerHandler.triggerDisabled = true; // Disable Agreement trigger to avoid permission issues in test context
            Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);
            List<Convention__c> agreements = new List<Convention__c>{
                createAgreement('AGR-FR', 'France Agreement', 'AGR-FR-001', companies[0].Id, grids[0].Id, 'FR', agmRtMap),
                createAgreement('AGR-UK', 'UK Agreement', 'AGR-UK-001', companies[1].Id, grids[1].Id, 'GB', agmRtMap),
                createAgreement('AGR-DE', 'Germany Agreement', 'AGR-DE-001', companies[2].Id, grids[2].Id, 'DE', agmRtMap)
            };
            insert agreements;
            AgreementTriggerHandler.triggerDisabled = false; // Re-enable Agreement trigger after test data creation

            // 9. Create AUM records (48 - 2 agreements × 24 share classes)
            List<AUM__c> aums = new List<AUM__c>();
            for (Share_Class__c sc : shareClasses) {
                aums.add(createAUM(sc.Id, agreements[0].Id, companies[0].Id, 100000 + Math.random() * 50000, Date.today().addDays(-30)));
                aums.add(createAUM(sc.Id, agreements[1].Id, companies[1].Id, 75000 + Math.random() * 25000, Date.today().addDays(-30)));
            }
            insert aums;
        }
    }

    // ------------------------------------ STRATEGY METHODS ------------------------------------
    public static Strategy__c createStrategy(String name, String assetClass, String code) {
        return new Strategy__c(
            Name = name,
            AssetClass__c = assetClass,
            Code__c = code // Unique external ID
        );
    }

    public static List<Strategy__c> getTestStrategies() {
        return [SELECT Id, Name, AssetClass__c FROM Strategy__c ORDER BY Name];
    }

    // ------------------------------------ PRODUCT METHODS ------------------------------------
    public static Product__c createProduct(Id strategyId, String name, String internalShortName, String legalStatus) {
        return new Product__c(
            Name = name,
            ProductName__c = name,
            FundStrategy__c = strategyId,
            InternalShortName__c = internalShortName,
            Legal_Status__c = legalStatus,
            Fund_Code__c = internalShortName // Unique external ID
        );
    }

    public static List<Product__c> getTestProducts() {
        return [SELECT Id, Name, ProductName__c, FundStrategy__c, InternalShortName__c, Legal_Status__c
                FROM Product__c
                ORDER BY Name];
    }

    public static Product__c getTestProductByShortName(String shortName) {
        List<Product__c> products = [SELECT Id, Name, InternalShortName__c, Legal_Status__c
                                  FROM Product__c
                                  WHERE InternalShortName__c = :shortName
                                  LIMIT 1];
        return products.isEmpty() ? null : products[0];
    }

    // ------------------------------------ SHARE CLASS METHODS ------------------------------------
    public static Share_Class__c createShareClass(Id productId, String name, String isin, String type, Decimal effectiveMgtFees, String currencyCode) {
        return new Share_Class__c(
            Name = name,
            Name__c = name,
            Fund__c = productId,
            ISIN__c = isin,
            ISIN_Code__c = isin, // Unique external ID
            Type__c = type,
            EffectiveManagementFees__c = effectiveMgtFees,
            Currency__c = currencyCode
        );
    }

    public static List<Share_Class__c> getTestShareClasses() {
        return [SELECT Id, Name, Name__c, Fund__c, ISIN__c, Type__c, EffectiveManagementFees__c, Currency__c,
                       Fund__r.Legal_Status__c, Fund__r.InternalShortName__c, Fund__r.FundStrategy__c
                FROM Share_Class__c
                ORDER BY Name];
    }

    public static Map<String, Share_Class__c> getShareClassesByType() {
        Map<String, Share_Class__c> scByType = new Map<String, Share_Class__c>();
        for (Share_Class__c sc : getTestShareClasses()) {
            if (!scByType.containsKey(sc.Type__c)) {
                scByType.put(sc.Type__c, sc);
            }
        }
        return scByType;
    }

    public static List<Share_Class__c> getShareClassesForProduct(Id productId) {
        return [SELECT Id, Name, Type__c, ISIN__c, EffectiveManagementFees__c, Currency__c
                FROM Share_Class__c
                WHERE Fund__c = :productId
                ORDER BY Type__c];
    }

    public static Share_Class__c getShareClassByType(String type) {
        List<Share_Class__c> shareClasses = [SELECT Id, Name, Type__c, Fund__c, ISIN__c, EffectiveManagementFees__c,
                                              Fund__r.Legal_Status__c, Fund__r.InternalShortName__c
                                              FROM Share_Class__c
                                              WHERE Type__c = :type
                                              LIMIT 1];
        return shareClasses.isEmpty() ? null : shareClasses[0];
    }

    // ------------------------------------ COUNTRY METHODS ------------------------------------
    public static Country__c createCountry(Id shareClassId, String country, String registrationStatus, String isinCode) {
        return new Country__c(
            ShareClass__c = shareClassId,
            Country__c = country,
            RegistrationStatus__c = registrationStatus,
            ISINCountryKey__c = isinCode + '-' + country, // Unique external ID
            RegistrationDate__c = Date.today(),
            StartDate__c = Date.today()
        );
    }

    public static List<Country__c> getTestCountries() {
        return [SELECT Id, ShareClass__c, Country__c, RegistrationStatus__c
                FROM Country__c
                ORDER BY ShareClass__c, Country__c];
    }

    // ------------------------------------ ACCOUNT METHODS ------------------------------------
    public static Account createAccount(String name, String accountType, String street, String city, String postalCode, String country, String distributorType, String subType, String businessRegion) {
        return new Account(
            Name = name,
            Type = accountType,
            BillingStreet = street,
            BillingCity = city,
            BillingPostalCode = postalCode,
            BillingCountry = country,
            Distributor_Type__c = distributorType,
            Sub_Type__c = subType,
            LegalForm__c = 'Other',
            In__c = 'Wholesale',
            Final_Distribution__c = 'Retail',
            BusinessDevelopmentRegion__c = businessRegion
        );
    }

    public static List<Account> getTestAccounts() {
        return [SELECT Id, Name, Type, BillingStreet, BillingCity, BillingPostalCode, BillingCountry, Distributor_Type__c
                FROM Account
                ORDER BY Name];
    }

    // ------------------------------------ AGREEMENT METHODS ------------------------------------
    public static Convention__c createAgreement(String name, String conventionName, String agreementCode, Id companyId, Id gridId, String countriesOfDistribution, Map<String, Id> agmRtMap) {
        return new Convention__c(
            Name = name,
            ConventionName__c = conventionName,
            Agreement_Code__c = agreementCode,
            Company__c = companyId,
            Grid__c = gridId,
            EffectiveDate__c = Date.today(),
            IsSigned__c = true,
            Countries_of_Distribution__c = countriesOfDistribution,
            Code_Type__c = 'Distribution Agreement', 
            Agreement_Type__c = 'Master',
            RecordTypeId = agmRtMap.get('Request_Agreement')
        );
    }

    public static Convention__c createAgreement(String name, String conventionName, String agreementCode, Id companyId, Id gridId, Id gridRequestId, Date gridRequestStartDate, String countriesOfDistribution, Map<String, Id> agmRtMap) {
        Convention__c agr = createAgreement(name, conventionName, agreementCode, companyId, gridId, countriesOfDistribution, agmRtMap);
        agr.Grid_Request__c = gridRequestId;
        agr.Grid_Request_Start_Date__c = gridRequestStartDate;
        return agr;
    }

    public static List<Convention__c> getTestAgreements() {
        return [SELECT Id, Name, ConventionName__c, Team__c
                FROM Convention__c
                ORDER BY Name];
    }

    public static Convention__c getTestAgreementByTeam(String team) {
        List<Convention__c> agreements = [SELECT Id, Name, ConventionName__c, Team__c
                                          FROM Convention__c
                                          WHERE Team__c = :team
                                          LIMIT 1];
        return agreements.isEmpty() ? null : agreements[0];
    }

    // ------------------------------------ GRID & SCOPE METHODS ------------------------------------
    public static GridScope__c createGridScope(String gridName, Id gridId, String agreement, String country, String productCode) {
        String scopeName = 'Grid Scope for ' + gridName + ' - ' + Date.today().format();
        return new GridScope__c(
            Name = scopeName,
            Grid__c = gridId,
            Agreement__c = agreement,
            Country__c = country,
            ProductCode__c = productCode
        );
    }

    public static Grid__c createGrid(String name, String team, Boolean active, String recordTypeDeveloperName) {
        return new Grid__c(
            Name = name,
            ActiveGrid__c = active,
            RecordTypeId = Schema.SObjectType.Grid__c.getRecordTypeInfosByDeveloperName().get(recordTypeDeveloperName).getRecordTypeId()
        );
    }

    public static List<Grid__c> getTestGrids() {
        return [SELECT Id, Name, ActiveGrid__c
                FROM Grid__c
                ORDER BY Name];
    }

    public static Grid__c getTestGridByName(String name) {
        List<Grid__c> grids = [SELECT Id, Name, ActiveGrid__c
                               FROM Grid__c
                               WHERE Name = :name
                               LIMIT 1];
        return grids.isEmpty() ? null : grids[0];
    }

    public static List<GridScope__c> getTestGridScopes() {
        return [SELECT Id, Name, Grid__c, Agreement__c, Country__c, ProductCode__c
                FROM GridScope__c
                ORDER BY Name];
    }

    // ------------------------------------ CRITERIA & RULE METHODS ------------------------------------
    public static GridCriteria__c createCriteria(Id gridId, String filterLogic, String filterLogicExpression, String comment) {
        return new GridCriteria__c(
            Grid__c = gridId,
            FilterLogic__c = filterLogic,
            FilterLogicExpression__c = filterLogicExpression,
            Comment__c = comment,
            StartDate__c = Date.today(),
            EndDate__c = Date.newInstance(2099, 12, 31)
        );
    }

    public static GridCriteriaDetail__c createCriteriaDetail(Id criteriaId, Integer filterNumber, String objectName, String field, String logic, String value, String techOrigin) {
        return new GridCriteriaDetail__c(
            GridCriteria__c = criteriaId,
            FilterNumber__c = filterNumber,
            Object__c = objectName,
            Field__c = field,
            Logic__c = logic,
            Value__c = value,
            TECHOrigin__c = techOrigin
        );
    }

    public static GridRule__c createGridRule(Id gridId, Id criteriaId, String ruleToApply, String feesType, Decimal gridRate, String shareType, String otherShareType, String otherGridRule) {
        return new GridRule__c(
            Grid__c = gridId,
            GridCriteria__c = criteriaId,
            RuleToApply__c = ruleToApply,
            FeesType__c = feesType,
            GridRate__c = gridRate,
            ShareType__c = shareType,
            OtherShareType__c = otherShareType,
            OtherGridRule__c = otherGridRule
        );
    }

    public static List<GridCriteria__c> getTestCriteria() {
        return [SELECT Id, Grid__c, FilterLogic__c, FilterLogicExpression__c, Comment__c, StartDate__c, EndDate__c
                FROM GridCriteria__c
                ORDER BY CreatedDate];
    }

    public static List<GridCriteriaDetail__c> getTestCriteriaDetails() {
        return [SELECT Id, GridCriteria__c, FilterNumber__c, Object__c, Field__c, Logic__c, Value__c, TECHOrigin__c
                FROM GridCriteriaDetail__c
                ORDER BY GridCriteria__c, FilterNumber__c];
    }

    public static List<GridRule__c> getTestGridRules() {
        return [SELECT Id, Grid__c, GridCriteria__c, RuleToApply__c, FeesType__c, GridRate__c,
                       ShareType__c, OtherShareType__c, OtherGridRule__c
                FROM GridRule__c
                ORDER BY CreatedDate];
    }

    // ------------------------------------ GRID DETAIL METHODS ------------------------------------
    public static GridDetail__c createGridDetail(Id gridId, Id gridRuleId, Id criteriaId, Id shareClassId, Decimal rebateRate, Date startDate, Date endDate, String recordTypeDeveloperName) {
        Id recordTypeId = Schema.SObjectType.GridDetail__c.getRecordTypeInfosByDeveloperName().get(recordTypeDeveloperName).getRecordTypeId();
        return new GridDetail__c(
            RecordTypeId = recordTypeId,
            Grid__c = gridId,
            GridRule__c = gridRuleId,
            GridCriteria__c = criteriaId,
            ShareClass__c = shareClassId,
            RebateRate__c = rebateRate,
            StartDate__c = startDate,
            EndDate__c = endDate
        );
    }

    public static GridDetail__c createCustomGridDetail(Id gridId, Id criteriaId, Id shareClassId, Id standardGridDetailId, Date startDate) {
        return new GridDetail__c(
            RecordTypeId        = Schema.SObjectType.GridDetail__c.getRecordTypeInfosByDeveloperName().get(GridBuilderHelper.RT_CUSTOM_GRID_DETAIL).getRecordTypeId(),
            Grid__c             = gridId,
            GridCriteria__c     = criteriaId,
            ShareClass__c       = shareClassId,
            StandardGridDetail__c = standardGridDetailId,
            StartDate__c        = startDate
        );
    }

    public static List<GridDetail__c> getTestGridDetails() {
        return [SELECT Id, Grid__c, GridRule__c, GridCriteria__c, ShareClass__c, RebateRate__c, StartDate__c, EndDate__c
                FROM GridDetail__c
                ORDER BY CreatedDate];
    }

    // ────────────────────────────────────── AGREEMENT GRID TIMELINE METHODS ──────────────────────────────────────
    public static AgreementGridTimeline__c createAgreementGridTimeline(Id agreementId, Id gridId, Date startDate, Date endDate, String status) {
        return new AgreementGridTimeline__c(
            Agreement__c = agreementId,
            Grid__c = gridId,
            GridStartDate__c = startDate,
            GridEndDate__c = endDate,
            Status__c = status
        );
    }

    public static List<AgreementGridTimeline__c> getTestAgreementGridTimelines(Id agreementId) {
        return [SELECT Id, Agreement__c, Grid__c, GridStartDate__c, GridEndDate__c, Status__c
                FROM AgreementGridTimeline__c
                WHERE Agreement__c = :agreementId
                ORDER BY GridStartDate__c];
    }

    // ────────────────────────────────────── AUM METHODS ──────────────────────────────────────
    public static AUM__c createAUM(Id shareClassId, Id conventionId, Id companyId, Decimal amountEUR, Date aumDate) {
        // Construct unique external ID from convention, shareclass, and date
        String externalId = String.valueOf(conventionId).substring(0, 15) + '-' +
                           String.valueOf(shareClassId).substring(0, 15) + '-' +
                           String.valueOf(aumDate);

        return new AUM__c(
            ShareClass__c = shareClassId,
            Convention__c = conventionId,
            Company__c = companyId, // Required field
            AmountEUR__c = amountEUR,
            Date__c = aumDate, // Required date field
            Amount__c = amountEUR,
            AUMExternalId__c = externalId // Required unique external ID
        );
    }

    public static List<AUM__c> getTestAUMs() {
        return [SELECT Id, ShareClass__c, Convention__c, AmountEUR__c
                FROM AUM__c
                ORDER BY ShareClass__c];
    }
}