public with sharing class NarrativeTriggerHandler
    extends TriggerHandlerBase
{
    /**
     * Returns the Salesforce object handled by this class.
     */
    protected override Schema.SObjectType ObjectType() {
        return Narrative__c.SObjectType;
    }

    /**
     * Populates the External ID before record creation.
     */
    public override void BeforeInsert(
        List<SObject> newItems
    ) {
        GenericExternalIdService.populate(
            newItems,
            'ExternalID__c'
        );
    }

    /**
     * Populates the External ID before record update
     * when the field is blank.
     */
    public override void BeforeUpdate(
        Map<Id, SObject> newItems,
        Map<Id, SObject> oldItems
    ) {
        List<SObject> recordsToProcess =
            new List<SObject>();

        for (Id recordId : newItems.keySet()) {
            recordsToProcess.add(
                newItems.get(recordId)
            );
        }

        GenericExternalIdService.populate(
            recordsToProcess,
            'ExternalID__c'
        );
    }

    /**
     * This context is not used by this handler.
     */
    public override void BeforeDelete(
        Map<Id, SObject> oldItems
    ) {}

    /**
     * This context is not used by this handler.
     */
    public override void AfterInsert(
        Map<Id, SObject> newItems
    ) {}

    /**
     * This context is not used by this handler.
     */
    public override void AfterUpdate(
        Map<Id, SObject> newItems,
        Map<Id, SObject> oldItems
    ) {}

    /**
     * This context is not used by this handler.
     */
    public override void AfterDelete(
        Map<Id, SObject> oldItems
    ) {}

    /**
     * This context is not used by this handler.
     */
    public override void AfterUndelete(
        Map<Id, SObject> newItems
    ) {}
}
