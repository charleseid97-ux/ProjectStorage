@IsTest
private class RFP_Helper_Test {

    private static final String CATEGORY = 'Corporate';
    private static final String SUBCATEGORY = 'ESG';

    @IsTest
    static void testGetSubCategories_BlankCategory() {

        Test.startTest();
        List<RFP_Helper.PicklistOption> results = RFP_Helper.getSubCategories(null);
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testGetSubCategories_NoRecords() {

        Test.startTest();
        List<RFP_Helper.PicklistOption> results = RFP_Helper.getSubCategories(CATEGORY);
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testGetSubCategories_ReturnsUsedValues() {

        insert new List<RFP_Library__c>{
            new RFP_Library__c(
                Category__c = CATEGORY,
                SubCategory__c = SUBCATEGORY
            ),
            new RFP_Library__c(
                Category__c = CATEGORY,
                SubCategory__c = SUBCATEGORY
            )
        };

        Test.startTest();
        List<RFP_Helper.PicklistOption> results = RFP_Helper.getSubCategories(CATEGORY);
        Test.stopTest();

        System.assertEquals(1, results.size());

        RFP_Helper.PicklistOption opt = results[0];

        System.assertEquals(SUBCATEGORY, opt.value);
        System.assert(opt.label.contains(SUBCATEGORY));
    }
}