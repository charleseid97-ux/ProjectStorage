({	
	
	changeLookup : function(component) {
        var meetingNote = component.get("v.meetingNote")
        component.find('ownerLookup').set('v.value', meetingNote.OwnerId);
	},
    
    hideField : function(component, event, helper, fieldObj){
        $A.util.addClass(fieldObj, 'slds-hide');
        $A.util.removeClass(fieldObj, 'slds-show');
    },
    
    showField : function(component, event, helper, fieldObj){
        $A.util.removeClass(fieldObj, 'slds-hide');
        $A.util.addClass(fieldObj, 'slds-show');
    },
    
    setMeetingTypeForPurposeVisibility : function(component, event, helper) {
        var tt = component.find('MeetingType').get('v.value');
        if(component.find('MeetingType').get('v.value') == 'Event (Schedule)') {
            component.find("Purpose").set("v.value","");
            helper.hideField(component, event, helper, component.find('Purpose'));
        } else {
            helper.showField(component, event, helper, component.find('Purpose'));
        }
    }
})