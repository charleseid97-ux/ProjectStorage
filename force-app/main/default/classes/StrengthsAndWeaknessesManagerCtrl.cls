global without sharing class StrengthsAndWeaknessesManagerCtrl {
    
    @AuraEnabled
    global static Strengths_and_Weaknesses__c loadPlanWeakness(String objectId) {
        Strengths_and_Weaknesses__c SandW = [SELECT Name, Weakness__c, Weakness_Type__c FROM Strengths_and_Weaknesses__c WHERE Id =: objectId];
        return SandW;
    }
    
    @AuraEnabled
    global static Strengths_and_Weaknesses__c loadPlanStrength(String objectId) {
        Strengths_and_Weaknesses__c SandW = [SELECT Name, Strength__c, Strength_Type__c FROM Strengths_and_Weaknesses__c WHERE Id =: objectId];
        return SandW;
    }
    
	@AuraEnabled
    global static Strengths_and_Weaknesses__c saveStrength(String parentRecordId, String currentObjectId, String strength, String strengthType){
        Strengths_and_Weaknesses__c SandW = new Strengths_and_Weaknesses__c();
        if(currentObjectId == null) {
            SandW.Account_Plan__c = parentRecordId;
        } else {
            SandW = [SELECT Name, Strength__c FROM Strengths_and_Weaknesses__c WHERE Id =: currentObjectId];
        }
        SandW.Strength__c = strength;
        SandW.Strength_Type__c = strengthType;
        
        try {
            upsert SandW;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());    
        }
        return SandW;
    }
    @AuraEnabled
    global static Strengths_and_Weaknesses__c saveWeakness(String parentRecordId, String currentObjectId, String weakness, String weaknessType){
        Strengths_and_Weaknesses__c SandW = new Strengths_and_Weaknesses__c();
        if(currentObjectId == null) {
            SandW.Account_Plan__c = parentRecordId;
        } else {
            SandW = [SELECT Name, Weakness__c FROM Strengths_and_Weaknesses__c WHERE Id =: currentObjectId];
        }
        SandW.Weakness__c = weakness;
        SandW.Weakness_Type__c = weaknessType;
        
        try {
            upsert SandW;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());    
        }
        return SandW;
    }
    
    @AuraEnabled
    public static List < String > getselectOptions(sObject objObject, string fld) {
		return AccountUtil.getselectOptions(objObject, fld);
	}
}