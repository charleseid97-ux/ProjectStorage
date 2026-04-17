/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 12-05-2023
 * @last modified by  : SILA Nicolas
**/
public with sharing class BATCH_AudienceManagement implements Database.Batchable<sObject> {

    private Id campaignId;
    private List<Id> contactIds;
    private Datetime startTime;
    private Datetime endTime;

    public BATCH_AudienceManagement(Id campaignId, List<Id> contactIds,DateTime startTime) {
        this.campaignId = campaignId;
        this.contactIds = contactIds;
        this.startTime = startTime;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        String query = 'SELECT Id FROM Contact WHERE Id in :contactIds';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext context, List<Contact> scope) {
        List<CampaignMember> memberList = new List<CampaignMember>();

        for (Contact cont : scope) {
            memberList.add(new CampaignMember(CampaignId = campaignId, ContactId = cont.Id));
        }
        if (!memberList.isEmpty()) {
            // Insert the records and handle any exceptions
            System.debug('memberList.size() => execution' + memberList.size());
            Database.SaveResult[] saveResults = Database.insert(memberList, false);

            // Check for failed inserts
            List<Interface_Log__c> failedRecords = new List<Interface_Log__c>();
            for (Integer i = 0; i < saveResults.size(); i++) {
                if (!saveResults[i].isSuccess()) {
                    // Log or handle the specific error
                    System.debug('Error inserting CampaignMember for ContactId ' + memberList[i].ContactId + ': ' +
                        saveResults[i].getErrors()[0].getMessage());

                    // if (saveResults[i].getErrors()[0].getStatusCode() != StatusCode.DUPLICATE_VALUE || Test.isRunningTest()) {
                        // Handle duplicate error differently, if needed
                        // Add the failed record to the list
                        failedRecords.add(new Interface_Log__c(To_be_deleted__c = true, Contact__c = memberList[i].ContactId, Data__c = saveResults[i].getErrors()[0].getMessage(), Date_Log__c = System.now(), Interface_Name__c = 'Audience Management: BATCH_AudienceManagement - '+saveResults[i].getErrors()[0].getStatusCode()));
                    // }
                }
            }

            insert failedRecords;
        }
    }

    public void finish(Database.BatchableContext context) {
        endTime = Datetime.now();
        System.debug('Batch processing starts at '+startTime +'');
        System.debug('Batch processing ends at '+endTime +'');

        Long durationInSec = (endTime.getTime() - startTime.getTime())/ 1000;
        System.debug('Batch processing took '+durationInSec +' secs');
        String title = 'Your task is completed.';
        String body = 'The contacts have been added to your campaign. View it here.';
        sendNotification(title, body, UserInfo.getUserId());
        sendErrorEmailWithAttachment();
    }
    

    // Sends a salesforce notification to the user
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

    // Sends an email with the failed records and a CSV file attachment
    private void sendErrorEmailWithAttachment() {

        // Create a CSV file content
        String csvFileContent = 'Contact ID,Contact Name, Error\n';
        List <Interface_Log__c> failedContactsLogs = [SELECT Contact__c,Contact__r.Name,Data__c 
                                                        FROM Interface_Log__c 
                                                        WHERE OwnerId =: UserInfo.getUserId() 
                                                        AND Interface_Name__c LIKE '%Audience Management: BATCH_AudienceManagement%' And (NOT Interface_Name__c LIKE '%Audience Management: BATCH_AudienceManagement - DUPLICATE_VALUE%') ] ;
        List <Interface_Log__c> duplicateContactsLogs = [SELECT Contact__c,Contact__r.Name,Data__c 
                                                        FROM Interface_Log__c 
                                                        WHERE OwnerId =: UserInfo.getUserId() 
                                                        AND Interface_Name__c Like '%Audience Management: BATCH_AudienceManagement - DUPLICATE_VALUE%'] ;
          
                                                        
        Integer numberOfFailedContacts = failedContactsLogs.size();
        Integer numberOfduplicateContacts = duplicateContactsLogs.size();
        Integer numberOfAllContacts = contactIds.size();
        // Use the Messaging.SingleEmailMessage class to send an email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setSubject('Campaign Member Insertions');
        email.setToAddresses(new String[] { UserInfo.getUserEmail() }); // Replace with the recipient's email address
        String emailBody =  'Here is the update on your Audience Management:\n\n';
        if (numberOfAllContacts - numberOfFailedContacts - numberOfduplicateContacts> 0) {
            emailBody += 'Successful Additions:\n' +
            '    - ' + (numberOfAllContacts - numberOfFailedContacts - numberOfduplicateContacts) + ' contacts have been added to your campaign successfully.\n\n' ;
        }
                            
        
        if (numberOfduplicateContacts > 0) {
            emailBody += 'Duplicate Contacts:\n' +
            '    - ' + (numberOfduplicateContacts == numberOfAllContacts? 'All selected': + String.valueOf(numberOfduplicateContacts) )+' contacts have already been added to this campaign.\n\n' ;
           delete duplicateContactsLogs;
        }

        if (numberOfFailedContacts > 0) {
            for (Interface_Log__c failedContact : failedContactsLogs) {
                csvFileContent += failedContact.Contact__c+','+failedContact.Contact__r.Name+','+failedContact.Data__c + '\n';
            }
    
            // Create a ContentVersion record
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = 'Failed_Contacts.csv';
            contentVersion.PathOnClient = 'Failed_Contacts.csv';
            contentVersion.VersionData = Blob.valueOf(csvFileContent);
            insert contentVersion;
            String varContentDocumentId = [SELECT ID,ContentDocumentId FROM ContentVersion WHERE Id =: contentVersion.Id][0].ContentDocumentId;

            // Create an email with the attached file
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(contentVersion.Title);
            attachment.setBody(contentVersion.VersionData);
            emailBody += 'Encountered Issues:\n' +
            '    - ' + numberOfFailedContacts + ' contacts cannot be added due to errors. Please refer to the attached file for detailed information.\n\n' ;
           
            email.setFileAttachments(new Messaging.EmailFileAttachment[]{attachment});

            delete failedContactsLogs;
            delete [SELECT ID FROM ContentDocument WHERE Id =: varContentDocumentId];
        }
        emailBody += 'Thank you for your understanding.\n\nRegards.' ;
        email.setPlainTextBody(emailBody);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        
    }
}