({
	navigateToGAMHomepage : function(component) {
    	var accId = component.get("v.recordId");
        var action = component.get("c.returnGAMHomepage");
        
        action.setParams({"accId" : accId});
        action.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                var resp = actionResult.getReturnValue();
                this.navigateToRecord(component, resp);
            } else if (status === 'ERROR'){
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    title: "Error",
                    message: "No GAM Homepage was found",
                    type: "error"
                });
                toastEvent.fire();
            }
        });
        $A.enqueueAction(action);

	},
    navigateToRecord : function(component, recId) {
        var navEvent = $A.get("e.force:navigateToSObject");
        if(navEvent){
            navEvent.setParams({
                recordId: recId
            });
            navEvent.fire();   
        }
        else{
            //window.location.href = '/one/one.app#/sObject/'+component.get("v.contacts").Id+'/view'
        }
	}

})