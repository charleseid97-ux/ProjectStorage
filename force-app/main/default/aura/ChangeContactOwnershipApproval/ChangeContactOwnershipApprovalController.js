({
    init: function(component, event, helper) {
        debugger;
        var currContact = ({"Name":"","OwnerId.FirstName":""});
        component.set("v.contact", currContact);
        var currentUserId = $A.get("$SObjectType.CurrentUser.Id");
        component.set("v.currentUserId", currentUserId);
    	helper.buildData(component);
    },
    approveCurrentCtrl : function(component, event, helper) {
        helper.approveCurrent(component);
    },
    approveProposedCtrl : function(component, event, helper) {
        helper.approveProposed(component);
    },
    rejectChange : function(component, event, helper) {
        helper.rejectChange(component);
    }
})