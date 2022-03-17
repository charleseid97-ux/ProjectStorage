({
    init : function(component, event, helper) {
        debugger;
        if(component.get('v.GAMId')==null || component.get('v.GAMId')=='') {
            component.set('v.GAMId', component.get('v.recordId'));
            component.set('v.viewOppDashComponent', true);
        }
    },
	closeComponent : function(component, event, helper) {
		component.set('v.viewOppDashComponent', false);
	}
})