({
	init : function(component, event, helper) {

        var accId = component.get("v.recordId");
        var returnAcc = component.get("c.returnAccount");
        returnAcc.setParams({
            "accId": accId            
        });
        
        returnAcc.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS') {
                var responseValue = response.getReturnValue();
                component.set("v.account", responseValue);
                var GAMName = responseValue.Name;
                GAMName = GAMName.replace("GLOBAL", "");
                GAMName = GAMName.replace("ACCOUNT", "");
                GAMName = GAMName.replace("GAM", "");
                component.set("v.accountName", GAMName);
            }
        });
        $A.enqueueAction(returnAcc);
        
	}
})