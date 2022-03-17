({
    getLocalBuyList : function(component) {
        var action = component.get("c.getLocalBuyListItemCtrl");
        action.setParams({ 
            globalBuyListId : component.get("v.currentObjectId"),
            accountId : component.get("v.parentObjectId")
        });
        
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                var resp = response.getReturnValue();
                if(resp!=null) {
                    var curObj = {Local_Status__c: resp.Local_Status__c,
                                  Comment__c: resp.Comment__c,
                                  Product__c: resp.Product__r.Name,
                                  Id: resp.Id};
    				
                    component.set('v.buyListDisplay', curObj);
                    component.set('v.showDelete', true);
                }
            }
        });
        
        $A.enqueueAction(action);
    },
    saveLocalBuyList: function(component) {
        var action = component.get("c.saveLocalBuyListCtrl");
        var gloablBuyList = component.get("v.globalBuyList");
        var localBuyList = component.get("v.buyListDisplay");
		var accountId = component.get("v.parentObjectId");
        action.setParams( {
            globalStatusId : null,
            globalStatus : 'N/A',
            localStatus : localBuyList.Local_Status__c,
            product : localBuyList.Product__c,
            fundSelector : null,
            comment : localBuyList.Comment__c,
            accountId : localBuyList.Company__c,
            localId : localBuyList.Id
        });
        debugger;
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The record has been saved successfully."
                });
                toastEvent.fire();
				component.set('v.viewCustomObjectManagement', false);
            } else if(response.getState() === "ERROR") {
                var errors = response.getError();
				component.set('v.message',errors[0].message);
            }
        });
        
        $A.enqueueAction(action);
    },
    deleteLocal: function(component) {
        var action = component.get("c.deleteLocalCtrl");
        var localBuyList = component.get("v.buyListDisplay");
        action.setParams({delId : localBuyList.Id,
                         globalStatusId : component.get("v.currentObjectId")});
        
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The record has been deleted."
                });
                toastEvent.fire();
				component.set('v.viewCustomObjectManagement', false);
            } else if(response.getState() === "ERROR") {
                var errors = response.getError();
				component.set('v.message',errors[0].message);
            }
        });
        
        $A.enqueueAction(action);
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
	}
})