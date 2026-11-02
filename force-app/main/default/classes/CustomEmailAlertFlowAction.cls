/** ──────────────────────────────────────
 * @description Flow action "Send Custom Email Alert": sends the email configured in a CustomEmailAlert__mdt record
 *                  (template, recipients, sender) through EmailService, the template rendered with the Record Id.
 *              One EmailService.EmailRequest per Flow interview, all sent in a single EmailService.send, then the
 *                  OperationLog buffer is flushed: this action is the entry point of the email logs.
 *              Configuration errors (unknown alert, template or queue, no recipient, tokens and values of different sizes)
 *                  make the Flow fail; send failures are only logged (LogFailures__c) and never stop the Flow.
 * @author Charles EID
 * @testClass TBD
 * @coverage TBD
 ────────────────────────────────────── */
public with sharing class CustomEmailAlertFlowAction {

    @InvocableMethod(label='Send Custom Email Alert' category='Email' description='Sends the email configured in a Custom Email Alert (Custom Metadata): template, recipients, sender. The template is rendered with the record given in Record Id.')
    public static void sendCustomEmailAlerts(List<Request> requests) {
        List<EmailService.EmailRequest> emailRequests = new List<EmailService.EmailRequest>();
        for (Request request : requests) {
            EmailService.EmailRequest emailRequest = new EmailService.EmailRequest(request.alertName, request.recordId);
            emailRequest.recipientId = request.recipientId;
            emailRequest.replacements.putAll(buildReplacements(request));
            emailRequests.add(emailRequest);
        }
        EmailService.send(emailRequests);
        OperationLogService.flush();
    }

    // Replacement Tokens and Replacement Values are matched by position (Flow has no Map type)
    private static Map<String, String> buildReplacements(Request request) {
        List<String> tokens = request.replacementTokens != null ? request.replacementTokens : new List<String>();
        List<String> values = request.replacementValues != null ? request.replacementValues : new List<String>();
        if (tokens.size() != values.size()) throw new EmailService.EmailServiceException('Custom Email Alert "' + request.alertName + '": ' + tokens.size() + ' Replacement Tokens for ' + values.size() + ' Replacement Values. Both collections need the same size and order.');

        Map<String, String> replacements = new Map<String, String>();
        for (Integer i = 0; i < tokens.size(); i++) replacements.put(tokens[i], values[i]);
        return replacements;
    }

    public class Request {
        @InvocableVariable(required=true label='Custom Email Alert Name' description='API name (DeveloperName) of the Custom Email Alert record to send (Setup > Custom Metadata Types > Custom Email Alert). It defines the template, recipients and sender. Unknown name: the Flow fails. Inactive alert: nothing is sent.')
        public String alertName;

        @InvocableVariable(label='Record Id' description='Record used to fill the template\'s merge fields (e.g. {!Opportunity.Name} or {{{Opportunity.Name}}}). For a Lightning template, it must be of the template\'s related object. Leave empty if the template has no record merge fields. Send failures are logged on this record.')
        public Id recordId;

        @InvocableVariable(label='Recipient Id' description='Optional Contact, Lead or User Id. This person receives the email (in addition to the alert\'s recipients) and fills the template\'s Recipient merge fields. Required when a Lightning template uses {{{Recipient.…}}} fields. For a Person Account, use its PersonContactId.')
        public Id recipientId;

        @InvocableVariable(label='Replacement Tokens' description='Optional text collection of tokens to replace in the email after rendering, e.g. {_Datatable_}. Each token is replaced by the value at the same position in Replacement Values.')
        public List<String> replacementTokens;

        @InvocableVariable(label='Replacement Values' description='Optional text collection of values (text or HTML), same size and order as Replacement Tokens. Different sizes: the Flow fails.')
        public List<String> replacementValues;
    }
}