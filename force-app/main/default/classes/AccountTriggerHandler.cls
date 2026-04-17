public class AccountTriggerHandler {
    
    public static void handleBeforeDelete(Map<Id, Account> oldAccountMap) {
        /* Test if there are Agreement link to the account  */
        for(Convention__c agreement : [SELECT id, Company__c FROM Convention__c WHERE Company__c IN :oldAccountMap.keySet()]){
            oldAccountMap.get(agreement.company__c).addError('You can not delete an Account whose related to Agreement.', false);
        }
    }
}