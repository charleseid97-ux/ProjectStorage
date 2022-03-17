({
	init : function(component, event, helper) {
		helper.getCompany(component);
	},
    deactivateCompany : function(component, event, helper) {
        if(confirm('Are you sure you want to Deactivate this Company?')) {
	        helper.deactivateCompany(component);
        }
    },
    convertProspect : function(component, event, helper) {
        if(confirm('Are you sure you want to convert this Company to a Prospect?')) {
	        helper.convertProspect(component);
        }
    },
    cancelDeactivate : function(component, event, helper) {
        var closeAction = $A.get("e.force:closeQuickAction");
        closeAction.fire();
    }
})