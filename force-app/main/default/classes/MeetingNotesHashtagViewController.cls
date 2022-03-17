public class MeetingNotesHashtagViewController {
	@AuraEnabled
    public static String getNotes(String notesId) {
        return [SELECT Id, Note__c FROM Meeting_Note__c WHERE Id =: notesId].Note__c;
    }
}