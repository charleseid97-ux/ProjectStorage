public class SM026_DeleteWebsiteLeadsSchedulable implements Schedulable {
    List<Lead> leadToBeDeleted;

    public void execute(SchedulableContext sc) {
        System.enqueueJob(new SM026_DeleteWebsiteLeadsAsync(leadToBeDeleted, leadToBeDeleted.size(), 1));
        // Abort the job once the job is queued
        System.abortJob(sc.getTriggerId());
    }

    public SM026_DeleteWebsiteLeadsSchedulable(List<Lead> listLeads) {
        if (leadToBeDeleted == null) {
            leadToBeDeleted = listLeads;
        }
    }
}