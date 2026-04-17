public class WS_GetUserGraphApi {
    
    // Default Value
    public static final String DEFAULT_NC = 'MicrosoftGraph';

    private static String safeNc(String nc) {
        return String.isBlank(nc) ? DEFAULT_NC : nc.trim();
    }

    private static String buildEndpoint(String nc, String pathAndQuery) {
        String base = 'callout:' + safeNc(nc);
        if (!pathAndQuery.startsWith('/')) pathAndQuery = '/' + pathAndQuery;
        return base + pathAndQuery;
    }
    
    
    private static String encodeURIComponent(String value) {
        return EncodingUtil.urlEncode(value, 'UTF-8')
            .replace('+', '%20')
            .replace('*', '%2A')
            .replace('%7E', '~');
    }
    
    public static String getUserByEmail(String namedCredentialName, String email){
        
        HttpRequest req = new HttpRequest();
        
        Http http = new Http();
        
        String filter = 'mail eq \'' + email + '\'';
        
        String encodedFilter = encodeURIComponent(filter);
        req.setEndpoint(buildEndpoint(namedCredentialName, '/users?$filter=' + encodedFilter));
        
        req.setMethod('GET');
        
        req.setHeader('Content-Type','application/json');
        
        req.setHeader('Accept','application/json');
        
        req.setHeader('Accept-Encoding','gzip, deflate, br');
        
        System.debug('Endpoint Value: '+ req.getEndpoint());
        
        System.debug('Request: ' + req);
        
        HTTPResponse res = http.send(req);
        
        System.debug('Response Body: '+res.getBody());
        System.debug('Response status code: '+res.getStatusCode());
        
        String jsonResponse = res.getBody();
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            
            Map<String, Object> parsedJson = (Map<String, Object>)JSON.deserializeUntyped(jsonResponse);
            List<Object> values = (List<Object>)parsedJson.get('value');
            
            if(values != null && !values.isEmpty()){
                Map<String, Object> firstValue = (Map<String, Object>)values[0]; 
                
                String userId = (String) firstValue.get('id');
                
                system.debug('id '+userId);
                
                return userId;
            }
            
            return null;
            
        } else {
            System.debug('Erreur HTTP: ' + res.getStatusCode() + ' ' + res.getStatus());
            return null;
        }
    }
    
    public static String getCurrentUserId(String namedCredentialName) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(buildEndpoint(namedCredentialName, '/me'));
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        Http http = new Http();
        try {
            HttpResponse response = http.send(request);
            system.debug('body : ' + response.getBody());
            if (response.getStatusCode() == 200) {
                Map<String, Object> userInfo = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                system.debug(userInfo.get('id'));
                system.debug(userInfo.get('displayName'));
                return (String) userInfo.get('id');
            }
            system.debug('response.getStatusCode() :'+response.getStatusCode());
            
        } catch (Exception e) {
            System.debug('Error getting current user ID: ' + e.getMessage());
        }
        return null;
    }
    
    public static String buildChatRequestBody(String currentUserId, String recipientId) {
        // Chat members List
        List<Map<String, Object>> members = new List<Map<String, Object>>();
        
        // Add member 1 (actual user)
        Map<String, Object> member1 = new Map<String, Object>();
        member1.put('@odata.type', '#microsoft.graph.aadUserConversationMember');
        member1.put('roles', new List<String>{'owner'});
        member1.put('user@odata.bind', 'https://graph.microsoft.com/v1.0/users/' + currentUserId);
        members.add(member1);
        
        // Add member 2 (dest)
        Map<String, Object> member2 = new Map<String, Object>();
        member2.put('@odata.type', '#microsoft.graph.aadUserConversationMember');
        member2.put('roles', new List<String>{'owner'});
        member2.put('user@odata.bind', 'https://graph.microsoft.com/v1.0/users/' + recipientId);
        members.add(member2);
        
        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('chatType', 'oneOnOne');
        requestBody.put('members', members);
        
        return JSON.serializePretty(requestBody); 
    }
    
    
    public static String createChat(String namedCredentialName, String currentUserId, String recipientId) {
   
        String requestBody = buildChatRequestBody(currentUserId, recipientId);
        
        HttpRequest request = new HttpRequest();
        request.setEndpoint(buildEndpoint(namedCredentialName, '/chats'));
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(requestBody);
        system.debug(request);
        //system.debug(requestBody);
        
        Http http = new Http();
        try {
            HttpResponse response = http.send(request);
            System.debug('Response: ' + response.getBody());
            
            if (response.getStatusCode() == 201) { // 201 = Created
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String chatId = (String) responseMap.get('id');
                System.debug('Chat ID: ' + chatId);
                return chatId;
            } else {
                System.debug('Error: ' + response.getBody());
            } 
        }
        catch (Exception e) {
            System.debug('Error while creating chat: ' + e.getMessage());
        }
        
        return null;
    }
    
    public static String getHtmlFromTemplate(String templateId) {
        EmailTemplate template = [
            SELECT HtmlValue FROM EmailTemplate WHERE Id = :templateId LIMIT 1
        ];
        return template.HtmlValue.unescapeHtml4();
    }
    
    /*
    @InvocableMethod(label='Send Microsoft Teams Message' description='Send an HTML message to a Microsoft Teams chat using a Lightning Email Template')
    public static void sendMessage(List<MessageRequest> messageRequests) {
        system.debug('avant');
        for (MessageRequest request : messageRequests) {
            system.debug('request : '+request.email);
            for(String email : request.email.split(';')){
                if(!email.contains('invalid')){
                    system.debug('email : '+email);
                    sendMessageFuture(email, request.templateId, request.recordId);
                }
                
            }
            
        }
        system.debug('apres');
        
    }
    
    
    public static void sendMessageFuture(String email, String templateId, String recordId) {
        system.debug('future');
        try {
            
            String chatId = createChat(email);
            if (String.isBlank(chatId)) {
                System.debug('Erreur: chatId est requis');
                return;
            }
            
            String content = getHtmlFromTemplate(templateId);
            content = bindMergeFields(content, recordId);
            sendTeamsMessage(chatId, content);
        } catch (Exception e) {
            System.debug('Erreur dans sendMessageFuture: ' + e.getMessage());
        }
    }
    */
    
    
    public static void sendTeamsMessage(String namedCredentialName, String chatId, String messageBody) {
        HttpRequest req = new HttpRequest();
        Http http = new Http();
        
        req.setEndpoint(buildEndpoint(namedCredentialName, '/chats/' + chatId + '/messages'));
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');       
        
        Map<String, Object> message = new Map<String, Object>{
            'body' => new Map<String, Object>{'contentType' => 'html',
                'content' => messageBody}
        };
            
            req.setBody(JSON.serialize(message));
        
        HTTPResponse res = http.send(req);
        if (res.getStatusCode() == 201) {
            System.debug('Message envoyé avec succès à Teams.');
        } else {
            System.debug('Erreur lors de l\'envoi du message à Teams : ' + res.getBody());
        }
    }
    
    //@InvocableMethod(label='Send Microsoft Teams Message' description='Send a message to a Microsoft Teams chat')
    /*public static void sendMessageAncien(List<MessageRequest> messageRequests) {
        //List<ChatMessageResponse> responses = new List<ChatMessageResponse>();
        
        for (MessageRequest request : messageRequests) {
            String chatId = createChat(request.email);
            
            if (String.isBlank(chatId)) {
                System.debug('Erreur: chatId ou message est requis');
                //responses.add(new ChatMessageResponse('Erreur: chatId ou message manquant', null));
                continue;
            }
            
            HttpRequest req = new HttpRequest();
            Http http = new Http();
            
            req.setEndpoint('callout:MicrosoftGraph/chats/' + chatId + '/messages');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            
            ChatMessageRequest messageRequest = new ChatMessageRequest('');
            req.setBody(messageRequest.toJson());
            
            try {
                HTTPResponse res = http.send(req);
                String jsonResponse = res.getBody();
                System.debug('Response status code: ' + res.getStatusCode());
                System.debug('Response Body: ' + jsonResponse);
                
                if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                    ChatMessageResponse response = ChatMessageResponse.parse(jsonResponse);
                    System.debug('Message envoyé avec succès. ID: ' + response.id);
                    //responses.add(response);
                } else {
                    System.debug('Erreur lors de l\'envoi du message: ' + res.getStatusCode() + ' ' + res.getStatus());
                    //responses.add(new ChatMessageResponse('Erreur lors de l\'envoi du message', null));
                }
            } catch (Exception e) {
                System.debug('Exception lors de l\'envoi du message: ' + e.getMessage());
                //responses.add(new ChatMessageResponse('Exception lors de l\'envoi du message', null));
            }
        }
        
        //return responses;
    }
    */
    // Classe pour recevoir les paramètres de la méthode invocable
    /*public class MessageRequest {
        @InvocableVariable(label='Recipient Email' description='Email address of the recipient user')
        public String email;
        
        @InvocableVariable(label='Template Id' description='Lightning Template Email')
        public String templateId;
        
        @InvocableVariable(label='record Id' description='record Id for whoId')
        public Id recordId; 
    }*/
    
    public static String bindMergeFields(String htmlTemplate, Id recordId) {
        if (String.isBlank(htmlTemplate) || recordId == null) return htmlTemplate;
        
        // Récupérer le nom de l'objet API du recordId
        Schema.SObjectType objectType = recordId.getSObjectType();
        String objectApiName = objectType.getDescribe().getName();
        
        // Extraire les tokens {{...}} dans le template
        Pattern pattern = Pattern.compile('\\{\\{\\{(.*?)\\}\\}\\}');
        Matcher matcher = pattern.matcher(htmlTemplate);
        Set<String> allFields = new Set<String>();
        
        while (matcher.find()) {
            allFields.add(matcher.group(1)); // Ajouter les tokens trouvés dans un Set
        }
        
        // Préparer les chemins de champs à interroger
        Set<String> fieldPaths = new Set<String>();
        for (String f : allFields) {
            // Si le token commence par le nom de l'objet API, on enlève ce préfixe
            if (f.toLowerCase().startsWith(objectApiName.toLowerCase() + '.')) {
                // Retirer le préfixe de l'objet (par exemple "MyObject__c.")
                String cleaned = f.substring(objectApiName.length() + 1);
                fieldPaths.add(cleaned);
            }
        }
        
        // Variables pour stocker les champs de base et les relations
        Set<String> baseFields = new Set<String>();
        Map<String, Set<String>> relationships = new Map<String, Set<String>>();
        
        // Séparer les champs simples et les champs liés aux relations
        for (String path : fieldPaths) {
            if (path.contains('.')) {
                String rel = path.substring(0, path.indexOf('.'));
                String relField = path.substring(path.indexOf('.') + 1);
                if (!relationships.containsKey(rel)) {
                    relationships.put(rel, new Set<String>());
                }
                relationships.get(rel).add(relField);
            } else {
                baseFields.add(path);
            }
        }
        
        // Construction de la requête SOQL
        String query = 'SELECT ';
        List<String> selectParts = new List<String>();
        
        // Ajouter les champs simples à la requête
        for (String f : baseFields) {
            selectParts.add(f);
        }
        
        // Ajouter les champs des relations à la requête
        for (String rel : relationships.keySet()) {
            String relFields = String.join(new List<String>(relationships.get(rel)), ', ');
            selectParts.add(rel + '.(' + relFields + ')');
        }
        
        query += String.join(selectParts, ', ') + ' FROM ' + objectApiName + ' WHERE Id = :recordId';
        
        // Exécution de la requête dynamique
        SObject record;
        try {
            record = Database.query(query);
        } catch (Exception e) {
            System.debug('Erreur lors du query dynamique : ' + e.getMessage());
            return htmlTemplate; // Retourner le template original en cas d'erreur
        }
        
        // Appliquer les valeurs des champs dans le template
        for (String fullPath : allFields) {
            if (!fullPath.toLowerCase().startsWith(objectApiName.toLowerCase() + '.')) continue;
            
            // Retirer le préfixe de l'objet dans le chemin du champ
            String relativePath = fullPath.substring(objectApiName.length() + 1);
            Object value;
            
            try {
                if (relativePath.contains('.')) {
                    // Pour les champs liés à des relations
                    List<String> parts = relativePath.split('\\.');
                    SObject current = record;
                    for (Integer i = 0; i < parts.size() - 1; i++) {
                        current = (SObject) current.getSObject(parts[i]);
                        if (current == null) break;
                    }
                    if (current != null) {
                        value = current.get(parts[parts.size() - 1]);
                    }
                } else {
                    // Pour les champs simples
                    value = record.get(relativePath);
                }
                
                // Remplacer les tokens dans le template
                htmlTemplate = htmlTemplate.replace('{{{' + fullPath + '}}}', value != null ? String.valueOf(value) : '');
            } catch (Exception e) {
                System.debug('Erreur de binding sur ' + fullPath + ' : ' + e.getMessage());
                htmlTemplate = htmlTemplate.replace('{{{' + fullPath + '}}}', ''); // Remplacer par une chaîne vide en cas d'erreur
            }
        }
        
        // Retourner le template HTML avec les valeurs injectées, sans changer les guillemets doubles
        return htmlTemplate;
    }
    
    
}