({
	launchDownload : function(component, event, helper) {
        debugger;
		$A.createComponent(
            "c:DecisionMakerPDF",
            {
                "recordId" : component.get("v.recordId"),
                "viewFull" : component.get("v.viewFull")
            },
            function(viewComponent, status, errorMessage){
                if (status === "SUCCESS") {
                    component.set("v.viewComponent", viewComponent);
                    component.set('v.viewComponentBlock', true);
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
    closeDownload : function(component, event, helper) {
        component.set('v.viewComponentBlock', false);
    }
})