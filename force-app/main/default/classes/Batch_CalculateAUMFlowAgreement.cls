public class Batch_CalculateAUMFlowAgreement implements Database.Batchable<sObject>{
    
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id,Name,IS__c,RecordType.Name from Convention__c where Status__c != 'Terminated'
        ]);
    }
    
    public void execute(Database.BatchableContext BC, List<Convention__c> scope) {
        Set<Id> agreementIds = new Set<Id>();
        for(Convention__c conv : scope) {
            agreementIds.add(conv.Id);
        }
        
        List<AggregateResult> resultsAUM = [
            SELECT Convention__c, sum(AmountEUR__c) totalAUM
            FROM AUM__c 
            WHERE Convention__c IN :agreementIds AND Last_AUM__c = true
            GROUP BY Convention__c
        ];
        
        List<AggregateResult> resultsFlows = [
            SELECT Agreement__c, SUM(AmountEUR__c) totalFlow
            FROM Flow__c 
            WHERE Agreement__c IN :agreementIds AND ValueDate__c = THIS_YEAR
            GROUP BY Agreement__c
        ];
        
        Map<Id, Decimal> aumMap = new Map<Id, Decimal>();
        Map<Id, Decimal> flowMap = new Map<Id, Decimal>();
        
        for (AggregateResult ar : resultsAUM) {
            Id conventionId = (Id)ar.get('Convention__c');
            Decimal totalAUM = (Decimal)ar.get('totalAUM');
            aumMap.put(conventionId, totalAUM);
        }
        
        for (AggregateResult ar : resultsFlows) {
            Id agreementId = (Id)ar.get('Agreement__c');
            Decimal totalFlow = (Decimal)ar.get('totalFlow');
            flowMap.put(agreementId, totalFlow);
        }
        
        List<Convention__c> agreementsToUpdate = new List<Convention__c>();
        
        for (Convention__c conv : scope) {
            Decimal aumValue = aumMap.get(conv.Id);
            Decimal flowValue = flowMap.get(conv.Id);
            system.debug('Id : '+conv.Id);
            system.debug('name : '+conv.Name);
            system.debug('is Code : '+conv.IS__c);
            system.debug('recTypeId : '+conv.RecordType.Name);
            
                conv.AUM_To_Date__c = aumValue != null ? aumValue : 0;
                conv.YTDNetFlows__c = flowValue != null ? flowValue : 0;
                agreementsToUpdate.add(conv);
            
        }
        
        if (!agreementsToUpdate.isEmpty()) {
            update agreementsToUpdate;
        }
    }
    
    public void finish(Database.BatchableContext BC) {
       
    }
}