@IsTest
private class ProjectFeederControllerTest {

    // Constants to avoid duplicated literals (fix Sonar CODE_SMELL)
    private static final String ASSERT_NOT_NULL_MSG = 'DTO list should not be null';
    private static final String FEEDER_PRODUCT_NAME = 'Feeder Product';

    @TestSetup
    static void setupData() {
        // Create ProjectProduct records
        ProjectProduct__c projectWithFeeder = new ProjectProduct__c(
            Name = 'PT With Feeder'
        );
        insert projectWithFeeder;

        ProjectProduct__c projectWithoutFeeder = new ProjectProduct__c(
            Name = 'PT Without Feeder'
        );
        insert projectWithoutFeeder;

        // Create feeder product (custom Product__c used in your org)
        Product__c feeder = new Product__c(
            Name = FEEDER_PRODUCT_NAME,
            ProductName__c = FEEDER_PRODUCT_NAME,
            Validity__c = true
        );
        insert feeder;

        // ProjectShareclass linked to projectWithFeeder WITH feeder (should be returned)
        ProjectShareclass__c scWithFeeder = new ProjectShareclass__c(
            ProjectProduct__c = projectWithFeeder.Id,
            Feeder__c = feeder.Id,
            Type__c = 'X'
        );
        insert scWithFeeder;

        // ProjectShareclass linked to projectWithFeeder WITHOUT feeder (should be ignored)
        ProjectShareclass__c scNoFeeder = new ProjectShareclass__c(
            ProjectProduct__c = projectWithFeeder.Id,
            Type__c = 'A'
        );
        insert scNoFeeder;

        // For projectWithoutFeeder: shareclass without feeder
        ProjectShareclass__c scOnly = new ProjectShareclass__c(
            ProjectProduct__c = projectWithoutFeeder.Id,
            Type__c = 'A'
        );
        insert scOnly;
    }

    @IsTest
    static void testGetFeeders_WithFeeder() {
        ProjectProduct__c proj = [
            SELECT Id FROM ProjectProduct__c
            WHERE Name = 'PT With Feeder'
            LIMIT 1
        ];

        Test.startTest();
        List<ProjectFeederController.FeederLineDTO> dtos = ProjectFeederController.getFeeders(proj.Id);
        Test.stopTest();

        // Expect one DTO corresponding to the shareclass that has a feeder
        System.assertNotEquals(null, dtos, ASSERT_NOT_NULL_MSG);
        System.assertEquals(1, dtos.size(), 'Expected exactly 1 feeder DTO');

        ProjectFeederController.FeederLineDTO dto = dtos[0];
        System.assertNotEquals(null, dto.shareclassId, 'shareclassId must be populated');
        System.assert( dto.shareclassName.contains('X'), 'shareclassName should match');
        System.assertNotEquals(null, dto.feederId, 'feederId must be populated');
        System.assertEquals(FEEDER_PRODUCT_NAME, dto.feederName, 'feederName should match ProductName__c');
    }

    @IsTest
    static void testGetFeeders_NoFeeder() {
        ProjectProduct__c projNo = [
            SELECT Id FROM ProjectProduct__c
            WHERE Name = 'PT Without Feeder'
            LIMIT 1
        ];

        Test.startTest();
        List<ProjectFeederController.FeederLineDTO> dtos = ProjectFeederController.getFeeders(projNo.Id);
        Test.stopTest();

        // No feeders expected for this project
        System.assertNotEquals(null, dtos, ASSERT_NOT_NULL_MSG);
        System.assertEquals(0, dtos.size(), 'Expected 0 feeder DTOs for project with no feeders');
    }

    @IsTest
    static void testGetFeeders_NullInput() {
        Test.startTest();
        List<ProjectFeederController.FeederLineDTO> dtos = ProjectFeederController.getFeeders(null);
        Test.stopTest();

        System.assertNotEquals(null, dtos, ASSERT_NOT_NULL_MSG);
        System.assertEquals(0, dtos.size(), 'Expected 0 DTOs when passing null projectId');
    }
}