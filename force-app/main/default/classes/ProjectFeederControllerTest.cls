/** ──────────────────────────────────────
 * @description Tests of ProjectFeederController.getFeeders: feeder lines of a project's share classes, a project without feeder, and
 *                  a null project Id.
 * @author Khadija
 * @covers ProjectFeederController   100%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
private class ProjectFeederControllerTest {

    private static final String FEEDER_PRODUCT_NAME = 'Feeder Product';

    @isTest
    static void test_getFeeders() {
        ProjectProduct__c projectWithFeeder = new ProjectProduct__c(Name = 'PT With Feeder', ProjectStartDate__c = Date.today());
        ProjectProduct__c projectWithoutFeeder = new ProjectProduct__c(Name = 'PT Without Feeder', ProjectStartDate__c = Date.today());
        insert new List<ProjectProduct__c>{ projectWithFeeder, projectWithoutFeeder };
        Product__c feeder = new Product__c(Name = FEEDER_PRODUCT_NAME, ProductName__c = FEEDER_PRODUCT_NAME, Validity__c = true);
        insert feeder;

        // Only the share class with a feeder is returned
        insert new List<ProjectShareclass__c>{
            new ProjectShareclass__c(ProjectProduct__c = projectWithFeeder.Id, Feeder__c = feeder.Id, Type__c = 'X'),
            new ProjectShareclass__c(ProjectProduct__c = projectWithFeeder.Id, Type__c = 'A'),
            new ProjectShareclass__c(ProjectProduct__c = projectWithoutFeeder.Id, Type__c = 'A')
        };

        Test.startTest();

        List<ProjectFeederController.FeederLineDTO> dtos = ProjectFeederController.getFeeders(projectWithFeeder.Id);
        List<ProjectFeederController.FeederLineDTO> noFeederDtos = ProjectFeederController.getFeeders(projectWithoutFeeder.Id);
        List<ProjectFeederController.FeederLineDTO> nullDtos = ProjectFeederController.getFeeders(null);

        Test.stopTest();

        System.assertEquals(1, dtos.size(), 'Expected exactly 1 feeder DTO');
        System.assertNotEquals(null, dtos[0].shareclassId, 'shareclassId must be populated');
        System.assert(dtos[0].shareclassName.contains('X'), 'shareclassName should match');
        System.assertNotEquals(null, dtos[0].feederId, 'feederId must be populated');
        System.assertEquals(FEEDER_PRODUCT_NAME, dtos[0].feederName, 'feederName should match ProductName__c');
        System.assertEquals(0, noFeederDtos.size(), 'Expected 0 feeder DTOs for project with no feeders');
        System.assertEquals(0, nullDtos.size(), 'Expected 0 DTOs when passing null projectId');
    }
}