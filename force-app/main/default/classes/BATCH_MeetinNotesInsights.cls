// Database.executebatch(new BATCH_MeetinNotesInsights('q'),100);
public class BATCH_MeetinNotesInsights implements Database.Batchable<SObject> {
    String query;

    public  BATCH_MeetinNotesInsights(String aQuery) {
        query = aQuery;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        Database.QueryLocator qloc = Database.getQueryLocator(query);
        return qloc;
    }

    public void execute(Database.BatchableContext BC, List<Meeting_Note__c> mns) {
        CTL_MeetingNotes.getJSONMeetingNote(mns);

    }

    public void finish(Database.BatchableContext param1) {

        System.debug('DONE');

    }

}