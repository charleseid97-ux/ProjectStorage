/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 05-23-2024
 * @last modified by  : SILA Nicolas
**/
public class DependencyPicklistApex {
    
    public static Map<String, Set<String>> getFieldDependencies(String objectName, String controllingField, String dependentField) {
        Map<String, Set<String>> controllingInfo = new Map<String, Set<String>>();
        
        // Get the object type from the global describe
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        if (objType == null) {
            System.debug('Object not found: ' + objectName);
            return controllingInfo;
        }
        
        Schema.DescribeSObjectResult describeResult = objType.getDescribe();
        
        // Get the describe result for controlling and dependent fields
        Schema.DescribeFieldResult controllingFieldInfo = describeResult.fields.getMap().get(controllingField).getDescribe();
        Schema.DescribeFieldResult dependentFieldInfo = describeResult.fields.getMap().get(dependentField).getDescribe();
        
        List<Schema.PicklistEntry> controllingValues = controllingFieldInfo.getPicklistValues();
        List<Schema.PicklistEntry> dependentValues = dependentFieldInfo.getPicklistValues();
        
        // Initialize the map with controlling field values
        for (Schema.PicklistEntry currControllingValue : controllingValues) {
            controllingInfo.put(currControllingValue.getValue(), new Set<String>());
        }
        
        // Process each dependent value
        for (Schema.PicklistEntry currDependentValue : dependentValues) {
           
            String jsonString = JSON.serialize(currDependentValue);
            MyPickListInfo info = (MyPickListInfo) JSON.deserialize(jsonString, MyPickListInfo.class);
            String hexString = EncodingUtil.convertToHex(EncodingUtil.base64Decode(info.validFor));
            Integer baseCount = 0;
            for (Integer curr : hexString.getChars()) {
                Integer val = (curr >= 65) ? (curr - 65 + 10) : (curr - 48);
                
                // Add checks to ensure the baseCount doesn't go out of bounds
                if (baseCount + 0 < controllingValues.size() && (val & 8) == 8) {
                    controllingInfo.get(controllingValues[baseCount + 0].getValue()).add(currDependentValue.getLabel());
                }
                if (baseCount + 1 < controllingValues.size() && (val & 4) == 4) {
                    controllingInfo.get(controllingValues[baseCount + 1].getValue()).add(currDependentValue.getLabel());
                }
                if (baseCount + 2 < controllingValues.size() && (val & 2) == 2) {
                    controllingInfo.get(controllingValues[baseCount + 2].getValue()).add(currDependentValue.getLabel());
                }
                if (baseCount + 3 < controllingValues.size() && (val & 1) == 1) {
                    controllingInfo.get(controllingValues[baseCount + 3].getValue()).add(currDependentValue.getLabel());
                }
                
                baseCount += 4;
            }            
        } 
        
        System.debug(controllingInfo);
        return controllingInfo;
    }
    
    public class MyPickListInfo {
        public String validFor;
    }
}