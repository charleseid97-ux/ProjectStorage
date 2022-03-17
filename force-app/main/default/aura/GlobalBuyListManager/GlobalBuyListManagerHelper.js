({
    getLocalBuyList : function(component) {
        debugger;
        var action = component.get("c.getGlobalBuyListItemCtrl");
        action.setParams({ 
            buyListId : component.get("v.currentObjectId")
        });
        
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                var resp = response.getReturnValue();
                if(resp!=null) {
                    var curObj = {Company__c: resp.Company__c,
                                  Product__c: resp.Product__c,
                                  Fund_Selector__c: resp.Fund_Selector__c,
                                  Status__c: resp.Status__c,
                                  Comment__c: resp.Comment__c,
                                  Id: resp.Id};
    				
                    component.set('v.buyListDisplay', curObj);
                }
            }
        });
        
        $A.enqueueAction(action);
    },
    saveBuyList: function(component) {
        var action = component.get("c.saveGlobalBuyListCtrl");
        var gloablBuyList = component.get("v.globalBuyList");
        var buyListDisplay = component.get("v.buyListDisplay");
		var accountId = component.get("v.parentObjectId");
        debugger;
        action.setParams( {
            globalStatus : buyListDisplay.Status__c,
            product : buyListDisplay.Product__c,
            fundSelector : buyListDisplay.Fund_Selector__c,
            comment : buyListDisplay.Comment__c,
            accountId : accountId,
            buyListDisplayId : buyListDisplay.Id
        });
        debugger;
        action.setCallback(this, function(response) {
            debugger;
            if(component.isValid() && response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The record has been saved successfully."
                });
                toastEvent.fire();
				component.set('v.viewCustomObjectManagement', false);
                $A.get('e.force:refreshView').fire();
            } else if(response.getState() === "ERROR") {
                var errors = response.getError();
				component.set('v.message','Please ensure all mandatory fields are filled in');
            }
        });
        
        $A.enqueueAction(action);
    },
    deleteBuyList: function(component) {
        var action = component.get("c.deleteGlobalCtrl");
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