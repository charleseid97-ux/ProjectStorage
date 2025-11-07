public class WS_GetUserGraphApi_Queueable implements Queueable, Database.AllowsCallouts {

    public class MessageData {
        public String email;
        public String templateId;
        public Id recordId;
    }

    private List<MessageData> allMessages;
    private Integer startIndex;

    // Constructeurs
    public WS_GetUserGraphApi_Queueable(List<MessageData> allMessages) {
        this(allMessages, 0);
    }

    public WS_GetUserGraphApi_Queueable(List<MessageData> allMessages, Integer startIndex) {
        this.allMessages = allMessages;
        this.startIndex = startIndex;
    }

    public void execute(QueueableContext context) {
        Integer batchSize = 5;
        Integer endIndex = Math.min(startIndex + batchSize, allMessages.size());
        List<MessageData> currentBatch = new List<MessageData>();

        for (Integer i = startIndex; i < endIndex; i++) {
            currentBatch.add(allMessages[i]);
        }

        String currentUserId = WS_GetUserGraphApi.getCurrentUserId();
        if (String.isBlank(currentUserId)) {
            System.debug('Erreur : impossible de récupérer l\'ID utilisateur courant.');
            return;
        }

        for (MessageData msg : currentBatch) {
            for (String email : msg.email.split(';')) {
                email = email.trim();
                if (!email.contains('invalid')) {
                    try {
                        String recipientId = WS_GetUserGraphApi.getUserByEmail(email);
                        if (String.isBlank(recipientId)) continue;

                        String chatId = WS_GetUserGraphApi.createChat(currentUserId, recipientId);
                        if (String.isBlank(chatId)) continue;

                        String content = WS_GetUserGraphApi.getHtmlFromTemplate(msg.templateId);
                        content = WS_GetUserGraphApi.bindMergeFields(content, msg.recordId);

                        WS_GetUserGraphApi.sendTeamsMessage(chatId, content);
                    } catch (Exception e) {
                        System.debug('Erreur lors du traitement du message : ' + e.getMessage());
                    }
                }
            }
        }

        // Enchaînement automatique si d'autres messages à traiter
        if (endIndex < allMessages.size()) {
            System.enqueueJob(new WS_GetUserGraphApi_Queueable(allMessages, endIndex));
        }
    }
}