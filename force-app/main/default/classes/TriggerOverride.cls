/**
 * @author Mike Egar
 * @date 07/06/2018
 * @description Responisble for querying and managing the state of trigger overrides. This is used at a hanlder level throughout the framework
 */
public with sharing class TriggerOverride {

    @TestVisible private static Boolean testLock = false;
    @TestVisible private static BeforeOrAfter testBeforeOrAfter;
    @TestVisible private static TriggerEvent testEvent;

    /*
     *  Custom Metadata enumerations
     */
    public enum BeforeOrAfter {ISBEFORE, ISAFTER}
    public enum TriggerEvent {ISUPDATE, ISINSERT, ISDELETE, ISUNDELETE}

    /*
     *  Override maps for Custom Metdata query and map of state before programmatic override
     */
    private map<String, Boolean> TriggerOldStateMap = new map<String, Boolean>();
    private static Map <String, Boolean> TriggerOverrideMap;

    /*
     *  Determine if trigger is disabled for a given ObjectType
     */
    public Boolean IsDisabled(Schema.sObjectType objectType)
    {
        String key = getKey(objectType);

        return TriggerOverrideMap().get(key);
    }
    /*
     *  Disable a trigger for a specific event and before/after trigger
     */
    public void disable(Schema.sObjectType objectType, BeforeOrAfter beforeOrAfter, TriggerEvent event)
    {
        String key = getKey(objectType, beforeOrAfter, event);

        Boolean overridenTriggerValue = TriggerOverrideMap().get(key);

        if (overridenTriggerValue != null) {

            TriggerOldStateMap.put(key, overridenTriggerValue);
        }else{
            TriggerOldStateMap.put(key, false);
        }

        TriggerOverrideMap().put(key, true);
    }

    /*
     *  Restore a trigger for a specific event and before/after trigger
     */
    public void restore(Schema.sObjectType objectType, BeforeOrAfter beforeOrAfter, TriggerEvent event)
    {

        String key = getKey(objectType, beforeOrAfter, event);

        Boolean oldState = TriggerOldStateMap.get(key);

        TriggerOverrideMap().put(key, oldState);

    }

    /*
     *  Query the Custom Metadata of trigger overrides
     */
    private Map <String, Boolean> TriggerOverrideMap()
    {

        if (TriggerOverrideMap == null)
        {
            TriggerOverrideMap = new Map <String, Boolean>();

            List <Trigger_Override__mdt> overrides =
            [Select Id, Event__c, Before_Or_After__c, Override__c, Object_Type__c
             from Trigger_Override__mdt];

            for (Trigger_Override__mdt triggerOverride : overrides) {
                TriggerOverrideMap.put(getKey(triggerOverride), triggerOverride.Override__c);
            }
        }

        return TriggerOverrideMap;
    }
    /*
     *  Construct a key for the map from a Custom Metadata record
     */
    private String getKey(Trigger_Override__mdt triggerOverride){

        return triggerOverride.Object_Type__c + triggerOverride.Before_Or_After__c + triggerOverride.Event__c;
    }
    /*
     *  Construct a key for the map from a given ObjectType and event
     */
    private String getKey(Schema.sObjectType objectType, BeforeOrAfter beforeOrAfter, TriggerEvent event){

        return String.valueOf(objectType) + beforeOrAfter + event;
    }
    /*
     *  Construct a key for the map from a given ObjectType using the Trigger context to determine the remaining data points
     */
    private String getKey(Schema.sObjectType objectType){
        TriggerEvent event;
        BeforeOrAfter beforeAfter;

        if ((testLock && testEvent == TriggerEvent.ISINSERT) || (!testLock && Trigger.isInsert)) {
            event = TriggerEvent.ISINSERT;
        }else if ((testLock && testEvent == TriggerEvent.ISUPDATE) || (!testLock && Trigger.isUpdate)) {
            event = TriggerEvent.ISUPDATE;
        }else if ((testLock && testEvent == TriggerEvent.ISDELETE) || (!testLock && Trigger.isDelete)) {
            event = TriggerEvent.ISDELETE;
        }else if ((testLock && testEvent == TriggerEvent.ISUNDELETE) || (!testLock && Trigger.isUndelete)) {
            event = TriggerEvent.ISUNDELETE;
        }

        if ((testLock && testBeforeOrAfter == BeforeOrAfter.ISBEFORE)
            || (!testLock && Trigger.isBefore == true))
        {
            beforeAfter = BeforeOrAfter.ISBEFORE;
        } else if ((testLock && testBeforeOrAfter == BeforeOrAfter.ISAFTER)
                   || (!testLock && Trigger.isAfter == true))
        {
            beforeAfter = BeforeOrAfter.ISAFTER;
        }

        return String.valueOf(objectType) + beforeAfter + event;
    }
}