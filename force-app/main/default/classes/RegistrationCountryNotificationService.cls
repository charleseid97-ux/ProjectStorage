public without sharing class RegistrationCountryNotificationService {
    // Uses the exact Public Group labels supplied by the business specification.
    private static final Set<String> TEAM_GROUP_NAMES = new Set<String>{
        'Product Strategy',
        'Legal',
        'DCR',
        'Fund Marketing',
        'Digital Marketing'
    };

    // Limits each outbound message to a safe number of recipient addresses.
    private static final Integer RECIPIENTS_PER_EMAIL = 100;

    // Allows tests to bypass Public Group configuration and use known recipients.
    @TestVisible private static Set<String> recipientEmailsOverride;

    // Identifies an incomplete recipient or email configuration.
    public class NotificationException extends Exception {
    }

    // Sends the successful API submission details to all configured team members.
    public static void sendSuccessEmail(
        RegistrationCountryApiService.Request request,
        RegistrationCountryApiService.Response response
    ) {
        Set<String> recipientEmails = resolveTeamRecipientEmails();
        String subject = '[Registration Countries] Request submitted - ' + request.shareClassName;

        // Includes the component comment and every country selection in the message.
        String body =
            'The Registration Country request was submitted successfully to the external service.\n\n' +
            buildRequestDetails(request) + '\n\n' +
            'API status: ' + String.valueOf(response.statusCode) + '\n' +
            'External reference: ' + safeText(response.externalId, 'Not provided');
        sendEmails(recipientEmails, subject, body);
    }

    // Sends an API failure notification only to the user who submitted the request.
    public static void sendFailureEmail(
        RegistrationCountryApiService.Request request,
        RegistrationCountryApiService.Response response,
        String failureReason
    ) {
        User submittingUser = [
            SELECT Id, Name, Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (String.isBlank(submittingUser.Email)) {
            throw new NotificationException('The submitting user does not have an email address.');
        }

        // Keeps the failure message useful without exposing tokens or response payloads.
        String statusText = response == null || response.statusCode == null
            ? 'Not available'
            : String.valueOf(response.statusCode);
        String subject = '[Registration Countries] Request submission failed - ' + request.shareClassName;
        String body =
            'A problem occurred while submitting your Registration Country request.\n\n' +
            buildRequestDetails(request) + '\n\n' +
            'API status: ' + statusText + '\n' +
            'Problem: ' + safeText(failureReason, 'External service submission failed.') + '\n\n' +
            'Please contact support if the problem continues.';
        sendEmails(new Set<String>{ submittingUser.Email }, subject, body);
    }

    // Resolves active users from the five exact Public Group names.
    @TestVisible
    private static Set<String> resolveTeamRecipientEmails() {
        if (Test.isRunningTest() && recipientEmailsOverride != null) {
            return new Set<String>(recipientEmailsOverride);
        }

        List<Group> teamGroups = [
            SELECT Id, Name
            FROM Group
            WHERE Type = 'Regular'
            AND Name IN :TEAM_GROUP_NAMES
        ];
        Set<String> foundGroupNames = new Set<String>();
        Set<Id> rootGroupIds = new Set<Id>();

        // Collects every configured team group and detects missing configuration.
        for (Group teamGroup : teamGroups) {
            foundGroupNames.add(teamGroup.Name);
            rootGroupIds.add(teamGroup.Id);
        }

        Set<String> missingGroupNames = new Set<String>();
        missingGroupNames.addAll(TEAM_GROUP_NAMES);
        missingGroupNames.removeAll(foundGroupNames);
        if (!missingGroupNames.isEmpty()) {
            List<String> sortedMissingNames = new List<String>(missingGroupNames);
            sortedMissingNames.sort();
            throw new NotificationException(
                'Missing Registration Country Public Groups: ' +
                String.join(sortedMissingNames, ', ') + '.'
            );
        }

        Set<Id> userIds = resolveUserIds(rootGroupIds);
        Set<String> recipientEmails = new Set<String>();

        // Keeps only active users with a usable email address.
        for (User recipient : [
            SELECT Id, Email
            FROM User
            WHERE Id IN :userIds
            AND IsActive = true
            AND Email != null
        ]) {
            recipientEmails.add(recipient.Email.trim().toLowerCase());
        }

        if (recipientEmails.isEmpty()) {
            throw new NotificationException(
                'No active email recipient was found in the Registration Country Public Groups.'
            );
        }

        return recipientEmails;
    }

    // Expands direct users and nested Public Groups without processing a group twice.
    private static Set<Id> resolveUserIds(Set<Id> rootGroupIds) {
        Set<Id> userIds = new Set<Id>();
        Set<Id> processedGroupIds = new Set<Id>();
        Set<Id> pendingGroupIds = new Set<Id>();
        pendingGroupIds.addAll(rootGroupIds);

        while (!pendingGroupIds.isEmpty()) {
            Set<Id> currentGroupIds = new Set<Id>();
            currentGroupIds.addAll(pendingGroupIds);
            pendingGroupIds.clear();
            processedGroupIds.addAll(currentGroupIds);

            // Adds users directly and queues nested groups for the next iteration.
            for (GroupMember member : [
                SELECT UserOrGroupId
                FROM GroupMember
                WHERE GroupId IN :currentGroupIds
            ]) {
                Schema.SObjectType memberType = member.UserOrGroupId.getSObjectType();
                if (memberType == User.SObjectType) {
                    userIds.add(member.UserOrGroupId);
                } else if (
                    memberType == Group.SObjectType &&
                    !processedGroupIds.contains(member.UserOrGroupId)
                ) {
                    pendingGroupIds.add(member.UserOrGroupId);
                }
            }
        }

        return userIds;
    }

    // Builds the shared request recap, including the component comment.
    @TestVisible
    private static String buildRequestDetails(RegistrationCountryApiService.Request request) {
        User submittingUser = [
            SELECT Name, Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        return
            'Share Class: ' + request.shareClassName + ' (' + String.valueOf(request.shareClassId) + ')\n' +
            'Submitted by: ' + submittingUser.Name + ' <' + submittingUser.Email + '>\n\n' +
            'Retail: ' + formatCountries(request.countriesByType.get('Retail')) + '\n' +
            'Institutional: ' + formatCountries(request.countriesByType.get('Institutional')) + '\n' +
            'Semi-Pro: ' + formatCountries(request.countriesByType.get('Semi-Pro')) + '\n\n' +
            'Comment: ' + safeText(request.comment, 'None');
    }

    // Formats one type as a readable comma-separated country list.
    private static String formatCountries(List<String> countries) {
        return countries == null || countries.isEmpty()
            ? 'None'
            : String.join(countries, ', ');
    }

    // Replaces blank optional values with a readable fallback.
    private static String safeText(String value, String fallbackValue) {
        return String.isBlank(value) ? fallbackValue : value.trim();
    }

    // Sends one or more messages and fails when Salesforce rejects an email.
    private static void sendEmails(
        Set<String> recipientEmails,
        String subject,
        String body
    ) {
        List<String> sortedEmails = new List<String>(recipientEmails);
        sortedEmails.sort();
        List<Messaging.Email> messages = new List<Messaging.Email>();

        // Splits large team lists into supported recipient batches.
        for (Integer startIndex = 0; startIndex < sortedEmails.size(); startIndex += RECIPIENTS_PER_EMAIL) {
            List<String> emailBatch = new List<String>();
            Integer endIndex = startIndex + RECIPIENTS_PER_EMAIL;
            if (endIndex > sortedEmails.size()) {
                endIndex = sortedEmails.size();
            }

            for (Integer emailIndex = startIndex; emailIndex < endIndex; emailIndex++) {
                emailBatch.add(sortedEmails[emailIndex]);
            }

            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.setToAddresses(emailBatch);
            message.setSubject(subject);
            message.setPlainTextBody(body);
            message.setSaveAsActivity(false);
            messages.add(message);
        }

        Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
        for (Messaging.SendEmailResult result : results) {
            if (!result.isSuccess()) {
                String errorMessage = result.getErrors().isEmpty()
                    ? 'Salesforce rejected the notification email.'
                    : result.getErrors()[0].getMessage();
                throw new NotificationException(errorMessage);
            }
        }
    }
}
