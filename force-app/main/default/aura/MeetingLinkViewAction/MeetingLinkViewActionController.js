({
    handleRecordUpdated: function(component, event, helper) {
        var eventParams = event.getParams();
        if(eventParams.changeType === "LOADED") {
            
            var meetingLink = component.get("v.simpleRecord");
            var meetingNoteId = meetingLink.Meeting_Note__c;
            
            var sObjectEvent = $A.get("e.force:navigateToSObject");

            sObjectEvent.setParams({
                "recordId": meetingNoteId
            });
            
            sObjectEvent.fire();
            
        } else if(eventParams.changeType === "ERROR") {
            // there’s an error while loading, saving, or deleting the record
        }
    }
})