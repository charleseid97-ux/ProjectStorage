/**
* @author Mike Egar
* @date 07/06/2018
* @description This class implements the ITriggerHandler interface to provide a concrete implementation of the override logic
*/
public with sharing abstract class TriggerHandlerBase implements ITriggerHandler{

    protected abstract Schema.sObjectType ObjectType();

    /*
    *   Check to see if the trigger is overriden in the custom metadata settings or programmatically
    */
    public virtual Boolean IsDisabled()
    {
        return TriggerOverrideInstance.IsDisabled(ObjectType());
    }

    /*
    *   Trigger methods to be implemented by the calling Trigger Handler
    */
    public abstract void BeforeInsert(List<SObject> newItems);

    public abstract void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems);

    public abstract void BeforeDelete(Map<Id, SObject> oldItems);

    public abstract void AfterInsert(Map<Id, SObject> newItems);

    public abstract void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems);

    public abstract void AfterDelete(Map<Id, SObject> oldItems);

    public abstract void AfterUndelete(Map<Id, SObject> oldItems);

    /*
    *   Return a class level instance of the TriggerOverride object
    */
    private TriggerOverride TriggerOverrideInstance{
        get{
            if (TriggerOverrideInstance == null) {
                TriggerOverrideInstance = new TriggerOverride();
            }
            return TriggerOverrideInstance;
        }
        private set;
    }
}