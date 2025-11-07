global class Schedule_MeetingNotesInsights implements Schedulable {
    global void execute(SchedulableContext sc) {
        String query = 'SELECT Id FROM Meeting_Note__c WHERE SalesPresentation__c =TRUE AND ID Not In (SELECT Meeting_Note__c from Meeting_Note_Insight__c) ';
        BATCH_MeetinNotesInsights b = new BATCH_MeetinNotesInsights(query);
        Database.executeBatch(b, 1);
    }
}