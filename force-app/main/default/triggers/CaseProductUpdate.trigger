trigger CaseProductUpdate on Case_Product__c (before update, before insert) {
    
    //First we use this IF statement to make sure that the following code is only ever run before inserting or updating.
    //If, for example, the trigger is modified in the future to handle Deletes eg (before update, before insert, after delete)
    //then the following code will not be run. It creates a nice way to separate blocks for different database transactions.
    //for Delete specific code you would have an : if(trigger.isAfter && trigger.isDelete) : to make sure the code is only run after deleting a record
    if(trigger.isBefore && (trigger.isInsert || trigger.isUpdate)) {

        //We will query the ISIN__c from all Carmignac Product records in the system
        List<CarmignacProduct__c> carmignacProducts = [SELECT Id, ISIN__c FROM CarmignacProduct__c];
        //Create an empty MAP to store the ISIN__c and the Id
        MAP<String, Id> carmignacProductISINMAP = new MAP<String, Id>();
        
        //we then loop through all Carmignac Products
        for(CarmignacProduct__c cp : carmignacProducts) {
            //and add the ISIN__c and the Id to the MAP
            carmignacProductISINMAP.put(cp.ISIN__c, cp.Id);
        }
        
        //then we do the same for all the Share Classes
        List<Share_Class__c> shareClasses = [SELECT Id, ISIN_Code__c FROM Share_Class__c];
        //and create an empty MAP to hold them
        MAP<Id, String> shareClassISINMAP = new MAP<Id, String>();
        
        for(Share_Class__c shc : shareClasses) {
            //but here we will reverse the order and store the Id first then the ISIN_Code__c
            shareClassISINMAP.put(shc.Id, shc.ISIN_Code__c);
        }
        
        //We loop over all records in the trigger
        for(Case_Product__c  oa : trigger.new) {
            //here we set the Carmignac Product field. 
            //We first search the shareClassISINMAP using the Id of the linked share class. This will return the ISIN from the map.
            //Then we search for the Carmignac Product Id using the Share Class ISIN - and set the Id to the field.
            oa.Carmignac_Product__c = carmignacProductISINMAP.get(shareClassISINMAP.get(oa.Share_Class__c));
            oa.ShareClass__c = oa.Share_Class__c + '' + oa.Work_Together_Process__c;
        }
	}    
}