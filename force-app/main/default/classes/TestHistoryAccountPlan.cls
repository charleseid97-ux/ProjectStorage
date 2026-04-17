@isTest
public class TestHistoryAccountPlan {
    
    static Account_Plan__c getTestAccountPlan(){
        Account_Plan__c ap = new Account_Plan__c(Name = 'Test Account Plan', Company__c = '0015800001N4VhIAAV');

        insert ap;
        return ap;
    }
    
    public static testmethod void doTest() {
        Account_Plan__c ap = getTestAccountPlan();
        HistoryAccountPlan.getHistoryAccountPlan(ap.Id);
    }
}