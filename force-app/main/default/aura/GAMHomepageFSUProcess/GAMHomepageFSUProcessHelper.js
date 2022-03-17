({
	loadLinkedAccount : function(component) {
        var recId = component.get("v.recordId");
        var action = component.get("c.returnGAMAccount");
        
        action.setParams({"HPId" : recId});
        action.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                var resp = actionResult.getReturnValue();
                component.set('v.GAMAccount', resp);
                component.set('v.GAMId', resp.Id);
            }
        });
        $A.enqueueAction(action);
    },
    loadProcessComponent : function(component) {
        $A.createComponent(
            "c:GAMHomepageFSUProcessModal",
            {
                GAMId: component.get('v.GAMId'),
                GAMName: component.get('v.GAMAccount.Name'),
                viewProcessComponent: true
            },
            function(hierarchyComponent, status, errorMessage){
                if (status === "SUCCESS") {
                    
                    component.set("v.processComponent", hierarchyComponent);
                    component.set('v.preview', true);
                }
                else if (status === "INCOMPLETE") {
                    console.log("No response from server or client is offline.")
                    // Show offline error
                }
                    else if (status === "ERROR") {
                        console.log("Error: " + errorMessage);
                        // Show error message
                    }
            }
        );
    },
    loadGlobalLocalReport : function(component) {
        var GAMName = component.get("v.GAMAccount.Name");
        var action = component.get("c.returnBuyListReport");
        GAMName = GAMName.replace(' ACCOUNT', '');
        GAMName = GAMName.replace(' GLOBAL', '');
        GAMName = GAMName.replace(' GAM', '');
        action.setParams({"reportName" : GAMName + ' Buy List'});
        console.log('-'+GAMName+'-');
        action.setCallback(this, function(actionResult) {
            console.log(actionResult.getReturnValue());
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                var resp = actionResult.getReturnValue();
		        this.navigateToRecord(component, resp);
            } else if (status === 'ERROR') {
                console.log('error getting report');
            }
        });
        $A.enqueueAction(action);
    },
    loadFullBuyListComponent : function(component) {
        var accId = component.get('v.GAMId');
        var action = component.get("c.getFullClientBuyListFileId");
        
        action.setParams({"accId" : accId});
        action.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                var resp = actionResult.getReturnValue();
                component.set("v.FullBuyListFileId", resp);
                $A.get('e.lightning:openFiles').fire({
                    recordIds: [resp]
                });
                console.log("event fired");
            } else if(status === 'ERROR') {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    title: "Error",
                    message: "No Full Client Buy List document was found for this GAM",
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