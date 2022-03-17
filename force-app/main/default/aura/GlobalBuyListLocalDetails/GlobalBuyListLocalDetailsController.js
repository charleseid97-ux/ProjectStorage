({
	init : function(component, event, helper) {
        helper.getGlobalBuyList(component);
        helper.getLocalBuyLists(component);
    },
    closeComponent : function(component, event, helper) {
		component.set('v.viewCustomObjectManagement', false);
	}
})