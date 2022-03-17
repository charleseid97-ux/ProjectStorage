({
	init : function(component, event, helper) {
        component.set("v.origRecordId", component.get("v.recordId"));
		helper.getAllPickListVals(component);
        helper.getHierarchyAccounts(component);
	},
    changeCompany : function(component, event, helper) {
        component.set("v.viewFull", false);
        component.set("v.recordId", event.getSource().get("v.value"));
        helper.getContactsForCompany(component);
    },
    renderToggle : function(component, event, helper) {
        debugger;
        if(component.get("v.viewFull") == true) {
	        helper.getContactsForHierarchy(component);
        } else {
            helper.getContactsForCompany(component);
        }
    }
})