public with sharing class ProjectFeederController {
    public class FeederLineDTO {
        @AuraEnabled public Id shareclassId;
        @AuraEnabled public String shareclassName;
        @AuraEnabled public Id feederId;
        @AuraEnabled public String feederName;

        public FeederLineDTO(ProjectShareclass__c psc) {
            shareclassId = psc.Id;
            shareclassName = psc.Share_Class_Name__c;
            feederId = psc.Feeder__c;
            feederName = (psc.Feeder__r != null) ? psc.Feeder__r.ProductName__c : null;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FeederLineDTO> getFeeders(Id projectId) {
        if (projectId == null) return new List<FeederLineDTO>();

        // ⚠️ Remplace Project__c par le vrai lookup vers Project si différent
        List<ProjectShareclass__c> rows = [
            SELECT Id, Share_Class_Name__c, Feeder__c, Feeder__r.ProductName__c
            FROM ProjectShareclass__c
            WHERE ProjectProduct__c = :projectId
              AND Feeder__c != null
            ORDER BY Name
        ];

        List<FeederLineDTO> out = new List<FeederLineDTO>();
        for (ProjectShareclass__c r : rows) out.add(new FeederLineDTO(r));
        return out;
    }
}