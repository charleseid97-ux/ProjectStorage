({
    init : function(component, event, helper) {
        helper.fetchPickListVal(component, 'Weakness_Type__c', 'weaknessType');
        
        var recId = component.get('v.parentObjectId');
        if(component.get('v.mode') == 'EDIT') {
            component.set("v.headerLabel", "Edit Weakness");
            helper.loadWeakness(component, component.get('v.currentObjectId'));
        } else {
            var curObj;
            curObj = {Company__c: recId,
                      Weakness__c: ''};
            component.set('v.strengthsAndWeaknesses', curObj);
        }
    },
    closeComponent : function(component, event, helper) {
		component.set('v.viewCustomObjectManagement', false);
	},
	saveComponent : function(component, event, helper) {
        helper.saveWeakness(component);
	}
})