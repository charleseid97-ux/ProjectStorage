/** ──────────────────────────────────────
 * @description Sends the Teams messages built by TeamsMessageService (US-20337), RECIPIENTS_PER_JOB recipients per job (3 callouts each: user, chat, message, plus /me once
 *                  per Named Credential), then chains the next job. Same Microsoft Graph calls as WS_GetUserGraphApi_Queueable (WS_GetUserGraphApi), so the same sender
 *                  and the same 1:1 conversations; masked sandbox addresses (.invalid) are skipped as there.
 *              A recipient that can't be reached never stops the others: not found in Microsoft 365 (WARN), chat or message refused, callout error (ERROR),
 *                  logged on the record (LogFailures__c of the Teams message), then flushed at the end of each job.
 * @author Charles EID
 * @testClass TeamsMessageServiceTest
 * @coverage 86%   [12-11-26]
 ────────────────────────────────────── */
public without sharing class TeamsMessageQueueable implements Queueable, Database.AllowsCallouts {

    @TestVisible
    private static final Integer RECIPIENTS_PER_JOB = 30;
    private static final Integer CREATED = 201;

    private List<TeamsMessageService.Delivery> deliveries;
    private Integer startIndex;

    public TeamsMessageQueueable(List<TeamsMessageService.Delivery> deliveries) {
        this(deliveries, 0);
    }

    public TeamsMessageQueueable(List<TeamsMessageService.Delivery> deliveries, Integer startIndex) {
        this.deliveries = deliveries;
        this.startIndex = startIndex;
    }

    public void execute(QueueableContext context) {
        Integer endIndex = Math.min(startIndex + RECIPIENTS_PER_JOB, deliveries.size());
        Map<String, String> senderIdByNamedCredential = new Map<String, String>();
        Map<String, String> chatIdByRecipient = new Map<String, String>();
        for (Integer i = startIndex; i < endIndex; i++) {
            TeamsMessageService.Delivery delivery = deliveries[i];
            if (delivery.address.endsWith('.invalid')) continue;

            try {
                deliver(delivery, senderIdByNamedCredential, chatIdByRecipient);
            }
            catch (Exception e) {
                logFailure(OperationLogService.Level.ERROR, delivery, 'The Teams message could not be sent to ' + delivery.address + '.', e);
            }
        }
        OperationLogService.flush();
        if (endIndex < deliveries.size()) System.enqueueJob(new TeamsMessageQueueable(deliveries, endIndex));
    }

    // Sender (/me) and 1:1 chat are read once per job: a person receiving several messages costs one user lookup and one chat
    private static void deliver(TeamsMessageService.Delivery delivery, Map<String, String> senderIdByNamedCredential, Map<String, String> chatIdByRecipient) {
        String namedCredential = delivery.namedCredential;
        if (!senderIdByNamedCredential.containsKey(namedCredential)) senderIdByNamedCredential.put(namedCredential, WS_GetUserGraphApi.getCurrentUserId(namedCredential));
        String senderId = senderIdByNamedCredential.get(namedCredential);
        if (String.isBlank(senderId)) {
            logFailure(OperationLogService.Level.ERROR, delivery, 'The Microsoft 365 account of the Named Credential ' + namedCredential + ' could not be read (/me): check that it is authenticated.', null);
            return;
        }
        String recipientKey = namedCredential + '|' + delivery.address.toLowerCase();
        if (!chatIdByRecipient.containsKey(recipientKey)) {
            String recipientId = WS_GetUserGraphApi.getUserByEmail(namedCredential, delivery.address);
            if (String.isBlank(recipientId)) {
                logFailure(OperationLogService.Level.WARN, delivery, delivery.address + ' was not found in Microsoft 365: the Teams message was not sent to this person.', null);
                return;
            }
            chatIdByRecipient.put(recipientKey, WS_GetUserGraphApi.createChat(namedCredential, senderId, recipientId));
        }
        String chatId = chatIdByRecipient.get(recipientKey);
        if (String.isBlank(chatId)) {
            logFailure(OperationLogService.Level.ERROR, delivery, 'The Teams chat with ' + delivery.address + ' could not be opened: the Teams message was not sent to this person.', null);
            return;
        }
        HttpResponse response = WS_GetUserGraphApi.postChatMessage(namedCredential, chatId, delivery.content);
        if (response.getStatusCode() != CREATED) logFailure(OperationLogService.Level.ERROR, delivery, 'Microsoft Teams refused the message to ' + delivery.address + ' (' + response.getStatusCode() + '): ' + response.getBody(), null);
    }

    private static void logFailure(OperationLogService.Level level, TeamsMessageService.Delivery delivery, String message, Exception e) {
        if (delivery.logFailures != true) return;

        Map<String, Object> context = new Map<String, Object>{ 'customTeamsMessageName' => delivery.messageName, 'recipient' => delivery.address, 'namedCredential' => delivery.namedCredential };
        OperationLogService.logWithContext(level, delivery.recordId, delivery.logOperation, message, context, e, 'TeamsMessageQueueable', 'execute');
    }
}