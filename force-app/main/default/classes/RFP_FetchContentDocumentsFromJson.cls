public with sharing class RFP_FetchContentDocumentsFromJson {

    // ====== INPUT POUR FLOW ======
    public class Request {
        @InvocableVariable(required=true)
        public String json; // JSON en entrée
    }

    // ====== SORTIE POUR FLOW ======
    public class Response {
        @InvocableVariable
        public List<ContentDocument> documents;
    }

    @InvocableMethod(
        label='Fetch ContentDocuments from JSON'
        description='Parse le JSON (documents[id,title,rank]) et renvoie les ContentDocument associés via ContentDocumentLink.'
    )
    public static List<Response> fetch(List<Request> requests) {

        Response res = new Response();
        res.documents = new List<ContentDocument>();

        // Sécurité basique
        if (requests == null || requests.isEmpty() || String.isBlank(requests[0].json)) {
            return new List<Response>{ res };
        }

        String jsonInput = requests[0].json;

        try {
            // Parsing non typé
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(jsonInput);
            if (root == null || !root.containsKey('documents')) {
                return new List<Response>{ res };
            }

            List<Object> docs = (List<Object>) root.get('documents');
            if (docs == null || docs.isEmpty()) {
                return new List<Response>{ res };
            }

            // Récupération des LinkedEntityId (IDs des enregistrements métier)
            Set<Id> linkedEntityIds = new Set<Id>();

            for (Object o : docs) {
                if (!(o instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> docMap = (Map<String, Object>) o;
                String rawId = (String) docMap.get('id');

                if (String.isBlank(rawId)) {
                    continue;
                }

                try {
                    Id linkedId = (Id) rawId;
                    linkedEntityIds.add(linkedId);
                } catch (Exception e) {
                    // Si ce n'est pas un Id Salesforce valide, on ignore
                }
            }

            if (linkedEntityIds.isEmpty()) {
                return new List<Response>{ res };
            }

            // Requête des liens ContentDocumentLink
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :linkedEntityIds
            ];

            if (links.isEmpty()) {
                return new List<Response>{ res };
            }

            // Récupérer les IDs de ContentDocument
            Set<Id> contentDocumentIds = new Set<Id>();
            for (ContentDocumentLink cdl : links) {
                if (cdl.ContentDocumentId != null) {
                    contentDocumentIds.add(cdl.ContentDocumentId);
                }
            }

            if (contentDocumentIds.isEmpty()) {
                return new List<Response>{ res };
            }

            // Requête des ContentDocument
            res.documents = [
                SELECT Id, Title, FileExtension, LatestPublishedVersionId, CreatedDate, CreatedById
                FROM ContentDocument
                WHERE Id IN :contentDocumentIds
            ];

        } catch (Exception e) {
            // En cas d'erreur, on renvoie une liste vide dans res.documents
        }

        return new List<Response>{ res };
    }
}