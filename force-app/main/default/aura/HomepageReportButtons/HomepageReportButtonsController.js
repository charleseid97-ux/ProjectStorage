({
	openOppDash : function(component, event, helper) {
        var urlEvent = $A.get("e.force:navigateToURL");
        urlEvent.setParams({
            "url": "https://efl-prd.carmignac.com/#/views/Salesforce-HomePage/OPPORTUNITYDASHBOARD?:iid=3"
        });
        urlEvent.fire();
    },
	openActDash : function(component, event, helper) {
        var urlEvent = $A.get("e.force:navigateToURL");
        urlEvent.setParams({
            "url": "https://efl-prd.carmignac.com/#/views/Salesforce-Activites_15717257033500/Salesforce-Activities?:iid=1"
        });
        urlEvent.fire();
    },
	openBuyListReport : function(component, event, helper) {
        var urlEvent = $A.get("e.force:navigateToSObject");
        urlEvent.setParams({
            "recordId": "01Z1i000000cE0bEAE"
        });
        urlEvent.fire();
    }

})