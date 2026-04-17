/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 06-19-2024
 * @last modified by  : SILA Nicolas
**/
@isTest
private class DependencyPicklistApexTest {
    
    @isTest
    static void testGetFieldDependencies() {
        // Create test data
        // Case parentCase = new Case(
        //     Subject = 'Parent Case',target_languages__c='Italian;English',Translation_Request_Type__c = 'Translation Only',
        //     RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Translation Request').getRecordTypeId()
        // );
        // insert parentCase;
        
        Test.startTest();
        Map<String, Set<String>> result = DependencyPicklistApex.getFieldDependencies('Case', 'Sub_Target_language__c','TargetWebsite__c');

        Test.stopTest();
        
        System.assertNotEquals(null, result, 'The method should return a non-null value');
        System.assertNotEquals(0, result.size(), 'The result map should not be empty');
        
        // Verify that the result map contains the expected controlling field values as keys
        Schema.DescribeFieldResult controllingFieldDescribe = Case.Sub_Target_language__c.getDescribe();
        List<Schema.PicklistEntry> controllingValues = controllingFieldDescribe.getPicklistValues();
        for (Schema.PicklistEntry entry : controllingValues) {
            System.assert(result.containsKey(entry.getValue()), 'The result map should contain the controlling field value "' + entry.getValue() + '" as a key');
        }
        
        // Verify that the result map contains the expected dependent field values as values
        Schema.DescribeFieldResult dependentFieldDescribe = Case.TargetWebsite__c.getDescribe();
        List<Schema.PicklistEntry> dependentValues = dependentFieldDescribe.getPicklistValues();
        Set<String> allDependentValues = new Set<String>();
        for (Schema.PicklistEntry entry : dependentValues) {
            allDependentValues.add(entry.getLabel());
        }
        
        for (Set<String> dependentValuesSet : result.values()) {
            for (String dependentValue : dependentValuesSet) {
                System.assert(allDependentValues.contains(dependentValue), 'The dependent field value "' + dependentValue + '" should be present in the result map values');
            }
        }
    }
}