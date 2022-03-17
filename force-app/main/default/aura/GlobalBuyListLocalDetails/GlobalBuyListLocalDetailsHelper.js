({
	getGlobalBuyList: function(component) {
        var action = component.get("c.getGlobalBuyListItemCtrl");
        action.setParams({ buyListId : component.get("v.currentObjectId")});
        
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                component.set("v.globalBuyListItem", response.getReturnValue());
            }
        });
        
        $A.enqueueAction(action);
    },
    getLocalBuyLists: function(component) {
        debugger;
        var action = component.get("c.getLocalBuyListsCtrl");
        action.setParams({ buyListId : component.get("v.currentObjectId")});
        
        action.setCallback(this, function(response) {
            debugger;
            if(component.isValid() && response.getState() === "SUCCESS") {
                component.set("v.localBuyList", response.getReturnValue());
            }
        });
        
        $A.enqueueAction(action);
    }
})