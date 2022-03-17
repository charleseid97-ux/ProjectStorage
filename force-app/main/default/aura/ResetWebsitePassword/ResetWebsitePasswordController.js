({
	resetProspacePassword : function(component, event, helper) {
        var contactId = component.get("v.recordId");

        helper.resetWebsitePassword(component, event, helper, contactId);
	}
})