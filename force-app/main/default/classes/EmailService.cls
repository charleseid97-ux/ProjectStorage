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

    private static final String DEFAULT_ORG_WIDE_ADDRESS = Label.EmailService_DefaultOrgWideAddress;

    public static void sendTemplateEmail(String templateDeveloperName, Id whatId, Set<Id> recipientUserIds) {
        sendTemplateEmail(templateDeveloperName, whatId, recipientUserIds, new List<String>());
    }

    // Overload: also delivers to raw email addresses that aren't tied to a Salesforce User (e.g. a shared ops mailbox).
    public static void sendTemplateEmail(String templateDeveloperName, Id whatId, Set<Id> recipientUserIds, List<String> additionalEmailAddresses) {
        Boolean hasUserRecipients = recipientUserIds != null && !recipientUserIds.isEmpty();
        Boolean hasRawRecipients = additionalEmailAddresses != null && !additionalEmailAddresses.isEmpty();
        if (!hasUserRecipients && !hasRawRecipients) return;

        Id templateId = resolveTemplateId(templateDeveloperName);
        if (templateId == null) return;

        Id orgWideEmailAddressId = resolveOrgWideEmailAddressId();

        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        if (hasUserRecipients) {
            emailList.addAll(buildUserEmails(templateId, whatId, recipientUserIds, orgWideEmailAddressId));
        }
        if (hasRawRecipients) {
            emailList.addAll(buildRawAddressEmails(templateId, whatId, additionalEmailAddresses, orgWideEmailAddressId));
        }

        if (!emailList.isEmpty()) {
            Messaging.sendEmail(emailList, false);
        }
    }

    public static Set<Id> resolveRecipientIds(Set<String> recipientTypeValues, Set<Id> currentApproverIds, Set<Id> nextApproverIds, Id submittedById, Id targetRecordId, String objectApiName) {
        Set<Id> result = new Set<Id>();
        if (recipientTypeValues == null || recipientTypeValues.isEmpty()) return result;

        for (String recipientType : recipientTypeValues) {
            if (recipientType == 'CurrentStepApprovers' && currentApproverIds != null) {
                result.addAll(expandApproverIds(currentApproverIds));
            } 
            else if (recipientType == 'NextStepApprovers' && nextApproverIds != null) {
                result.addAll(expandApproverIds(nextApproverIds));
            } 
            else if (recipientType == 'Submitter' && submittedById != null) {
                result.add(submittedById);
            } 
            else if (recipientType == 'RecordOwner' && targetRecordId != null && String.isNotBlank(objectApiName)) {
                try {
                    SObject record = Database.query('SELECT OwnerId FROM ' + objectApiName + ' WHERE Id = :targetRecordId LIMIT 1');
                    result.add((Id) record.get('OwnerId'));
                } catch (Exception e) {
                    OperationLogService.error(targetRecordId, 'EmailServiceResolveRecordOwner', 'Failed to resolve the owner of ' + objectApiName + ' while building alert recipients.', e);
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

    private static Id resolveTemplateId(String templateDeveloperName) {
        List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate WHERE DeveloperName = :templateDeveloperName LIMIT 1];
        return templates.isEmpty() ? null : templates[0].Id;
    }

    private static Id resolveOrgWideEmailAddressId() {
        List<OrgWideEmailAddress> owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = :DEFAULT_ORG_WIDE_ADDRESS];
        return owea.isEmpty() ? null : owea[0].Id;
    }

    private static List<Messaging.SingleEmailMessage> buildUserEmails(Id templateId, Id whatId, Set<Id> recipientUserIds, Id orgWideEmailAddressId) {
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();

        Map<Id, String> userEmails = new Map<Id, String>();
        for (User u : [SELECT Id, Email FROM User WHERE Id IN :recipientUserIds AND IsActive = true]) {
            if (String.isNotBlank(u.Email)) {
                userEmails.put(u.Id, u.Email);
            }
        }

        for (Id userId : recipientUserIds) {
            if (String.isBlank(userEmails.get(userId))) continue;

            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, userId, whatId);

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(userId);
            mail.setSubject(rendered.getSubject());
            mail.setHtmlBody(rendered.getHtmlBody());
            mail.setPlainTextBody(rendered.getPlainTextBody());
            mail.setSaveAsActivity(false);
            if (orgWideEmailAddressId != null) {
                mail.setOrgWideEmailAddressId(orgWideEmailAddressId);
            }
            emailList.add(mail);
        }

        return emailList;
    }

    // Raw addresses have no Salesforce User Id, so the template is rendered once without a "who" and reused for each address.
    private static List<Messaging.SingleEmailMessage> buildRawAddressEmails(Id templateId, Id whatId, List<String> emailAddresses, Id orgWideEmailAddressId) {
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, null, whatId);

        for (String address : emailAddresses) {
            if (String.isBlank(address)) continue;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ address.trim() });
            mail.setSubject(rendered.getSubject());
            mail.setHtmlBody(rendered.getHtmlBody());
            mail.setPlainTextBody(rendered.getPlainTextBody());
            mail.setSaveAsActivity(false);
            if (orgWideEmailAddressId != null) {
                mail.setOrgWideEmailAddressId(orgWideEmailAddressId);
            }
            emailList.add(mail);
        }

        return emailList;
    }
}