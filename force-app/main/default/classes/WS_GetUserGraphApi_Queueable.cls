public class WS_GetUserGraphApi_Queueable implements Queueable, Database.AllowsCallouts {

    public class MessageData {
        public String email;
        public String templateId;
        public String message;
        public Id recordId;
        public String namedCredentialName;
    }

    private List<MessageData> allMessages;
    private Integer startIndex;

    public WS_GetUserGraphApi_Queueable(List<MessageData> allMessages) { this(allMessages, 0); }
    public WS_GetUserGraphApi_Queueable(List<MessageData> allMessages, Integer startIndex) {
        this.allMessages = allMessages;
        this.startIndex = startIndex;
    }

    public void execute(QueueableContext context) {
        Integer batchSize = 5;
        Integer endIndex = Math.min(startIndex + batchSize, allMessages.size());
        List<MessageData> currentBatch = new List<MessageData>();
        for (Integer i = startIndex; i < endIndex; i++) currentBatch.add(allMessages[i]);

        // Cache des IDs "me" par Named Credential
        Map<String,String> currentUserIdByNC = new Map<String,String>();

        for (MessageData msg : currentBatch) {
            for (String raw : msg.email.split(';')) {
                String email = raw.trim();
                if (email.contains('invalid')) continue;

                String nc = String.isBlank(msg.namedCredentialName)
                    ? WS_GetUserGraphApi.DEFAULT_NC
                    : msg.namedCredentialName.trim();

                // Récupère/calcule l'ID user courant pour ce NC
                String currentUserId = currentUserIdByNC.get(nc);
                if (String.isBlank(currentUserId)) {
                    currentUserId = WS_GetUserGraphApi.getCurrentUserId(nc);
                    if (String.isBlank(currentUserId)) {
                        System.debug('Erreur : impossible de récupérer l\'ID utilisateur courant pour NC=' + nc);
                        continue;
                    }
                    currentUserIdByNC.put(nc, currentUserId);
                }

                try {
                    String recipientId = WS_GetUserGraphApi.getUserByEmail(nc, email);
                    if (String.isBlank(recipientId)) continue;

                    String chatId = WS_GetUserGraphApi.createChat(nc, currentUserId, recipientId);
                    if (String.isBlank(chatId)) continue;

                    // ----- Choix du contenu : template si fourni, sinon message -----
                    String content;
                    if (!String.isBlank(msg.templateId)) {
                        content = WS_GetUserGraphApi.getHtmlFromTemplate(msg.templateId);
                        content = WS_GetUserGraphApi.bindMergeFields(content, msg.recordId);
                    } else if (!String.isBlank(msg.message)) {
                        content = msg.message;
                    } else {
                        System.debug('Ignoré : ni templateId ni message fournis pour ' + email);
                        continue;
                    }

                    WS_GetUserGraphApi.sendTeamsMessage(nc, chatId, content);
                } catch (Exception e) {
                    System.debug('Erreur lors du traitement du message : ' + e.getMessage());
                }
            }
        }

        if (endIndex < allMessages.size()) {
            System.enqueueJob(new WS_GetUserGraphApi_Queueable(allMessages, endIndex));
        }
    }
}