/**
* @author JLC
* @date 02/03/2022
* @description Count the legal Entities on Company and update the field Number_Of_Legal_Entities__c
*/
global class BATCH018_CountLegalEntCompany implements Database.Batchable<AggregateResult> {

    // The batch job starts
    global Iterable<AggregateResult> start(Database.BatchableContext bc) {

        String query = 'SELECT COUNT(Id), Company__c FROM Legal_Entity__c WHERE Company__c != NULL GROUP BY Company__c';
        return new AggregateResultIterable(query);
    }

    // The batch job executes and operates on one batch of records
    global void execute(Database.BatchableContext bc, List<SObject> scope) {

        List<Account> companyToUpdateList = new List<Account>();

        //Get the Aggregate values and put the Company Id and the aggregate number in a Map
        for (SObject sObj : scope) {
            AggregateResult ar = (AggregateResult) sObj;
            Integer numberOfLegalEntity = (Integer) ar.get('expr0');
            if(numberOfLegalEntity > 1) companyToUpdateList.add(new Account(Id = (Id) ar.get('Company__c'), Number_Of_Legal_Entities__c = numberOfLegalEntity));
        }

        //Update the Company List
        if (companyToUpdateList.size() > 0) Database.update(companyToUpdateList, false);

    }

    // The batch job finishes
    global void finish(Database.BatchableContext bc) {
    }
}