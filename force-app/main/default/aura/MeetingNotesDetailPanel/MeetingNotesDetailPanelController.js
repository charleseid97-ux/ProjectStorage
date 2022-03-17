({
	init : function(component, event, helper) {
		if(component.get('v.meetingNote')){
			component.find("MeetingType").set("v.value",component.get('v.meetingNote').Meeting_Type__c);
        	component.find("Purpose").set("v.value",component.get('v.meetingNote').Purpose__c);
            //helper.setMeetingTypeForPurposeVisibility(component, event, helper);
		}		
	},
    
   	changeLookup : function(component, event, helper) {
		helper.changeLookup(component);
	},

	//Lightning Data Services handlers
	
    handleRecordUpdated: function(component, event, helper) {
    	
        var eventParams = event.getParams();

        if(eventParams.changeType === "LOADED") {
        	var targetFields = component.get("v.mNote");
            
        	component.find("MeetingType").set("v.value",targetFields.Meeting_Type__c);
            component.set("v.meeting_Note__c.Meeting_Type__c", targetFields.Meeting_Type__c);
        	component.find("Purpose").set("v.value",targetFields.Purpose__c);
        	
        } else if(eventParams.changeType === "ERROR") {
            // there’s an error while loading, saving, or deleting the record
        }
    },
    
    setMeetingTypeForPurposeVisibility : function(component, event, helper) {
        var meetingTypeError = component.find("meetingTypeError");
        helper.hideField(component, event, helper, meetingTypeError);
        
        //helper.setMeetingTypeForPurposeVisibility(component, event, helper);
    },
    setMeetingPurposeErrorVisbility : function(component, event, helper) {
        var meetingPurposeError = component.find("meetingPurposeError");
        helper.hideField(component, event, helper, meetingPurposeError);
    }

})