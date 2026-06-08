/** ──────────────────────────────────────
 * @description Utility service for sending template-based email notifications
 *              as part of the custom approval process.
 *              Resolves recipient IDs from approver sets, queue memberships,
 *              submitted-by references, record owners, and additional addressee lists.
 * @author Charles EID
 * @testClass EmailServiceTest
 * @coverage 74%   [20-05-26]
────────────────────────────────────── */
public without sharing class EmailService {

    public static void sendTemplateEmail(String templateDeveloperName, Id whatId, Set<Id> recipientUserIds) {
        if (recipientUserIds == null || recipientUserIds.isEmpty()) {
            return;
        }

        List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate WHERE DeveloperName = :templateDeveloperName LIMIT 1];
        if (templates.isEmpty()) {
            System.debug('EmailService: template not found: ' + templateDeveloperName);
            return;
        }
        Id templateId = templates[0].Id;

        Map<Id, String> userEmails = new Map<Id, String>();
        for (User u : [SELECT Id, Email FROM User WHERE Id IN :recipientUserIds AND IsActive = true]) {
            if (String.isNotBlank(u.Email)) {
                userEmails.put(u.Id, u.Email);
            }
        }

        OrgWideEmailAddress[] owea = [select Id from OrgWideEmailAddress where Address = 'noreplysalesforce@carmignac.com'];
        
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        for (Id userId : recipientUserIds) {
            String email = userEmails.get(userId);
            if (String.isBlank(email)) {
                continue;
            }
            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, userId, whatId);

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(userId);
            mail.setSubject(rendered.getSubject());
            mail.setHtmlBody(rendered.getHtmlBody());
            mail.setPlainTextBody(rendered.getPlainTextBody());
            mail.setSaveAsActivity(false);
            if (owea.size() > 0) {
                mail.setOrgWideEmailAddressId(owea.get(0).Id);
            }
            emailList.add(mail);
        }

        if (!emailList.isEmpty()) {
            Messaging.sendEmail(emailList, false);
        }
    }

    public static Set<Id> resolveRecipientIds(Set<String> recipientTypeValues, Set<Id> currentApproverIds, Set<Id> nextApproverIds, Id submittedById, Id targetRecordId, String objectApiName) {
        Set<Id> result = new Set<Id>();
        if (recipientTypeValues == null || recipientTypeValues.isEmpty()) {
            return result;
        }

        for (String recipientType : recipientTypeValues) {
            if (recipientType == 'CurrentStepApprovers' && currentApproverIds != null) {
                result.addAll(expandApproverIds(currentApproverIds));
            } else if (recipientType == 'NextStepApprovers' && nextApproverIds != null) {
                result.addAll(expandApproverIds(nextApproverIds));
            } else if (recipientType == 'Submitter' && submittedById != null) {
                result.add(submittedById);
            } else if (recipientType == 'RecordOwner' && targetRecordId != null && String.isNotBlank(objectApiName)) {
                try {
                    SObject record = Database.query('SELECT OwnerId FROM ' + objectApiName + ' WHERE Id = :targetRecordId LIMIT 1');
                    result.add((Id) record.get('OwnerId'));
                } catch (Exception e) {
                    System.debug('EmailService.resolveRecipientIds RecordOwner error: ' + e.getMessage());
                }
            }
        }
        return result;
    }

    public static Set<Id> resolveAdditionalRecipientIds(String additionalQueues, String additionalUsers) {
        Set<Id> result = new Set<Id>();

        if (String.isNotBlank(additionalQueues)) {
            Set<String> queueNames = new Set<String>();
            for (String name : additionalQueues.split(',')) queueNames.add(name.trim());

            Set<Id> queueIds = new Set<Id>();
            for (Group g : [SELECT Id FROM Group WHERE DeveloperName IN :queueNames AND Type = 'Queue']) {
                queueIds.add(g.Id);
            }
            Map<Id, List<Id>> memberMap = QueueMemberService.resolveMembers(queueIds);
            for (List<Id> ids : memberMap.values()) result.addAll(ids);
        }

        if (String.isNotBlank(additionalUsers)) {
            Set<String> usernames = new Set<String>();
            for (String name : additionalUsers.split(',')) usernames.add(name.trim());
            for (User u : [SELECT Id FROM User WHERE Username IN :usernames AND IsActive = true]) {
                result.add(u.Id);
            }
        }

        return result;
    }

    private static Set<Id> expandApproverIds(Set<Id> approverIds) {
        Map<Id, List<Id>> resolved = QueueMemberService.resolveMembers(approverIds);
        Set<Id> userIds = new Set<Id>();
        for (List<Id> members : resolved.values()) userIds.addAll(members);
        return userIds;
    }
}
