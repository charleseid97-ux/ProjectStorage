({
	syncContactToWebsite : function(component, event, helper) {
        var contactId = component.get("v.recordId");

        helper.syncWebsiteContact(component, event, helper, contactId);
	}
})