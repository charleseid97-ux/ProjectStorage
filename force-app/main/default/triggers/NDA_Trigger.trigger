/**
 * Created by MNFR user on 30/06/2022.
 */

trigger NDA_Trigger on NDA__c (before update, after update) {
    TriggerDispatcher.run(new NDA_TriggerHandler());
}