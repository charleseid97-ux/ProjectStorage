/**
*@Author AlphaFMC
*@Date 2018
*
*@Group Meeting Notes
*
*@Description Trigger Handler on Meeting_Note__c that handles the generation and update of the MDM auto generated value
*/
public with sharing class MeetingNoteTH extends TriggerHandlerBase{
	
	public override Schema.sObjectType ObjectType()
	{
	  return Meeting_Note__c.getSObjectType();
	}

    public override void BeforeInsert(List<SObject> newItems){
    	
    }

	public override void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems){
		
	}

	public override void BeforeDelete(Map<Id, SObject> oldItems){
		
	}

	public override void AfterInsert(Map<Id, SObject> newItems){
	//insert CustomTopicsUtil.GetSObjectFieldsAsFeedItems(newItems, trigger.oldMap, new list<string>{'Note__c'});
				
	}

	public override void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems){
	//insert CustomTopicsUtil.GetSObjectFieldsAsFeedItems(newItems, oldItems, new list<string>{'Note__c'});
	}

	public override void AfterDelete(Map<Id, SObject> oldItems){
		
	}

	public override void AfterUndelete(Map<Id, SObject> oldItems){
		
	}
}