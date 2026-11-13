/** ──────────────────────────────────────
 * @description Flow action "Send Custom Email Alert": sends the email configured in a CustomEmailAlert__mdt record
 *                  (template, recipients, sender) through EmailService, the template rendered with the Record Id.
 *              One EmailService.EmailRequest per Flow interview, all sent in a single EmailService.send, then the
 *                  OperationLog buffer is flushed: this action is the entry point of the email logs.
 *              Configuration errors (unknown alert, template or queue, tokens and values of different sizes)
 *                  make the Flow fail; send failures are only logged (LogFailures__c) and never stop the Flow.
 *              An email left without To recipient goes to the No Recipient Addresses (Email and Notification Service Settings) and doesn't stop the Flow.
 *              Dry Run input: forces a dry run for that call (it can't turn off the alert's own DryRun__c).
 *              Additional To / Cc / Bcc Addresses inputs: addresses computed by the Flow (comma-separated text), added to the alert's Custom Email Recipients.
 *              US-20337: tokens and values are paired by EmailService.buildReplacements, shared with the Teams action (CustomTeamsMessageFlowAction).
 * @author Charles EID
 * @testClass EmailServiceTest
 * @coverage 100%   [12-11-26]
 * @lastModifiedBy Charles EID   [12-11-26]
 ────────────────────────────────────── */
public with sharing class CustomEmailAlertFlowAction {

    @InvocableMethod(label='Send Custom Email Alert' category='Email' description='Sends the email configured in a Custom Email Alert (Custom Metadata): template, recipients, sender. The template is rendered with the record given in Record Id.')
    public static void sendCustomEmailAlerts(List<Request> requests) {
        List<EmailService.EmailRequest> emailRequests = buildRequests(requests);
        EmailService.send(emailRequests);
        OperationLogService.flush();
    }

    // One EmailService request per Flow interview, from the alert and the Flow's inputs
    @TestVisible
    private static List<EmailService.EmailRequest> buildRequests(List<Request> requests) {
        List<EmailService.EmailRequest> emailRequests = new List<EmailService.EmailRequest>();
        for (Request request : requests) {
            EmailService.EmailRequest emailRequest = new EmailService.EmailRequest(request.alertName, request.recordId);
            emailRequest.recipientId = request.recipientId;
            emailRequest.to.addresses.addAll(EmailService.splitValues(request.additionalToAddresses));
            emailRequest.cc.addresses.addAll(EmailService.splitValues(request.additionalCcAddresses));
            emailRequest.bcc.addresses.addAll(EmailService.splitValues(request.additionalBccAddresses));
            emailRequest.replacements.putAll(EmailService.buildReplacements('Custom Email Alert "' + request.alertName + '"', request.replacementTokens, request.replacementValues));
            if (request.dryRun == true) emailRequest.dryRun = true;
            emailRequests.add(emailRequest);
        }
        return emailRequests;
    }

    public class Request {
        @InvocableVariable(required=true label='Custom Email Alert Name' description='API name (DeveloperName) of the Custom Email Alert record to send (Setup > Custom Metadata Types > Custom Email Alert). It defines the template, recipients and sender. Unknown name: the Flow fails. Inactive alert: nothing is sent.')
        public String alertName;

        @InvocableVariable(label='Record Id' description='Record used to fill the template\'s merge fields (e.g. {!Opportunity.Name} or {{{Opportunity.Name}}}). For a Lightning template, it must be of the template\'s related object. Leave empty if the template has no record merge fields. Send failures are logged on this record.')
        public Id recordId;

        @InvocableVariable(label='Recipient Id' description='Optional Contact, Lead or User Id. This person receives the email (in addition to the alert\'s recipients) and fills the template\'s Recipient merge fields. Required when a Lightning template uses {{{Recipient.…}}} fields. For a Person Account, use its PersonContactId.')
        public Id recipientId;

        @InvocableVariable(label='Additional To Addresses' description='Optional email addresses added to the alert\'s To recipients, for addresses computed in the Flow. Separate them with commas (semicolons or line breaks also work): a@example.com, b@example.com. If they are always the same, or read from a field of the record, add them to the Custom Email Alert\'s Custom Email Recipients instead. An invalid address is removed and logged; the others still receive the email.')
        public String additionalToAddresses;

        @InvocableVariable(label='Additional Cc Addresses' description='Optional email addresses added to the alert\'s Cc recipients, for addresses computed in the Flow, separated by commas. If they are always the same, or read from a field of the record, add them to the Custom Email Alert\'s Custom Email Recipients instead. An invalid address is removed and logged; the others still receive the email.')
        public String additionalCcAddresses;

        @InvocableVariable(label='Additional Bcc Addresses' description='Optional email addresses added to the alert\'s Bcc recipients, for addresses computed in the Flow, separated by commas. If they are always the same, or read from a field of the record, add them to the Custom Email Alert\'s Custom Email Recipients instead. An invalid address is removed and logged; the others still receive the email.')
        public String additionalBccAddresses;

        @InvocableVariable(label='Replacement Tokens' description='Optional text collection of tokens to replace in the email after rendering, e.g. {_Datatable_}. Each token is replaced by the value at the same position in Replacement Values.')
        public List<String> replacementTokens;

        @InvocableVariable(label='Replacement Values' description='Optional text collection of values (text or HTML), same size and order as Replacement Tokens. Different sizes: the Flow fails.')
        public List<String> replacementValues;

        @InvocableVariable(label='Dry Run' description='Optional. True: this email is a test, sent only to the Dry Run Addresses of the Email and Notification Service Settings (Custom Setting) with "[DRY RUN] " before the subject and the real recipients listed at the top of the body. Empty or False: the alert\'s own Dry Run setting applies.')
        public Boolean dryRun;
    }
}