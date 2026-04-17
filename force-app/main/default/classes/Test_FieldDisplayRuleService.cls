@isTest
public class Test_FieldDisplayRuleService {
 
    @IsTest
    static void test_getRulesForObject() {

        Test.startTest();
        List<FieldDisplayRuleService.FieldRuleDTO> csData = FieldDisplayRuleService.getRulesForObject('ProjectShareclassChild__c');
        List<FieldDisplayRuleService.FieldRuleDTO> prodData = FieldDisplayRuleService.getRulesForObject('ProjectProductChild__c');

        Test.stopTest();
        system.assertNotEquals(0, csData.size());
        system.assertNotEquals(0, prodData.size());
    }
}