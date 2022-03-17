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
                this.accountPlanRedirect(component);
            }
        });
        $A.enqueueAction(action);
    },
    accountPlanRedirect : function(component) {
    	var accId = component.get("v.GAMId");
        var action = component.get("c.returnLatestAccPlan");
        
        action.setParams({"accId" : accId});
        action.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                var resp = actionResult.getReturnValue();
                component.set('v.AccPlanId', resp.Id);
                //this.navigateToRecord(component, resp.Id);
            } else if (status === 'ERROR'){
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    title: "Error",
                    message: "No Account Plan was found for this GAM",
                    type: "error"
                });
                toastEvent.fire();
            }
        });
        $A.enqueueAction(action);
	},
    loadHierarchyComponent : function(component) {
        $A.createComponent(
            "c:GAMHomepageHierarchyModal",
            {
                GAMId: component.get('v.GAMId'),
                GAMName: component.get('v.GAMAccount.Name'),
                viewHierarchyComponent: true
            },
            function(hierarchyComponent, status, errorMessage){
                if (status === "SUCCESS") {
                    
                    component.set("v.hierarchyComponent", hierarchyComponent);
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
    loadSocialComponent : function(component) {
        $A.createComponent(
            "c:GAMHomepageSocialModal",
            {
                GAMId: component.get('v.GAMId'),
                GAMAccount: component.get('v.GAMAccount'),
                viewSocialComponent: true
            },
            function(socialComponent, status, errorMessage){
                if (status === "SUCCESS") {
                    
                    component.set("v.socialComponent", socialComponent);
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
    loadKeyContactsComponent : function(component) {
        var accId = component.get('v.GAMId');
        var action = component.get("c.getKeyContactFileId");
        
        action.setParams({"accId" : accId});
        action.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                var resp = actionResult.getReturnValue();
                component.set("v.KCFileId", resp);
                $A.get('e.lightning:openFiles').fire({
                    recordIds: [resp]
                });
                console.log("event fired");
            } else if(status === 'ERROR') {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    title: "Error",
                    message: "No Key Contacts document was found for this GAM",
                    type: "error"
                });
                toastEvent.fire();
            }
        });
        $A.enqueueAction(action);
    },
    loadKeyContactsComponentModal : function(component) {
        debugger;
        $A.createComponent(
            "c:GAMHomepageKeyContactsModal",
            {
                GAMId: component.get('v.GAMId'),
                GAMName: component.get('v.GAMAccount.Name'),
                viewKCComponent: true
            },
            function(kCComponent, status, errorMessage){
                debugger;
                if (status === "SUCCESS") {
                    
                    component.set("v.kCComponent", kCComponent);
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
    loadOrganigramComponent : function(component) {
        var accId = component.get('v.GAMId');
        var action = component.get("c.getOrganigramFileId");
        
        action.setParams({"accId" : accId});
        action.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                var resp = actionResult.getReturnValue();
                component.set("v.OrgFileId", resp);
                $A.get('e.lightning:openFiles').fire({
                    recordIds: [resp]
                });
                console.log("event fired");
            } else if(status === 'ERROR') {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    title: "Error",
                    message: "No Organigram document was found for this GAM",
                    type: "error"
                });
                toastEvent.fire();
            }
        });
        $A.enqueueAction(action);
    },
    loadTieringComponent : function(component) {
        $A.createComponent(
            "c:GAMHomepageTieringModel",
            {
                GAMId: component.get('v.GAMId'),
                GAMName: component.get('v.GAMAccount.Name'),
                GAMTier: component.get('v.GAMAccount.Client_Tier__c'),
                viewTieringComponent: true
            },
            function(tieringComponent, status, errorMessage){
                if (status === "SUCCESS") {
                    
                    component.set("v.tieringComponent", tieringComponent);
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