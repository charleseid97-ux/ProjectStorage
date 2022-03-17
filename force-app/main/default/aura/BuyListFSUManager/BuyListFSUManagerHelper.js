({
	saveFSU: function(component) {
        var action = component.get("c.saveFSUCtrl");
        var fsuDisplay = component.get("v.fsuDisplay");
        var autoCategory = false;
        var createFSUGroup = component.get("v.createFSUGroup");
        var pOverride = component.get("v.pOverride");
        if(createFSUGroup && pOverride!=true) {
            autoCategory = true;
		}
        action.setParams( {
            Name : fsuDisplay.Name,
            parentId : fsuDisplay.parentId,
            BusinessDevelopmentRegion : fsuDisplay.BusinessDevelopmentRegion__c,
            autoCategory : autoCategory,
            parentRecordId : component.get("v.parentObjectId")
        });
        action.setCallback(this, function(response) {
            debugger;
            if(component.isValid() && response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The record has been saved successfully."
                });
                toastEvent.fire();
                component.set("v.newFSU", response.getReturnValue());
                this.getStrategyList(component);
				component.set('v.processStep', 2);
                //$A.get('e.force:refreshView').fire();
            } else if(response.getState() === "ERROR") {
                var errors = response.getError();
				component.set('v.message','An error occurred');
            }
        });
        
        $A.enqueueAction(action);
    },
    createBuyList : function(component) {
        var action = component.get("c.createBuyListCtrl");
        var newFSU = component.get("v.newFSU");
        var productIds = component.get("v.selectedProducts");
        action.setParams( {
            parentId : component.get('v.parentObjectId'),
            FSUId : newFSU.Id,
            productIds : productIds
        });
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The records have been saved successfully."
                });
                toastEvent.fire();
                component.set('v.viewCustomObjectManagement', false);
                $A.get('e.force:refreshView').fire();
            } else if(response.getState() === "ERROR") {
                var errors = response.getError();
            }
        });
        
        $A.enqueueAction(action);
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
    fetchPickListVal: function(component, fieldName, elementId) {
        var action = component.get("c.getselectOptions");
        action.setParams({
            "objObject": component.get("v.objInfo"),
            "fld": fieldName
        });
        var opts = [];
        action.setCallback(this, function(response) {
            if (response.getState() == "SUCCESS") {
                var allValues = response.getReturnValue();
                if (allValues != undefined && allValues.length > 0) {
                    opts.push({
                        class: "optionClass",
                        label: "--- None ---",
                        value: ""
                    });
                }
                for (var i = 0; i < allValues.length; i++) {
                    opts.push({
                        class: "optionClass",
                        label: allValues[i],
                        value: allValues[i]
                    });
                }
                component.find(elementId).set("v.options", opts);
            }
        });
        $A.enqueueAction(action);
    },

    hideElement : function(component, event, helper, elementObj){
        $A.util.addClass(elementObj, 'slds-hide');
        $A.util.removeClass(elementObj, 'slds-show');
    },
    
    showElement : function(component, event, helper, elementObj){
        $A.util.removeClass(elementObj, 'slds-hide');
        $A.util.addClass(elementObj, 'slds-show');
    },

})