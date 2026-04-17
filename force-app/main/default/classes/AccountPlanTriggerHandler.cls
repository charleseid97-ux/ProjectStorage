public class AccountPlanTriggerHandler {

    public static void beforeInsert(List<Account_Plan__c> accPlans) {
        for(Account_Plan__c ap : accPlans) {
		    List<Account_Plan__c> accPlanL = new List<Account_Plan__c>([SELECT Name, Id FROM Account_Plan__c WHERE Company__c =: ap.Company__c ORDER BY CreatedDate DESC]);
            if(accPlanL.size() > 0) {
	            ap.Previous_Account_Plan__c = accPlanL[0].Id;
            }
        }
    }
    
}