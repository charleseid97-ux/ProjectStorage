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

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        for (Id userId : recipientUserIds) {
            String email = userEmails.get(userId);
            if (String.isBlank(email)) {
                continue;
            }
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setTemplateId(templateId);
            msg.setWhatId(whatId);
            msg.setTargetObjectId(userId);
            msg.setSaveAsActivity(false);
            messages.add(msg);
        }

        if (!messages.isEmpty()) {
            Messaging.sendEmail(messages, false);
        }
    }

    public static Set<Id> resolveRecipientIds(
        Set<String> recipientTypeValues,
        Set<Id> currentApproverIds,
        Set<Id> nextApproverIds,
        Id submittedById,
        Id targetRecordId,
        String objectApiName
    ) {
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
            Set<String> queueNames = new Set<String>(additionalQueues.split(','));
            for (String name : queueNames) {
                queueNames.add(name.trim());
            }
            Map<String, Set<Id>> queueMembers = QueueMemberService.getQueueMemberIds(queueNames);
            for (Set<Id> ids : queueMembers.values()) {
                result.addAll(ids);
            }
        }

        if (String.isNotBlank(additionalUsers)) {
            Set<String> usernames = new Set<String>();
            for (String name : additionalUsers.split(',')) {
                usernames.add(name.trim());
            }
            for (User u : [SELECT Id FROM User WHERE Username IN :usernames AND IsActive = true]) {
                result.add(u.Id);
            }
        }

        return result;
    }

    private static Set<Id> expandApproverIds(Set<Id> approverIds) {
        Set<Id> userIds = new Set<Id>();
        Set<Id> queueIds = new Set<Id>();
        for (Id approverId : approverIds) {
            String prefix = String.valueOf(approverId).left(3);
            if (prefix == '005') {
                userIds.add(approverId);
            } else if (prefix == '00G') {
                queueIds.add(approverId);
            }
        }
        if (!queueIds.isEmpty()) {
            Set<String> queueDevNames = new Set<String>();
            for (Group q : [SELECT DeveloperName FROM Group WHERE Id IN :queueIds]) {
                queueDevNames.add(q.DeveloperName);
            }
            Map<String, Set<Id>> memberMap = QueueMemberService.getQueueMemberIds(queueDevNames);
            for (Set<Id> ids : memberMap.values()) {
                userIds.addAll(ids);
            }
        }
        return userIds;
    }
}
