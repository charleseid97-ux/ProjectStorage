trigger EventSpeakerApprovalsTrigger on EventSpeakerApprovals__c (
    before insert,
    before update,
    after insert,
    after update
) {
    TriggerDispatcher.run(new EventSpeakerApprovalsTriggerHandler());
}