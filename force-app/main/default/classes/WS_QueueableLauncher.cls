public class WS_QueueableLauncher {
    
    public class MessageInput {
        @InvocableVariable(required=true)
        public String email;
        
        @InvocableVariable(required=false)
        public String templateId;
        
        @InvocableVariable(required=false)
        public String message;
        
        @InvocableVariable(required=false)
        public Id recordId;
        
        @InvocableVariable(required=false)
        public String namedCredentialName; 
    }

    @InvocableMethod(label='Send Teams Message via Queueable (auto-batched)')
    public static void launch(List<MessageInput> requests) {
        List<WS_GetUserGraphApi_Queueable.MessageData> allMessages = new List<WS_GetUserGraphApi_Queueable.MessageData>();
        
        for (MessageInput input : requests) {
            List<String> emails = input.email.split(';');
            for (String email : emails) {
                WS_GetUserGraphApi_Queueable.MessageData md = new WS_GetUserGraphApi_Queueable.MessageData();
                md.email = email.trim();
                md.templateId = input.templateId;
                md.message = input.message;
                md.recordId = input.recordId;
                md.namedCredentialName = input.namedCredentialName;
                allMessages.add(md);
            }
        }

        // ❗ Un seul enqueueJob → WS_GetUserGraphApi_Queueable gère le découpage et chaînage
        System.enqueueJob(new WS_GetUserGraphApi_Queueable(allMessages));
    }
}