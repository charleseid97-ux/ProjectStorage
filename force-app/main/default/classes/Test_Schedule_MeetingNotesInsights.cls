@isTest
private class Test_Schedule_MeetingNotesInsights {
    
    @isTest
    static void testSchedulingWorks() {
        Test.startTest();
        String cron = '0 0 12 * * ?';
        String jobId = System.schedule('TestSchedule', cron, new Schedule_MeetingNotesInsights());
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }
}