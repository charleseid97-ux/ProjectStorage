/** ──────────────────────────────────────
 * @description Microsoft Graph callouts for Teams messages, through a Named Credential (default MicrosoftGraph, a single Microsoft 365 account): current account (/me),
 *                  user by email, 1:1 chat with a recipient, message in a chat. Used by WS_GetUserGraphApi_Queueable (WS_QueueableLauncher) and, since US-20337,
 *                  by TeamsMessageQueueable (TeamsMessageService), which reads the response of postChatMessage to log a refused message.
 * @testClass Test_WS_GetUserGraphApi, TeamsMessageServiceTest
 * @coverage 59%   [12-11-26]
 * @lastModifiedBy Charles EID   [12-11-26]
 ────────────────────────────────────── */
public class WS_GetUserGraphApi {

    // Default Value
    public static final String DEFAULT_NC = 'MicrosoftGraph';

    public static String getUserByEmail(String namedCredentialName, String email) {
        HttpRequest req = new HttpRequest();
        Http http = new Http();
        String filter = 'mail eq \'' + email + '\'';
        String encodedFilter = encodeURIComponent(filter);
        req.setEndpoint(buildEndpoint(namedCredentialName, '/users?$filter=' + encodedFilter));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Accept-Encoding', 'gzip, deflate, br');
        HTTPResponse res = http.send(req);

        String jsonResponse = res.getBody();
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            List<Object> values = (List<Object>) parsedJson.get('value');
            if (values != null && !values.isEmpty()) {
                Map<String, Object> firstValue = (Map<String, Object>) values[0];
                String userId = (String) firstValue.get('id');
                System.debug('id ' + userId);
                return userId;
            }
            return null;
        }
        else {
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
            System.debug('body : ' + response.getBody());
            if (response.getStatusCode() == 200) {
                Map<String, Object> userInfo = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                System.debug(userInfo.get('id'));
                System.debug(userInfo.get('displayName'));
                return (String) userInfo.get('id');
            }
            System.debug('response.getStatusCode() :' + response.getStatusCode());
        }
        catch (Exception e) {
            System.debug('Error getting current user ID: ' + e.getMessage());
        }
        return null;
    }

    // Body of a 1:1 chat between the Named Credential's account and the recipient, both owners
    public static String buildChatRequestBody(String currentUserId, String recipientId) {
        List<Map<String, Object>> members = new List<Map<String, Object>>();
        Map<String, Object> member1 = new Map<String, Object>();
        member1.put('@odata.type', '#microsoft.graph.aadUserConversationMember');
        member1.put('roles', new List<String>{ 'owner' });
        member1.put('user@odata.bind', 'https://graph.microsoft.com/v1.0/users/' + currentUserId);
        members.add(member1);

        Map<String, Object> member2 = new Map<String, Object>();
        member2.put('@odata.type', '#microsoft.graph.aadUserConversationMember');
        member2.put('roles', new List<String>{ 'owner' });
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
        System.debug(request);

        Http http = new Http();
        try {
            HttpResponse response = http.send(request);
            System.debug('Response: ' + response.getBody());
            // 201 = Created
            if (response.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String chatId = (String) responseMap.get('id');
                System.debug('Chat ID: ' + chatId);
                return chatId;
            }
            else {
                System.debug('Error: ' + response.getBody());
            }
        }
        catch (Exception e) {
            System.debug('Error while creating chat: ' + e.getMessage());
        }
        return null;
    }

    public static String getHtmlFromTemplate(String templateId) {
        EmailTemplate template = [SELECT HtmlValue FROM EmailTemplate WHERE Id = :templateId LIMIT 1];
        return template.HtmlValue.unescapeHtml4();
    }

    public static void sendTeamsMessage(String namedCredentialName, String chatId, String messageBody) {
        HTTPResponse res = postChatMessage(namedCredentialName, chatId, messageBody);
        if (res.getStatusCode() == 201) {
            System.debug('Message envoyé avec succès à Teams.');
        }
        else {
            System.debug('Erreur lors de l\'envoi du message à Teams : ' + res.getBody());
        }
    }

    // US-20337: posts an HTML message in a chat and returns Graph's response (201 = sent), so TeamsMessageQueueable can log a refused message; sendTeamsMessage keeps its behavior on top of it
    public static HttpResponse postChatMessage(String namedCredentialName, String chatId, String messageBody) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(buildEndpoint(namedCredentialName, '/chats/' + chatId + '/messages'));
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        Map<String, Object> message = new Map<String, Object>{ 'body' => new Map<String, Object>{ 'contentType' => 'html', 'content' => messageBody } };
        req.setBody(JSON.serialize(message));
        return new Http().send(req);
    }

    // Replaces the {{{Object.Field}}} tokens of a template with the record's values (the record's own fields; a relationship field makes the query fail and the template is returned unchanged)
    public static String bindMergeFields(String htmlTemplate, Id recordId) {
        if (String.isBlank(htmlTemplate) || recordId == null) return htmlTemplate;

        // Récupérer le nom de l'objet API du recordId
        Schema.SObjectType objectType = recordId.getSObjectType();
        String objectApiName = objectType.getDescribe().getName();

        // Extraire les tokens {{...}} dans le template
        Pattern pattern = Pattern.compile('\\{\\{\\{(.*?)\\}\\}\\}');
        Matcher matcher = pattern.matcher(htmlTemplate);
        Set<String> allFields = new Set<String>();
        while (matcher.find()) allFields.add(matcher.group(1));

        // Préparer les chemins de champs à interroger : un token qui commence par le nom de l'objet API perd ce préfixe (par exemple "MyObject__c.")
        Set<String> fieldPaths = new Set<String>();
        for (String f : allFields) {
            if (f.toLowerCase().startsWith(objectApiName.toLowerCase() + '.')) fieldPaths.add(f.substring(objectApiName.length() + 1));
        }

        // Séparer les champs simples et les champs liés aux relations
        Set<String> baseFields = new Set<String>();
        Map<String, Set<String>> relationships = new Map<String, Set<String>>();
        for (String path : fieldPaths) {
            if (path.contains('.')) {
                String rel = path.substring(0, path.indexOf('.'));
                String relField = path.substring(path.indexOf('.') + 1);
                if (!relationships.containsKey(rel)) relationships.put(rel, new Set<String>());
                relationships.get(rel).add(relField);
            }
            else {
                baseFields.add(path);
            }
        }

        // Construction de la requête SOQL : champs simples puis champs des relations
        String query = 'SELECT ';
        List<String> selectParts = new List<String>();
        for (String f : baseFields) selectParts.add(f);
        for (String rel : relationships.keySet()) {
            String relFields = String.join(new List<String>(relationships.get(rel)), ', ');
            selectParts.add(rel + '.(' + relFields + ')');
        }
        query += String.join(selectParts, ', ') + ' FROM ' + objectApiName + ' WHERE Id = :recordId';

        // Exécution de la requête dynamique ; en cas d'erreur, le template original est retourné
        SObject record;
        try {
            record = Database.query(query);
        }
        catch (Exception e) {
            System.debug('Erreur lors du query dynamique : ' + e.getMessage());
            return htmlTemplate;
        }

        // Appliquer les valeurs des champs dans le template (une chaîne vide en cas d'erreur)
        for (String fullPath : allFields) {
            if (!fullPath.toLowerCase().startsWith(objectApiName.toLowerCase() + '.')) continue;

            String relativePath = fullPath.substring(objectApiName.length() + 1);
            Object value;
            try {
                if (relativePath.contains('.')) {
                    List<String> parts = relativePath.split('\\.');
                    SObject current = record;
                    for (Integer i = 0; i < parts.size() - 1; i++) {
                        current = (SObject) current.getSObject(parts[i]);
                        if (current == null) break;
                    }
                    if (current != null) value = current.get(parts[parts.size() - 1]);
                }
                else {
                    value = record.get(relativePath);
                }
                htmlTemplate = htmlTemplate.replace('{{{' + fullPath + '}}}', value != null ? String.valueOf(value) : '');
            }
            catch (Exception e) {
                System.debug('Erreur de binding sur ' + fullPath + ' : ' + e.getMessage());
                htmlTemplate = htmlTemplate.replace('{{{' + fullPath + '}}}', '');
            }
        }
        return htmlTemplate;
    }

    private static String safeNc(String nc) {
        return String.isBlank(nc) ? DEFAULT_NC : nc.trim();
    }

    private static String buildEndpoint(String nc, String pathAndQuery) {
        String base = 'callout:' + safeNc(nc);
        if (!pathAndQuery.startsWith('/')) pathAndQuery = '/' + pathAndQuery;
        return base + pathAndQuery;
    }

    private static String encodeURIComponent(String value) {
        return EncodingUtil.urlEncode(value, 'UTF-8').replace('+', '%20').replace('*', '%2A').replace('%7E', '~');
    }
}