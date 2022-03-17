({
    
    initPickList: function(component,event, helper) {
        var contactId = component.get("v.recordId");
        helper.initPickList(component, event, helper, contactId);
        helper.initPickListPub(component, event, helper, contactId);

    },
    
    delAllAlerts : function(component, event, helper) {
        var contactId = component.get("v.recordId");
        var selectedAlertTypes = component.get("v.value");
        selectedAlertTypes.push.apply(selectedAlertTypes, component.get("v.valuePub"));
        
        helper.delAllProspaceAlerts(component, event, helper, contactId, selectedAlertTypes);
    },
    
    handleChange: function (component, event) {
        var button = component.find("buttonAdd");
        button.set("v.disabled", "false");
    },
    
    handleCancel: function (component, event) {
        var contactId = component.get("v.recordId");
        sforce.one.navigateToSObject(contactId);
        
    }
})