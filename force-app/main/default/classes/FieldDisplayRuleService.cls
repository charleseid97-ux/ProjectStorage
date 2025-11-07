public with sharing class FieldDisplayRuleService {
    @AuraEnabled(cacheable=true)
    public static List<FieldRuleDTO> getRulesForObject(String objectApiName) {
        if(objectApiName == 'ProjectShareclassChild__c'){
            objectApiName = 'Share_Class';
        } else if(objectApiName == 'ProjectProductChild__c'){
            objectApiName = 'Product';
        }
        List<FieldRuleDTO> results = new List<FieldRuleDTO>();
 
        for (FieldDisplayRule__mdt rule : [
            SELECT DeveloperName, Label, FieldApiName__c, ObjectApiName__c,
                   DisplayCondition__c,Mandatory_Rule__c
            FROM FieldDisplayRule__mdt
            WHERE ObjectApiName__c = :objectApiName
        ]) {
            results.add(new FieldRuleDTO(
                rule.DeveloperName,
                rule.FieldApiName__c+'__c',
                rule.DisplayCondition__c, 
                rule.Mandatory_Rule__c
            ));
        }
 
        return results;
    }
 
    public class FieldRuleDTO {
        @AuraEnabled public String developerName;
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String displayCondition;
        @AuraEnabled public String mandatoryCondition;
 
        public FieldRuleDTO(String devName, String fieldName, String cond, String mandCond) {
            this.developerName = devName;
            this.fieldApiName = fieldName;
            this.displayCondition = cond;
            this.mandatoryCondition = mandCond;
        }
    }
}