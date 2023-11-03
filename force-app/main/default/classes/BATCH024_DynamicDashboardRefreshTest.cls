@isTest
public class BATCH024_DynamicDashboardRefreshTest {
    @isTest(SeeAllData=true)
    static void testBatch() {
        SingleRequestMock fakeDashboardRequest = new SingleRequestMock(201, 'Created', null, null);
        Test.setMock(HttpCallOutMock.class, fakeDashboardRequest);
        BATCH024_DynamicDashboardRefresh batch = new BATCH024_DynamicDashboardRefresh();

        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();
    }
}