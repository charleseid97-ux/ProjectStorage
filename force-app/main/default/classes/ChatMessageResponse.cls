public class ChatMessageResponse {
    
    public String id { get; set; }
    public String etag { get; set; }
    public ChatMessageContent body { get; set; }
    public DateTime createdDateTime { get; set; }
    public DateTime lastModifiedDateTime { get; set; }
    public String messageType { get; set; }
    
    /**
* @description Classe pour le contenu du message
*/
    public class ChatMessageContent {
        public String contentType { get; set; }
        public String content { get; set; }
    }
    
    /**
* @description Analyse la réponse JSON et crée une instance de ChatMessageResponse
* @param jsonResponse La réponse JSON brute de l'API
* @return Une instance de ChatMessageResponse
*/
    public static ChatMessageResponse parse(String jsonResponse) {
        try {
            return (ChatMessageResponse) JSON.deserialize(jsonResponse, ChatMessageResponse.class);
        } catch (Exception e) {
            System.debug('Erreur lors de la désérialisation de la réponse: ' + e.getMessage());
            System.debug('Réponse JSON: ' + jsonResponse);
            throw e;
        }
    }
}