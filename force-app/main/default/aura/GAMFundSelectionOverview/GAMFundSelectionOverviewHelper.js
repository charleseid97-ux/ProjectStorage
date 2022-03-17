({
    getFSUList : function(component) {
        var accIdOverride = component.get("v.accIdOveride");
        var orgId = component.get("v.recordId");
        if(accIdOverride!=null && accIdOverride != '') {
            orgId = accIdOverride;
        } 
        var actionFSU = component.get("c.getFSUForReport");
        
        actionFSU.setParams({"GAMId" : orgId});
        
        actionFSU.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                var rV = actionResult.getReturnValue();
                component.set('v.FSUList', rV);
                this.getStrategyList(component);
            }
        });
        $A.enqueueAction(actionFSU);
    },
	getStrategyList : function(component) {
        var actionProds = component.get("c.getStrategyListForReport");
        
        actionProds.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                component.set('v.productList', actionResult.getReturnValue());
            }
        });
        $A.enqueueAction(actionProds);
	},
	getIsCoveredList : function(component) {
        var accIdOverride = component.get("v.accIdOveride");
        var orgId = component.get("v.recordId");   
        if(accIdOverride!=null && accIdOverride != '') {
            orgId = accIdOverride;
        } 
        var actionIsCovered = component.get("c.isCoveredList");
        
        actionIsCovered.setParams({"GAMId" : orgId});

        actionIsCovered.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                component.set('v.isCoveredList', actionResult.getReturnValue());
            }
        });
        $A.enqueueAction(actionIsCovered);
	},
    loadCustomFSUManager : function(component, mode, objectId) {
        $A.createComponent(
            "c:BuyListFSUManager",
            {
                parentObjectId: component.get('v.recordId'),
                sObjectType: component.get("v.sObjectType"),
                mode : mode,
                currentObjectId: objectId,
                viewCustomObjectManagement : true,
                "parentId": component.get('v.parentId')
            },
            function(creationComponent, status, errorMessage){
                if (status === "SUCCESS") {
                    
                    component.set("v.customFSUManagement", true);
                    component.set("v.creationComponent", creationComponent);
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
    }
})