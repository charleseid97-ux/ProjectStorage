@IsTest
private class ProjectFeederFlowActionTest {

    // Constant to avoid duplicated literal (fix Sonar CODE_SMELL)
    private static final String FEEDER_PRODUCT_NAME = 'Feeder Product';

    @TestSetup
    static void setupData() {

        // Create Project Products
        ProjectProduct__c projectWithFeeder = new ProjectProduct__c(
            Name = 'Test Project With Feeder'
        );
        insert projectWithFeeder;

        ProjectProduct__c projectWithoutFeeder = new ProjectProduct__c(
            Name = 'Test Project Without Feeder'
        );
        insert projectWithoutFeeder;

        // Create Feeder product (lookup target)
        Product__c feederProduct = new Product__c(
            Name = FEEDER_PRODUCT_NAME,
            ProductName__c = FEEDER_PRODUCT_NAME,
            Validity__c = true
        );
        insert feederProduct;

        // Create ProjectShareclass WITH feeder
        ProjectShareclass__c pscWithFeeder = new ProjectShareclass__c(
            ProjectProduct__c = projectWithFeeder.Id,
            Type__c = 'X',
            Feeder__c = feederProduct.Id
        );
        insert pscWithFeeder;

        // Create ProjectShareclass WITHOUT feeder (should be ignored)
        ProjectShareclass__c pscWithoutFeeder = new ProjectShareclass__c(
            ProjectProduct__c = projectWithFeeder.Id,
            Type__c = 'A'
        );
        insert pscWithoutFeeder;
    }

    @IsTest
    static void testWithFeeder() {

        ProjectProduct__c project = [
            SELECT Id FROM ProjectProduct__c
            WHERE Name = 'Test Project With Feeder'
            LIMIT 1
        ];

        ProjectFeederFlowAction.Request req = new ProjectFeederFlowAction.Request();
        req.projectId = project.Id;

        Test.startTest();
        List<ProjectFeederFlowAction.Response> responses =
            ProjectFeederFlowAction.getFeeders(
                new List<ProjectFeederFlowAction.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response expected');

        ProjectFeederFlowAction.Response res = responses[0];

        System.assertNotEquals('', res.feedersHtml, 'HTML should not be empty');
        System.assert(res.feedersHtml.contains('X'), 'Should contain share class name');
        System.assert(res.feedersHtml.contains(FEEDER_PRODUCT_NAME), 'Should contain feeder name');

    }

    @IsTest
    static void testWithoutFeeder() {

        ProjectProduct__c project = [
            SELECT Id FROM ProjectProduct__c
            WHERE Name = 'Test Project Without Feeder'
            LIMIT 1
        ];

        ProjectFeederFlowAction.Request req = new ProjectFeederFlowAction.Request();
        req.projectId = project.Id;

        Test.startTest();
        List<ProjectFeederFlowAction.Response> responses =
            ProjectFeederFlowAction.getFeeders(
                new List<ProjectFeederFlowAction.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response expected');

        ProjectFeederFlowAction.Response res = responses[0];

        System.assertEquals('', res.feedersHtml, 'HTML should be empty');
        System.assertEquals('', res.feedersPlain, 'Plain text should be empty');
    }

    @IsTest
    static void testEmptyRequestList() {

        Test.startTest();
        List<ProjectFeederFlowAction.Response> responses =
            ProjectFeederFlowAction.getFeeders(new List<ProjectFeederFlowAction.Request>());
        Test.stopTest();

        System.assertEquals(0, responses.size(), 'No responses expected');
    }

    @IsTest
    static void testBulkMultipleProjects() {

        List<ProjectProduct__c> projects = [
            SELECT Id FROM ProjectProduct__c
        ];

        List<ProjectFeederFlowAction.Request> requests =
            new List<ProjectFeederFlowAction.Request>();

        for (ProjectProduct__c p : projects) {
            ProjectFeederFlowAction.Request r = new ProjectFeederFlowAction.Request();
            r.projectId = p.Id;
            requests.add(r);
        }

        Test.startTest();
        List<ProjectFeederFlowAction.Response> responses =
            ProjectFeederFlowAction.getFeeders(requests);
        Test.stopTest();

        System.assertEquals(projects.size(), responses.size(),
            'Should return one response per project');
    }
}