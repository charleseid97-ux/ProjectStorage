({
	openHandbook : function(component, event, helper) {
        var urlEvent = $A.get("e.force:navigateToURL");
        urlEvent.setParams({
            "url": "https://home.carmignac.com/projects/cf2020/docs/4.%20Phase%20II%20-%20SF%20Implementation/0.%20Salesforce%20Handbook/Training%20SF%20Handbook%20V1.0.pdf"
        });
        urlEvent.fire();
    }
})