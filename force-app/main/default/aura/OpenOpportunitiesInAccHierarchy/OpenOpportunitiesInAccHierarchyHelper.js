({
    // Fetch the accounts from the Apex controller
    getOpenOpportunityList: function(component) {      
        var accPlanId = component.get("v.recordId");   
        var actionOpp = component.get("c.getOpenOpportunities");
        // Set up the callback/
        debugger;
        if(accPlanId!=null) {
            if(accPlanId.startsWith('001')) {
                component.set('v.isAccount', true);
            }
        }
        
        if(component.get('v.organisationId')!=null) {
            accPlanId = component.get('v.organisationId');
        }
        
        actionOpp.setParams({"accountPlanId" : accPlanId});
        
        actionOpp.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                component.set('v.openOpportunities', actionResult.getReturnValue());
            }
        });
        $A.enqueueAction(actionOpp);
    }
})