/** ──────────────────────────────────────
 * @description Tests of ProjectFeederFlowAction.getFeeders: feeders of a project's share classes (HTML and plain text), a project
 *                  without feeder, an empty request list, and one response per project in bulk.
 * @author Khadija
 * @covers ProjectFeederFlowAction   100%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
private class ProjectFeederFlowActionTest {

    private static final String FEEDER_PRODUCT_NAME = 'Feeder Product';

    @isTest
    static void test_getFeeders() {
        ProjectProduct__c projectWithFeeder = new ProjectProduct__c(Name = 'Test Project With Feeder', ProjectStartDate__c = Date.today());
        ProjectProduct__c projectWithoutFeeder = new ProjectProduct__c(Name = 'Test Project Without Feeder', ProjectStartDate__c = Date.today());
        insert new List<ProjectProduct__c>{ projectWithFeeder, projectWithoutFeeder };
        Product__c feederProduct = new Product__c(Name = FEEDER_PRODUCT_NAME, ProductName__c = FEEDER_PRODUCT_NAME, Validity__c = true);
        insert feederProduct;

        // A share class with a feeder, and one without (ignored)
        insert new List<ProjectShareclass__c>{ new ProjectShareclass__c(ProjectProduct__c = projectWithFeeder.Id, Type__c = 'X', Feeder__c = feederProduct.Id), new ProjectShareclass__c(ProjectProduct__c = projectWithFeeder.Id, Type__c = 'A') };

        Test.startTest();

        List<ProjectFeederFlowAction.Response> responses = ProjectFeederFlowAction.getFeeders(new List<ProjectFeederFlowAction.Request>{ newRequest(projectWithFeeder.Id), newRequest(projectWithoutFeeder.Id) });
        List<ProjectFeederFlowAction.Response> emptyResponses = ProjectFeederFlowAction.getFeeders(new List<ProjectFeederFlowAction.Request>());

        Test.stopTest();

        System.assertEquals(2, responses.size(), 'One response per project');
        System.assert(responses[0].feedersHtml.contains('X'), 'Should contain share class name');
        System.assert(responses[0].feedersHtml.contains(FEEDER_PRODUCT_NAME), 'Should contain feeder name');
        System.assertEquals('', responses[1].feedersHtml, 'HTML should be empty');
        System.assertEquals('', responses[1].feedersPlain, 'Plain text should be empty');
        System.assertEquals(0, emptyResponses.size(), 'No responses expected');
    }

    private static ProjectFeederFlowAction.Request newRequest(Id projectId) {
        ProjectFeederFlowAction.Request request = new ProjectFeederFlowAction.Request();
        request.projectId = projectId;
        return request;
    }
}