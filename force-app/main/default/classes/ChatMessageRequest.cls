public class ChatMessageRequest {
    
    public ChatMessageContent body { get; set; }
    
    /**
* @description Constructeur avec message
* @param message Le contenu du message à envoyer
*/
    public ChatMessageRequest(String message) {
        this.body = new ChatMessageContent();
        this.body.content = message;
    }
    
    public class ChatMessageContent {
        public String contentType { get; set; }
        public String content { get; set; }
        
        /**
* @description Constructeur par défaut
*/
        public ChatMessageContent() {
            this.contentType = 'html';
        }
    }
    
    /**
* @description Convertit l'objet en JSON
* @return Une chaîne JSON représentant l'objet
*/
    public String toJson() {
        return JSON.serialize(this);
    }
}