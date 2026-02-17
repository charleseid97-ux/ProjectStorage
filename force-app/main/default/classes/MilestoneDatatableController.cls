public without sharing class MilestoneDatatableController {
    
    @AuraEnabled(cacheable=true)
    public static List<Milestone__c> getMilestones(Id parentId) {
        return [
            SELECT Id, Name, StartDate__c, Status__c, Project_product__c, RAG__c
            FROM Milestone__c
            WHERE Project_product__c = :parentId
            ORDER BY StartDate__c
        ];
    }
 
    @AuraEnabled(cacheable=true)
    public static List<String> getStatusPicklistValues() {
        List<String> values = new List<String>();
        Schema.DescribeFieldResult fieldResult = Milestone__c.Status__c.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry entry : picklistEntries) {
            values.add(entry.getValue());
        }
        return values;
    }
 
    @AuraEnabled
    public static List<Milestone__c> updateMilestones(List<Milestone__c> updatedRecords) {
        try {
            // Effectuer la mise à jour — si une VR/addError bloque, on attrapera le DmlException
            update updatedRecords;

            // Renvoie les enregistrements fraîchement mis à jour
            return [
                SELECT Id, Name, StartDate__c, Status__c, Project_product__c, RAG__c
                FROM Milestone__c
                WHERE Id IN :updatedRecords
            ];
        } catch (DmlException e) {
            // Récupérer tous les messages DML (inclut addError / validation rule messages)
            List<String> msgs = new List<String>();
            Integer count = e.getNumDml();
            for (Integer i = 0; i < count; i++) {
                msgs.add(e.getDmlMessage(i));
            }

            // Si, pour une raison quelconque, on n'a rien, fallback sur e.getMessage()
            String joined = msgs.isEmpty() ? e.getMessage() : String.join(msgs, ' | ');

            // Renvoyer une exception manipulable côté client (LWC)
            throw new AuraHandledException(joined);
        } catch (Exception ex) {
            // Défaut : renvoyer message lisible
            throw new AuraHandledException(ex.getMessage());
        }
    }

}