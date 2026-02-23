/**
 * @description       : Controller for NewTask LWC - create Tasks linked to Meeting Note
 * @author            : 
 * @last modified on  : 18-02-2026
**/
public without sharing class newTaskCTRL {

    @AuraEnabled
    public static void createTasks(List<Task> tasksToInsert) {
        if (tasksToInsert == null || tasksToInsert.isEmpty()) return;

        // Basic hardening (optional but recommended)
        for (Task t : tasksToInsert) {
            if (String.isBlank(t.Subject)) t.Subject = 'Follow Up - Event';
             t.type = 'To Do Action';
        }

        insert tasksToInsert;
    }

    @AuraEnabled(cacheable=true)
    public static Id getMeetingNoteId(Id eventId) {
        if (eventId == null) return null;
        return [SELECT Meeting_Note__c FROM Event WHERE Id = :eventId LIMIT 1].Meeting_Note__c;
    }
}