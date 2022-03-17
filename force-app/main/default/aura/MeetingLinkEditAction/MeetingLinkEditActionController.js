({
    handleRecordUpdated: function(component, event, helper) {
        var eventParams = event.getParams();
        if(eventParams.changeType === "LOADED") {
        	
        	var meetingLink = component.get("v.simpleRecord");
        	var meetingNoteId = meetingLink.Meeting_Note__c;
        	
		    var editRecordEvent = $A.get("e.force:editRecord");
		    editRecordEvent.setParams({
		         "recordId": meetingNoteId
		    });
		    editRecordEvent.fire();
        	
        } else if(eventParams.changeType === "ERROR") {
            // there’s an error while loading, saving, or deleting the record
        }
    }
})