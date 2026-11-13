/** ──────────────────────────────────────
 * @description Flow action "Send Custom Teams Message" (US-20337): sends the Microsoft Teams message configured in a CustomTeamsMessage__mdt record (template, recipients)
 *                  through TeamsMessageService, the template rendered with the Record Id. One TeamsMessageRequest per Flow interview, all sent in a single
 *                  TeamsMessageService.send, then the OperationLog buffer is flushed: this action is the entry point of the logs written in the Flow's transaction.
 *              Configuration errors (unknown Teams message, template or queue, tokens and values of different sizes) make the Flow fail; a recipient the message
 *                  can't reach is only logged (TeamsMessageQueueable) and never stops the Flow.
 *              No Recipient Id input: the people of the record are Custom Email Recipients of Type Record Field or Apex Resolver (an optional Id input left
 *                  empty breaks Flows on older API versions).
 * @author Charles EID
 * @testClass TeamsMessageServiceTest
 * @coverage 100%   [12-11-26]
 ────────────────────────────────────── */
public with sharing class CustomTeamsMessageFlowAction {

    @InvocableMethod(label='Send Custom Teams Message' category='Microsoft Teams' description='Sends the Microsoft Teams message configured in a Custom Teams Message (Custom Metadata): template and recipients. The template is rendered with the record given in Record Id; every recipient receives it in a 1:1 Teams chat.')
    public static void sendCustomTeamsMessages(List<Request> requests) {
        TeamsMessageService.send(buildRequests(requests));
        OperationLogService.flush();
    }

    // One TeamsMessageService request per Flow interview, from the Teams message and the Flow's inputs
    @TestVisible
    private static List<TeamsMessageService.TeamsMessageRequest> buildRequests(List<Request> requests) {
        List<TeamsMessageService.TeamsMessageRequest> teamsRequests = new List<TeamsMessageService.TeamsMessageRequest>();
        for (Request request : requests) {
            TeamsMessageService.TeamsMessageRequest teamsRequest = new TeamsMessageService.TeamsMessageRequest(request.teamsMessageName, request.recordId);
            teamsRequest.emailRequest.to.addresses.addAll(EmailService.splitValues(request.additionalAddresses));
            teamsRequest.emailRequest.replacements.putAll(EmailService.buildReplacements('Custom Teams Message "' + request.teamsMessageName + '"', request.replacementTokens, request.replacementValues));
            if (request.dryRun == true) teamsRequest.emailRequest.dryRun = true;
            teamsRequests.add(teamsRequest);
        }
        return teamsRequests;
    }

    public class Request {
        @InvocableVariable(required=true label='Custom Teams Message Name' description='API name (DeveloperName) of the Custom Teams Message record to send (Setup > Custom Metadata Types > Custom Teams Message). It defines the template and the recipients. Unknown name: the Flow fails. Inactive message: nothing is sent.')
        public String teamsMessageName;

        @InvocableVariable(label='Record Id' description='Record used to fill the template\'s merge fields (e.g. {{{Milestone__c.Name}}}) and read by the recipients\' conditions, record fields and Apex resolvers. For a Lightning template, it must be of the template\'s related object. Failures are logged on this record.')
        public Id recordId;

        @InvocableVariable(label='Additional Addresses' description='Optional email addresses of Microsoft 365 users who also receive the message, for addresses computed in the Flow. Separate them with commas (semicolons or line breaks also work). If they are always the same, or read from a field of the record, add them to the Custom Teams Message\'s Custom Email Recipients instead.')
        public String additionalAddresses;

        @InvocableVariable(label='Replacement Tokens' description='Optional text collection of tokens to replace in the message after rendering, e.g. {_LaunchDate_}. Each token is replaced by the value at the same position in Replacement Values.')
        public List<String> replacementTokens;

        @InvocableVariable(label='Replacement Values' description='Optional text collection of values (text or HTML), same size and order as Replacement Tokens. Different sizes: the Flow fails.')
        public List<String> replacementValues;

        @InvocableVariable(label='Dry Run' description='Optional. True: this message is a test, sent only to the Dry Run Addresses of the Email and Notification Service Settings (Custom Setting), with the real recipients listed at the top. Empty or False: the Teams message\'s own Dry Run setting applies.')
        public Boolean dryRun;
    }
}
