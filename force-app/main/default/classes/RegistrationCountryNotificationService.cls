public without sharing class RegistrationCountryNotificationService {
    // Uses the exact Public Group API names configured in Salesforce.
    private static final Set<String> TEAM_GROUP_API_NAMES = new Set<String>{
        'PMTProductStrategy',
        'PMTLegal',
        'PMTDCR',
        'PMTFundMarketing',
        'PMTDigitalMarketing'
    };

    // Limits each outbound message to a safe number of recipient addresses.
    private static final Integer RECIPIENTS_PER_EMAIL = 100;

    // Identifie le template Visualforce utilisé pour les emails de succès.
    private static final String SUCCESS_TEMPLATE_DEVELOPER_NAME ='CountryRegistration';

    // Allows tests to bypass Public Group configuration and use known recipients.
    @TestVisible private static Set<String> recipientEmailsOverride;

    // Identifies an incomplete recipient or email configuration.
    public class NotificationException extends Exception {
    }

    // Sends the successful API submission with the CountryRegistration template.
    public static void sendSuccessEmail(
        RegistrationCountryApiService.Request request,
        RegistrationCountryApiService.Response response
    ) {
        Set<String> recipientEmails = resolveTeamRecipientEmails();
        EmailTemplate successTemplate = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = :SUCCESS_TEMPLATE_DEVELOPER_NAME
            AND IsActive = true
            LIMIT 1
        ];

        // Renders the Visualforce merge fields for the user and Share Class.
        Messaging.SingleEmailMessage renderedEmail =
            Messaging.renderStoredEmailTemplate(
                successTemplate.Id,
                UserInfo.getUserId(),
                request.shareClassId
            );
        String htmlBody = renderedEmail.getHtmlBody();

        // Replaces the request values that are not available as merge fields.
        htmlBody = htmlBody.replace(
            '@@RETAIL_COUNTRIES@@',
            formatCountries(request.countriesByType.get('Retail')).escapeHtml4()
        );
        htmlBody = htmlBody.replace(
            '@@INSTITUTIONAL_COUNTRIES@@',
            formatCountries(request.countriesByType.get('Institutional')).escapeHtml4()
        );
        htmlBody = htmlBody.replace(
            '@@SEMI_PRO_COUNTRIES@@',
            formatCountries(request.countriesByType.get('Semi-Pro')).escapeHtml4()
        );

        // Adds the comment and returned HTTP status to the rendered template.
        htmlBody = htmlBody.replace(
            '@@COMMENT@@',
            safeText(request.comment, 'None').escapeHtml4()
        );
        htmlBody = htmlBody.replace(
            '@@API_STATUS@@',
            String.valueOf(response.statusCode)
        );

        sendEmails(
            recipientEmails,
            renderedEmail.getSubject(),
            htmlBody,
            true
        );
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
        sendEmails(
            new Set<String>{ submittingUser.Email },
            subject,
            body,
            false
        );
    }

    // Resolves active users from the five exact Public Group names.
    @TestVisible
    private static Set<String> resolveTeamRecipientEmails() {
        if (Test.isRunningTest() && recipientEmailsOverride != null) {
            return new Set<String>(recipientEmailsOverride);
        }

        List<Group> teamGroups = [
            SELECT Id, DeveloperName
            FROM Group
            WHERE Type = 'Regular'
            AND DeveloperName IN :TEAM_GROUP_API_NAMES
        ];
        Set<String> foundGroupApiNames = new Set<String>();
        Set<Id> rootGroupIds = new Set<Id>();

        // Collects every configured team group and detects missing configuration.
        for (Group teamGroup : teamGroups) {
            foundGroupApiNames.add(teamGroup.DeveloperName);
            rootGroupIds.add(teamGroup.Id);
        }

        Set<String> missingGroupApiNames = new Set<String>();
        missingGroupApiNames.addAll(TEAM_GROUP_API_NAMES);
        missingGroupApiNames.removeAll(foundGroupApiNames);
        if (!missingGroupApiNames.isEmpty()) {
            List<String> sortedMissingApiNames = new List<String>(missingGroupApiNames);
            sortedMissingApiNames.sort();
            throw new NotificationException(
                'Missing Registration Country Public Groups: ' +
                String.join(sortedMissingApiNames, ', ') + '.'
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

    // Formats one type with the complete country labels.
    private static String formatCountries(List<String> countries) {
        if (countries == null || countries.isEmpty()) {
            return 'None';
        }

        // Builds the mapping between Salesforce values and displayed labels.
        Map<String, String> labelsByValue = new Map<String, String>();
        Schema.DescribeFieldResult fieldDescribe =
            Schema.SObjectType.Country__c.fields.Country__c;

        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            labelsByValue.put(entry.getValue(), entry.getLabel());
        }

        // Replaces each technical value while preserving the original order.
        List<String> countryLabels = new List<String>();
        for (String country : countries) {
            String countryLabel = labelsByValue.get(country);
            countryLabels.add(
                String.isBlank(countryLabel) ? country : countryLabel
            );
        }

        return String.join(countryLabels, ', ');
    }

    // Replaces blank optional values with a readable fallback.
    private static String safeText(String value, String fallbackValue) {
        return String.isBlank(value) ? fallbackValue : value.trim();
    }

    // Sends HTML or plain-text messages and detects Salesforce email failures.
    private static void sendEmails(
        Set<String> recipientEmails,
        String subject,
        String body,
        Boolean useHtmlBody
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

            // Uses the shared Org-Wide Email Address instead of the connected user's address.
            OrgWideEmailAddress senderAddress = [
                SELECT Id
                FROM OrgWideEmailAddress
                WHERE Address = 'noreplysalesforce@carmignac.com'
                LIMIT 1
            ];
            message.setOrgWideEmailAddressId(senderAddress.Id);

            message.setToAddresses(emailBatch);
            message.setSubject(subject);

            // Uses HTML only for the rendered success template.
            if (useHtmlBody) {
                message.setHtmlBody(body);
            } else {
                message.setPlainTextBody(body);
            }

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