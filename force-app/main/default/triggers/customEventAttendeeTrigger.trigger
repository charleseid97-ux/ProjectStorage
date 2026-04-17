trigger customEventAttendeeTrigger on EventAttendee__c (
    after insert
) {
    TriggerDispatcher.Run(new customEventAttendeeHandler());
}