({
	returnInterestedParties : function(component) {
		var action = component.get('c.opportunityParties');
        action.setParams({oppId : component.get('v.recordId')});
        action.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                var resp = actionResult.getReturnValue();
                debugger;
                component.set('v.opportunity', resp);
                component.set('v.interestedPartners', resp.Opportunity_Interested_Partners__r)
            }
        });
        $A.enqueueAction(action);
	},
    loadConvertOpp : function(component, idFromList) {
		var action = component.get('c.convertOpportunity');

        action.setParams({
            opp : component.get('v.opportunity'),
            oIPId : idFromList
        });
        action.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                var resp = actionResult.getReturnValue();
                
                var navEvt = $A.get("e.force:navigateToSObject");
                navEvt.setParams({
                    "recordId": resp.Id
                });
                navEvt.fire();
            }
        });
        $A.enqueueAction(action);
    }
})