public class FundManagerTriggerHandler {
    
    public static void handleBeforeInsert(List<Fund_Manager__c> newFundManagers) {
		//Get the ID of the 'Fund' Record Type in the Product Module - will be used to filter the products later
		Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
        
        //Create empty Map to store the Name and the Id of all the Funds in the Product object
        MAP<String, Id> fundMap = new Map<String, Id>();
        
        //Query and loop over all Products where the Record Type = fundRecordTypeId (returns all Funds)
        for(Product__c pF : [SELECT Id, Name FROM Product__c WHERE RecordTypeId =: fundRecordTypeId]) {
            //Add each Fund to the Map
            fundMap.put(pF.Name, pF.Id);
        }
        
        //Loop over every new Fund Manger being saved via the trigger
        for(Fund_Manager__c fM : newFundManagers) {
            //Look in the FundMap for a key matching the Name of the Fund in the SAM_Code field
            if(fundMap.get(fM.SAM_Code__c)!=null) {
                //If a match is found in the Map then set the FundManager.Product.Id to the value of the Map - which is the Id of the Fund
                fM.Product__c = fundMap.get(fM.SAM_Code__c);
            }
        }
        
    }
}