@isTest
global class MockHttpGraphApi implements HttpCalloutMock {
    
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        
        if (req.getEndpoint().contains('/users?$filter=')) {
            // Simule la réponse de getUserByEmail
            res.setStatusCode(200);
            res.setBody('{"value": [{"id": "user-123"}]}');
        }
        else if (req.getEndpoint().endsWith('/me')) {
            // Simule la réponse de getCurrentUserId
            res.setStatusCode(200);
            res.setBody('{"id": "current-user-456"}');
        }
        else if (req.getEndpoint().endsWith('/chats')) {
            // Simule la création du chat
            res.setStatusCode(201);
            res.setBody('{"id": "chat-789"}');
        }
        else if (req.getEndpoint().contains('/chats/chat-789/messages')) {
            // Simule l'envoi de message Teams
            res.setStatusCode(201);
            res.setBody('{"id": "msg-0001"}');
        }
        else {
            res.setStatusCode(400);
            res.setBody('{"error": "Unknown request"}');
        }
        
        return res;
    }
}