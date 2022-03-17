/**
* @author JLC
* @date 02/03/2022
* @description Schedule for the batch to count the legal Entities on Company and update the field Number_Of_Legal_Entities__c
* @see BATCH018_CountLegalEntCompany
*/
global class SCH_BATCH018_CountLegalEntCompany implements Schedulable{

    global void execute(SchedulableContext sc){

        BATCH018_CountLegalEntCompany b = new BATCH018_CountLegalEntCompany();
        Database.executeBatch(b);

    }
}