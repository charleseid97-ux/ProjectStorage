({
	init : function(component, event, helper) {
        helper.init(component, event, helper);
        var curObj;
            curObj = {Name: '',
                      Strengths: false,
                      Weaknesses: false,
                      Threats: false};
            component.set('v.accountPlanItems', curObj);
    },
    cloneAccountPlan : function(component, event, helper) {
        helper.cloneAccountPlan(component, event, helper);
    },
        callCheckboxMethod : function(component, event, helper) {
        var capturedCheckboxName = event.getSource().get("v.value");
        var selectedObjectives =  component.get("v.selectedObjectives");
        if(selectedObjectives.indexOf(capturedCheckboxName) > -1){
            selectedObjectives.splice(selectedObjectives.indexOf(capturedCheckboxName), 1);
        }
        else{
            selectedObjectives.push(capturedCheckboxName);
        }
        component.set("v.selectedObjectives", selectedObjectives);
    },
	cancel : function(component, event, helper) {
        helper.cancel(component);
    }
})