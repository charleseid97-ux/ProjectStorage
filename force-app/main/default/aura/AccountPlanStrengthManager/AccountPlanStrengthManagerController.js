({
    init : function(component, event, helper) {
        helper.fetchPickListVal(component, 'Strength_Type__c', 'strengthType');
        
        var recId = component.get("v.parentObjectId");
        if(component.get('v.mode') == 'EDIT') {
            component.set("v.headerLabel", "Edit Strength");
            helper.loadStrength(component, component.get('v.currentObjectId'));
        } else {
            component.set("v.headerLabel", "New Strength");
            var curObj;
            curObj = {Company__c: recId,
                      Strength__c: ''};
            component.set('v.strengthsAndWeaknesses', curObj);
        }
    },
    closeComponent : function(component, event, helper) {
		component.set('v.viewCustomObjectManagement', false);
	},
	saveComponent : function(component, event, helper) {
        helper.saveStrength(component);
	}
})