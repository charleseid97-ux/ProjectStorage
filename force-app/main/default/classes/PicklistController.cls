public with sharing class PicklistController {
    @AuraEnabled
    public static List < Map < String, String >> getPickListValues(String objApiName, String fieldName) {
        List < Map < String, String >> options = new List < Map < String, String >> ();

        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objApiName);

        if (objType == null) return options;

        Schema.DescribeSObjectResult sobjectDescribe = objType.getDescribe();

        Map < String, Schema.SObjectField > fieldMap = sobjectDescribe.fields.getMap();

        if (fieldMap.get(fieldName) == null) {
            return options;
        }
        List < Schema.PicklistEntry > pickListValues = fieldMap.get(fieldName).getDescribe().getPickListValues();

        for (Schema.PicklistEntry f : pickListValues) {
            Map < String, String > values = new Map < String, String >{
                    'label' => f.getLabel(),
                    'value' => f.getValue()
            };
            options.add(values);
        }
        return options;
    }

    @AuraEnabled
    public static List < Map < String, String >> getPickListValuesCustomContries(String objApiName, String fieldName) {

        List < Map < String, String >> options = getPickListValues(objApiName, fieldName);

        for(Integer i = 0; i < options.size(); i++){
            System.debug('//NGO : '+options.get(i).get('value'));
            if(options.get(i).get('value').equals('XI')) options.remove(i);
        }

        return options;
    }
}