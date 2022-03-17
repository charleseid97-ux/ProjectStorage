({
syncWebsiteContact : function (component, event, helper, contactId) {
        var action = component.get("c.syncProspaceDetails");
    	action.setParams({
            "aContactId": contactId
        });
        action.setCallback(this, function(response){
            var state = response.getState();
            if (state === "SUCCESS") {
                location.reload();
                
            }else if(state === "ERROR"){
                
                var errors = response.getError();
                
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + 
                                    errors[0].message);
                    }
                }else{
                    errors = "ERROR";
                    console.log("Unknown error");
                }

                let toastParams = {
                    title: $A.get("Error"),
                    message: errors[0].message, // Default error message
                    type: "error"
                };
                let toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams(toastParams);
                toastEvent.fire();
                
                 window.setTimeout(
                    $A.getCallback(function() {
                        location.reload();
                    }), 5500
                );
            }
            
        });
    
    //$A.get('e.force:refreshView').fire();
        $A.enqueueAction(action);
    }
})