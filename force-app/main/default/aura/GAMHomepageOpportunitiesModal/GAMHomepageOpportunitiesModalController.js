({
	init : function(component, event, helper) {
		var GAMName = component.get("v.GAMAccount.Name");
        GAMName = GAMName.replace("GLOBAL", "");
        GAMName = GAMName.replace("ACCOUNT", "");
        GAMName = GAMName.replace("GAM", "");
        component.set("v.GAMAccountName", GAMName);
	},
	closeComponent : function(component, event, helper) {
		component.set("v.viewOpportunitiesComponent", false);
	}
})