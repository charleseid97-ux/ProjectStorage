({
	init : function(component, event, helper) {
 
        var action = component.get("c.getAccountPlan");
        action.setParams({recordId : component.get("v.recordId")});
        action.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                var resp = actionResult.getReturnValue();
                component.set('v.accountPlan', resp);
                component.set('v.accountPlanItems.Name', resp.Name);
                component.set('v.accountPlanObjectives', resp.Account_Plan_Objectives__r)
            }
        });
        $A.enqueueAction(action);
    },
    cloneAccountPlan : function(component, event, helper) {
        var action = component.get("c.cloneAccountPlanCtrl");
        var apItems = component.get("v.accountPlanItems");
        var objItems = component.get("v.selectedObjectives");
        action.setParams({
            recordId : component.get("v.recordId"),
            accountPlan : component.get("v.accountPlan"),
            accountPlanItems : apItems,
            objectiveItems : objItems
        });
        action.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            debugger;
            if (status === 'SUCCESS') {
                var resp = actionResult.getReturnValue();
                var navEvt = $A.get("e.force:navigateToSObject");
                navEvt.setParams({
                    "recordId": resp.Id
                });
                navEvt.fire();
            } else if (status === 'ERROR') {
                var toastEvent = $A.get("e.force:showToast");
                var errs = actionResult.getError();
                debugger;
                toastEvent.setParams({
                    "title": "Error!",
                    "type" : "error",
                    message: actionResult.getError()[0].message
                });
                toastEvent.fire();            
            }
        });
        $A.enqueueAction(action);
    },
	cancel : function(component, event, helper) {
 
        
    }
})