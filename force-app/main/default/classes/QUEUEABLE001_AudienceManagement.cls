public with sharing class QUEUEABLE001_AudienceManagement implements Queueable, Finalizer {
    
    private Id campaignId;
    private List<Id> contactIds;

    public QUEUEABLE001_AudienceManagement(Id campaignId, List<Id> contactIds) {
        this.campaignId = campaignId;
        this.contactIds = contactIds;
    }

    public void execute(QueueableContext context) {
        QUEUEABLE001_AudienceManagement f = new QUEUEABLE001_AudienceManagement(campaignId, contactIds);
        System.attachFinalizer(f);
        List<CampaignMember> memberList = new List<CampaignMember>();
        for(Id id : contactIds) {
            memberList.add(new CampaignMember(CampaignId=campaignId, ContactId=id));
        }
        if(!memberList.isEmpty()) {
            insert memberList;
        }
    }

    //Finalizer method, called if the job ends succesfully or when an error occurs
    public void execute(FinalizerContext ctx) {
        //Retrieves the parent job to get the user who created it and notify him
        String parentJobId = '' + ctx.getAsyncApexJobId();
        AsyncApexJob job = [SELECT Id, CreatedById FROM AsyncApexJob WHERE Id =: parentJobId];

        //If the job succeeded, send a notification with the link to the campaign
        //If an error occurred, send a notification with an error message
        if(String.valueOf(ctx.getResult()) == 'SUCCESS') {
            String title = 'Your task is completed.';
            String body = String.valueOf(contactIds.size()) + ' contacts have been added to your campaign. View it here.';
            sendNotification(title, body, job.CreatedById);
        } else if(String.valueOf(ctx.getResult()) == 'UNHANDLED_EXCEPTION') {
            System.Exception error = ctx.getException();
            String title = 'An error has occured.';
            String body = '';
            //User friendly error message when a contact already is a campaign member of the selected campaign
            if(error.getMessage().contains('DUPLICATE_VALUE')) {
                body = 'One of the contact was already in the campaign. Please remove it and retry.';
            } else {
                title = 'An unexpected error has occured';
                body = 'Please contact your administrator. ' + error.getMessage();
            }
            sendNotification(title, body, job.CreatedById);
        }
    }

    //Sends a salesforce notification to the user
    private void sendNotification(String title, String body, Id userId) {
        CustomNotificationType notifType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'AMAddToCampaign'];
        Messaging.CustomNotification notif = new Messaging.CustomNotification();
        notif.setTitle(title);
        notif.setBody(body);
        notif.setTargetId(campaignId);
        notif.setNotificationTypeId(notifType.Id);
        Set<String> recipients = new Set<String>();
        recipients.add(userId);
        notif.send(recipients);
    }
}