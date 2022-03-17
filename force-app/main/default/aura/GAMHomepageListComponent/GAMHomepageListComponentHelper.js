({
	getGAMHPRecordsT0 : function(component) {
		var action = component.get("c.getGAMHomepagesT0");
        
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                component.set("v.GAMListT0", response.getReturnValue());
            }
        });
        
        $A.enqueueAction(action);
	},
	getGAMHPRecordsT1 : function(component) {
		var action = component.get("c.getGAMHomepagesT1");
        
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                component.set("v.GAMListT1", response.getReturnValue());
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