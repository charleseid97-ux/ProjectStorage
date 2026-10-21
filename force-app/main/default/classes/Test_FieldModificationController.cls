/** ──────────────────────────────────────
 * @description Tests of the fieldsModificationList LWC controller: fields to modify of an IS modification project (Product and Share
 *                  Classes) owned by the team of its Scope, the phase validations that follow, and the 3 update entry points of the LWC.
 * @covers FieldModificationController   100%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_FieldModificationController {

    private static final Id fundModificationRtId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();
    private static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();

    // IS modification project: fields to modify owned by IS, IS still has to validate Proposal
    @isTest
    static void test_getFieldsToModify() {
        Strategy__c s0 = new Strategy__c(Name = 'S0', AssetClass__c = 'Equity', SubAssetClass__c = 'Global', Code__c = 'S01');
        insert s0;
        Product__c p0 = new Product__c(Name = 'P0', FundStrategy__c = s0.Id, ProductName__c = 'Product Zero', Record_Type_Name__c = 'Fund', RecordTypeId = fundRecordTypeId, Validity__c = true, LegalForm__c = 'SICAV', VehicleType__c = 'Funds');
        insert p0;
        Share_Class__c sc0 = new Share_Class__c(Name = 'ShareClass0 A USD', CurrencyIsoCode = 'USD', Country__c = 'AT;BE;FR;DE;GB;XI;IT;LU;ES;SE;CH;NL', Type__c = 'A', Fund_Code__c = 'P0', Fund__c = p0.Id, Validity__c = true);
        insert sc0;

        // FIX-20178: fields configured for both Product Strategy and IS must resolve to the project's Scope team
        PMTTestFactoryData.createMatrice('Proposal', 'Product Strategy', 'NAVFrequency__c', 'DividendPolicy__c');
        PMTTestFactoryData.createMatrice('Proposal', 'IS', 'NAVFrequency__c', 'DividendPolicy__c');

        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundModificationRtId);
        proj.Product__c = p0.Id;
        proj.Scope__c = 'IS';
        proj.TECH_FieldsToModify__c = 'ForeseenEUCategory__c;NAVFrequency__c;PricingMethod__c;RecommendedHoldingPeriod__c';
        update proj;
        List<ProjectProductChild__c> phases = [SELECT Id FROM ProjectProductChild__c WHERE ProjectProductParent__c = :proj.Id];

        ProjectShareclass__c shareClass = PMTTestFactoryData.createProjectShareclass(proj.Id, 'DividendFrequency__c;Type__c;InvestmentStatusInvestors__c');
        shareClass.Tech_ShareClass__c = sc0.Id;
        update shareClass;
        List<ProjectChildJunction__c> junctionsToInsert = new List<ProjectChildJunction__c>();
        for (ProjectProductChild__c phase : phases) {
            junctionsToInsert.add(new ProjectChildJunction__c(ProjectProductChild__c = phase.Id, ProjectShareclass__c = shareClass.Id));
        }
        insert junctionsToInsert;

        Test.startTest();

        // Saving the selected fields again once the junctions exist runs both validateSteps (project and share class)
        proj.TECH_FieldsToModify__c = 'NAVFrequency__c;ForeseenEUCategory__c;PricingMethod__c;RecommendedHoldingPeriod__c';
        update proj;
        shareClass.TECH_FieldsToModify__c = 'DividendFrequency__c;Type__c;InvestmentStatusInvestors__c;DividendPolicy__c';
        update shareClass;
        List<Map<String, String>> productsList = FieldModificationController.getFieldsToModify(proj.Id, 'Product__c');
        List<Map<String, String>> scList = FieldModificationController.getFieldsToModify(proj.Id, 'Share_Class__c');

        Test.stopTest();

        System.assertNotEquals(0, productsList.size());
        System.assertNotEquals(0, scList.size());

        // IS-scoped project: PS/IS fields are owned by IS, never by Product Strategy
        for (Map<String, String> fieldData : productsList) {
            if (fieldData.get('fieldName') == 'NAVFrequency__c') System.assertEquals('IS', fieldData.get('teamOwner'));
        }
        for (Map<String, String> fieldData : scList) {
            if (fieldData.get('fieldName') == 'DividendPolicy__c') System.assertEquals('IS', fieldData.get('teamOwner'));
        }

        // IS still has to validate the Proposal step, Product Strategy has nothing to validate
        ProjectProductChild__c proposalChild = [SELECT TECH_TeamValidation__c
                                                FROM ProjectProductChild__c
                                                WHERE ProjectProductParent__c = :proj.Id AND Name = 'Proposal' LIMIT 1];
        Set<String> proposalTeams = new Set<String>(proposalChild.TECH_TeamValidation__c.split(';'));
        System.assert(!proposalTeams.contains('IS'), 'IS must still validate the Proposal step');
        System.assert(proposalTeams.contains('ProductStrategy'), 'Product Strategy has nothing to validate on an IS project');
    }

    // The 3 update entry points of the LWC, one after the other on the same product
    @isTest
    static void test_updateFields() {
        Product__c p = new Product__c(Name = 'P0', ProductName__c = 'Product Zero', Record_Type_Name__c = 'Fund', RecordTypeId = fundRecordTypeId, Validity__c = true, LegalForm__c = 'SICAV', VehicleType__c = 'Funds');
        insert p;
        FieldModificationController.FieldUpdate fieldUpdate = new FieldModificationController.FieldUpdate();
        fieldUpdate.recordId = p.Id;
        fieldUpdate.objectApiName = 'Product__c';
        fieldUpdate.fieldApiName = 'ProductName__c';
        fieldUpdate.newValue = 'Name 3';
        FieldModificationController.FieldUpdate emptyUpdate = new FieldModificationController.FieldUpdate(); // Incomplete update: skipped

        Test.startTest();

        FieldModificationController.updateFieldValue('Product__c', p.Id, 'ProductName__c', 'Name 1');
        String nameAfterUpdateFieldValue = getProductName(p.Id);
        FieldModificationController.updateFieldVal('Product__c', p.Id, 'ProductName__c', 'Name 2');
        String nameAfterUpdateFieldVal = getProductName(p.Id);
        FieldModificationController.updateMultipleFields(new List<FieldModificationController.FieldUpdate>{ fieldUpdate, emptyUpdate });
        String nameAfterUpdateMultipleFields = getProductName(p.Id);

        Test.stopTest();

        System.assertEquals('Name 1', nameAfterUpdateFieldValue, 'updateFieldValue');
        System.assertEquals('Name 2', nameAfterUpdateFieldVal, 'updateFieldVal');
        System.assertEquals('Name 3', nameAfterUpdateMultipleFields, 'updateMultipleFields');
    }

    private static String getProductName(Id productId) {
        Product__c product = [SELECT ProductName__c FROM Product__c WHERE Id = :productId];
        return product.ProductName__c;
    }
}