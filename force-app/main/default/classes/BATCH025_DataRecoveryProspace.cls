public class BATCH025_DataRecoveryProspace implements Database.Batchable<sObject>, schedulable {
    
	public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT id FROM Web_Communication__c WHERE Contact__c = null AND Lead__c = null';
        return Database.getQueryLocator(query);
    }

    public void execute(System.SchedulableContext sc) {
        BATCH025_DataRecoveryProspace batch = new BATCH025_DataRecoveryProspace();
        Database.executeBatch(batch);
    }
    
    public void execute(Database.BatchableContext BC, List<Web_Communication__c> prospaceAlerts) {
        if (prospaceAlerts.size() > 0) {
            Database.delete(prospaceAlerts, false);
        }
    }
    
	public void finish(Database.BatchableContext BC) {
        
    }    
}