/**
 * Created by Saad LOZZI on 25/04/2022.
 */

@IsTest
private class TSP_Test
{
    @IsTest
    static void testApiEventBehavior()
    {
        ApiEvent testEvent = new ApiEvent();
        testEvent.QueriedEntities = 'Account,Lead';
        testEvent.RowsProcessed = 2001;
        testEvent.UserId = UserInfo.getUserId();

        TSP_Blocker blockingEvent = new TSP_Blocker();
        System.assert(blockingEvent.evaluate(testEvent));

        TSP_Notifier notificationEvent = new TSP_Notifier();
        System.assert(notificationEvent.evaluate(testEvent));
    }

    @IsTest
    static void testApiEventLowNumberBehavior()
    {
        ApiEvent testEvent = new ApiEvent();
        testEvent.QueriedEntities = 'Account,Lead';
        testEvent.RowsProcessed = 1;
        testEvent.UserId = UserInfo.getUserId();

        TSP_Blocker blockingEvent = new TSP_Blocker();
        System.assert(!blockingEvent.evaluate(testEvent));

        TSP_Notifier notificationEvent = new TSP_Notifier();
        System.assert(!notificationEvent.evaluate(testEvent));

        TSP_Handler handler = new TSP_Handler();
        handler.getExcludedUsers('');
    }


    @IsTest
    static void testReportEventBehavior()
    {
        ReportEvent testEvent = new ReportEvent();
        testEvent.QueriedEntities = 'Account,Lead';
        testEvent.RowsProcessed = 2001;
        testEvent.Operation = 'ReportExported';
        testEvent.UserId = UserInfo.getUserId();

        TSP_Manager  event = new TSP_Manager();
        System.assert(event.evaluate(testEvent));
    }

    @IsTest
    static void testOtherEventBehavior()
    {
        TSP_Manager event = new TSP_Manager();
        System.assert(!event.evaluate(new LoginEvent()));
    }

    @IsTest
    static void testUnFoundObjectBehavior()
    {
        ApiEvent testEvent = new ApiEvent();
        testEvent.QueriedEntities = 'Order';
        testEvent.RowsProcessed = 2001;
        testEvent.UserId = UserInfo.getUserId();

        TSP_Manager  event = new TSP_Manager();
        System.assert(!event.evaluate(testEvent));
    }
}