/** 
LastUpdate : 07/05/2026
By: Ted Bamezon
What: CreatedDate = TODAY + Schudle every day 8PM
 **/


global class Schedule_MeetingNotesInsights implements Schedulable {
    global void execute(SchedulableContext sc) {
        String query = 'SELECT Id FROM Meeting_Note__c WHERE SalesPresentation__c =TRUE AND ID Not In (SELECT Meeting_Note__c from Meeting_Note_Insight__c) AND CreatedDate = TODAY ';
        BATCH_MeetinNotesInsights b = new BATCH_MeetinNotesInsights(query);
        Database.executeBatch(b, 20);
    }
}