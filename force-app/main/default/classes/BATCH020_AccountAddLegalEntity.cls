public class BATCH020_AccountAddLegalEntity implements Database.Batchable<sObject> {
    
	public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Company__c FROM Legal_Entity__c where Company__c != null ORDER BY Id';
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext BC, list<Legal_Entity__c> legalEntities) {
        Map<Id, Id> accountsWithLe = new Map<Id, Id>();
        for (Legal_Entity__c le : legalEntities) {
            if (!accountsWithLe.containsKey(le.Company__c)) {
                accountsWithLe.put(le.Company__c, le.Id);
            }
        }
        List<Id> accIds = new List<Id>(accountsWithLe.keySet());
        List<Account> accToUpdate = new List<Account>([Select Id, LegalEntity__c from Account where id in :accIds]);
        for (Account acc : accToUpdate) {
            acc.LegalEntity__c = accountsWithLe.get(acc.Id);
        }
        update accToUpdate;
    }
    
	public void finish(Database.BatchableContext BC) {
        
    }    
}