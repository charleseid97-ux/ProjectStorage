/** ──────────────────────────────────────
 * @description Test class for CustomAlertScheduler.
 *              Covers scheduler instantiation, and all frequency evaluation
 *                  branches (Daily, Weekly, Biweekly, Monthly, unknown).
 * @author Charles EID
 * @coverage 100%  [11-05-26]
 ────────────────────────────────────── */
@isTest
private class CustomAlertSchedulerTest {

    @isTest
    static void testSchedulerExecutes() {
        Test.startTest();
        String cronExpr = '0 0 6 * * ?';
        System.schedule('CustomAlertScheduler Test', cronExpr, new CustomAlertScheduler());
        Test.stopTest();
        // Verifies the scheduler can be instantiated and scheduled without errors
    }

    @isTest
    static void testFrequencyDaily() {
        // Daily should always dispatch regardless of day
        System.assertEquals(true,  CustomAlertScheduler.shouldDispatch('Daily', 0, 0));
        System.assertEquals(true,  CustomAlertScheduler.shouldDispatch('Daily', 1, 5));
        System.assertEquals(true,  CustomAlertScheduler.shouldDispatch('Daily', 6, 10));
    }

    @isTest
    static void testFrequencyWeekly() {
        // Weekly only dispatches on Monday (dayOfWeek == 1)
        System.assertEquals(true,  CustomAlertScheduler.shouldDispatch('Weekly', 1, 0));
        System.assertEquals(false, CustomAlertScheduler.shouldDispatch('Weekly', 0, 0)); // Sunday
        System.assertEquals(false, CustomAlertScheduler.shouldDispatch('Weekly', 2, 0)); // Tuesday
        System.assertEquals(false, CustomAlertScheduler.shouldDispatch('Weekly', 5, 0)); // Friday
    }

    @isTest
    static void testFrequencyBiweekly() {
        // Biweekly: Monday of even week numbers
        System.assertEquals(true,  CustomAlertScheduler.shouldDispatch('Biweekly', 1, 0));  // Monday, week 0
        System.assertEquals(true,  CustomAlertScheduler.shouldDispatch('Biweekly', 1, 2));  // Monday, week 2
        System.assertEquals(false, CustomAlertScheduler.shouldDispatch('Biweekly', 1, 1));  // Monday, week 1 (odd)
        System.assertEquals(false, CustomAlertScheduler.shouldDispatch('Biweekly', 2, 0));  // Tuesday, even week
    }

    @isTest
    static void testFrequencyMonthly() {
        // Monthly only dispatches on day 1 — we check today's actual date
        Boolean isFirstOfMonth = Date.today().day() == 1;
        System.assertEquals(isFirstOfMonth, CustomAlertScheduler.shouldDispatch('Monthly', 0, 0));
    }

    @isTest
    static void testUnknownFrequencyReturnsFalse() {
        System.assertEquals(false, CustomAlertScheduler.shouldDispatch('Quarterly', 1, 0));
        System.assertEquals(false, CustomAlertScheduler.shouldDispatch(null, 1, 0));
    }
}
