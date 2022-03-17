({
    resetWebsitePassword : function (component, event, helper, contactId) {
        
        var webIdPresent;
        
        var actionCheck = component.get("c.checkWebsiteId");
        actionCheck.setParams({
            "aContactId": contactId
        });
        
        actionCheck.setCallback(this, function(response) {
            webIdPresent = response.getReturnValue();
            console.log('TEST' + webIdPresent);
            
            
            
            if(webIdPresent == true){
                
                var action = component.get("c.resetProspacePass");
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
                        
                        
                        var errorMsg = "ERROR";
                        let toastParams = {
                            title: $A.get("Error"),
                            message: errors[0].message, // Default error message
                            type: "error"
                        };
                        let toastEvent = $A.get("e.force:showToast");
                        toastEvent.setParams(toastParams);
                        toastEvent.fire();
                    }
                    
                });
                
                //$A.get('e.force:refreshView').fire();
                $A.enqueueAction(action);
            }else{
                $A.util.addClass(component.find("loading"), "slds-hide");
                $A.util.addClass(component.find("waiting"), "slds-hide");
                $A.util.removeClass(component.find("errorsync"), 'slds-hide');
                $A.util.addClass(component.find("errorsync"), "slds-show");   
                
                var messageErr = $A.get("$Label.c.ErrorNotSync");
                
                let toastParams = {
                    title: $A.get("Error"),
                    message:messageErr , // Default error message
                    type: "error"
                };
                let toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams(toastParams);
                toastEvent.fire();
                
                window.setTimeout(
                    $A.getCallback(function() {
                        location.reload();
                        
                    }), 5000
                );
            }//
            
        });
        $A.enqueueAction(actionCheck);
        
        
    }
})