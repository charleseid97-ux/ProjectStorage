({
	init : function(component, event, helper) {
        helper.fetchPickListVal(component, 'Threat_Type__c', 'threatType');
        
        var recId = component.get('v.parentObjectId');
        if(component.get('v.mode') == 'EDIT') {
            component.set("v.headerLabel", "Edit Threat");
            helper.loadThreat(component, component.get('v.currentObjectId'));
        } else {
            var curObj = {Company__c: recId,
                      Threat__c: ''};
            component.set('v.threat', curObj);
        }
    },
    closeComponent : function(component, event, helper) {
		component.set('v.viewCustomObjectManagement', false);
	},
	saveComponent : function(component, event, helper) {
        helper.saveThreat(component);
	}
})