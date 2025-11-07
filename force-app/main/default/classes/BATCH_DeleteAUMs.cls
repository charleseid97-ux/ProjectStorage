/**
 * @description       : In order to delete AUM of last Month , sould be run once time a month.
 * @author            : Thanina YAYA
 * @last modified on  : 21-12-2023
 * @last modified by  : Thanina YAYA
**/
public without sharing class BATCH_DeleteAUMs implements Database.Batchable<SObject> {
    public static String query='select Id, Date__c, CreatedDate from AUM__c where Date__c = LAST_MONTH';

    public Database.QueryLocator start(Database.BatchableContext bc)
    {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<AUM__c> aumToDel)
    {
            if(aumToDel.size()> 0) delete aumToDel;
    }

    public void finish(Database.BatchableContext bc){
        // execute any post-processing operations
        System.debug('@@@End Batch Delete All AUMs------');
    }
}