({
    handleResponse : function(component, event) {
        
        var params = event.getParam('arguments');
        var response = params.response;
        var successHandler = params.successHandler;
        var errorHandler = params.errorHandler;

        var state = response.getState();

        if(state == 'SUCCESS') {
            
            successHandler(response);
            
        } else {
            
            var toastEvent = $A.get("e.force:showToast");
            var message = '';

            if (state === "INCOMPLETE") {
                
                message = 'Server could not be reached. Check your internet connection.';
                
            } else if (state === "ERROR") {
                
                var errors = response.getError();
                
                if (errors) {
                    
                    for(var i=0; i < errors.length; i++) {
                        
                        for(var j=0; errors[i].pageErrors && j < errors[i].pageErrors.length; j++) {
                            message += (message.length > 0 ? '\n' : '') + errors[i].pageErrors[j].message;
                        }
                        if(errors[i].fieldErrors) {
                            
                            for(var fieldError in errors[i].fieldErrors) {
                                
                                var thisFieldError = errors[i].fieldErrors[fieldError];
                                
                                for(var j=0; j < thisFieldError.length; j++) {
                                    message += (message.length > 0 ? '\n' : '') + thisFieldError[j].message;
                                }
                            }
                        }
                        if(errors[i].message) {
                            message += (message.length > 0 ? '\n' : '') + errors[i].message;
                        }
                    }
                } else {
                    message += (message.length > 0 ? '\n' : '') + 'Unknown error';
                }
            }

            toastEvent.setParams({
                title: 'Error',
                type: 'error',
                message: message
            });

            toastEvent.fire();
            if(errorHandler) {
                errorHandler(response);
            }
        }
    }
})