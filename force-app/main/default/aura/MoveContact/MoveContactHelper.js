({
    //Load CorporateTitle__c picklist values
    loadCorporateTitle : function(component, event, helper) {
        
        var opts=[];
        component.set("v.corporateTitleOptions", opts);
        
        //Action and error handler
        var action = component.get("c.getCorporateTitleOptions");
        var toastErrorHandler = component.find('toastErrorHandler');
        
        //Set Action callback to use toastErrorhandler
        action.setCallback(this, function(response) {
            
            toastErrorHandler.handleResponse(
                response, 
                function(response){
                    var JT = component.get("v.contact.CorporateTitle__c");
                    //Success handler. Set picklist options on component variable
                    for(var i=0;i< response.getReturnValue().length;i++){
                        var CT = response.getReturnValue()[i];
                        debugger;
                        if (response.getReturnValue()[i] == component.get("v.contact.CorporateTitle__c")) {
                            opts.push({label: response.getReturnValue()[i], value: response.getReturnValue()[i], selected: true});
                            component.set("v.newContact.CorporateTitle__c", component.get("v.contact.CorporateTitle__c"))
                        } else {
                            opts.push({label: response.getReturnValue()[i], value: response.getReturnValue()[i]});
                        }
                    }
                    component.set("v.corporateTitleOptions", opts);
                });
        });
        $A.enqueueAction(action); 
    },
    //Load JobFunction__c picklist values
    loadJobFunction : function(component, event, helper) {
        
        var opts=[];
        component.set("v.jobFunctionOptions", opts);
        
        //Action and error handler
        var action = component.get("c.getJobFunctionOptions");
        var toastErrorHandler = component.find('toastErrorHandler');
        
        //Set Action callback to use toastErrorhandler
        action.setCallback(this, function(response) {
            
            toastErrorHandler.handleResponse(
                response, 
                function(response){
                    var JT = component.get("v.contact.JobFunction__c");
                    //Success handler. Set picklist options on component variable
                    for(var i=0;i< response.getReturnValue().length;i++){
                        var CT = response.getReturnValue()[i];
                        debugger;
                        if (response.getReturnValue()[i] == component.get("v.contact.JobFunction__c")) {
                            opts.push({label: response.getReturnValue()[i], value: response.getReturnValue()[i], selected: true});	        		
                            component.set("v.newContact.JobFunction__c", component.get("v.contact.JobFunction__c"))
                        } else {
                            opts.push({label: response.getReturnValue()[i], value: response.getReturnValue()[i]});
                        }
                    }
                    component.set("v.jobFunctionOptions", opts);
                });
        });
        $A.enqueueAction(action); 
    },
    //Load Job_Title__c picklist values
    loadJobTitle : function(component, event, helper) {
        
        var opts=[];
        component.set("v.jobTitleOptions", opts);
        
        //Action and error handler
        var action = component.get("c.getJobTitleOptions");
        var toastErrorHandler = component.find('toastErrorHandler');
        
        //Set Action callback to use toastErrorhandler
        action.setCallback(this, function(response) {
            
            toastErrorHandler.handleResponse(
                response, 
                function(response){
                    var JT = component.get("v.contact.JobTitle__c");
                    //Success handler. Set picklist options on component variable
                    for(var i=0;i< response.getReturnValue().length;i++){
                        var CT = response.getReturnValue()[i];
                        debugger;
                        if (response.getReturnValue()[i] == component.get("v.contact.JobTitle__c")) {
                            opts.push({label: response.getReturnValue()[i], value: response.getReturnValue()[i], selected: true});	        		
                            component.set("v.newContact.JobTitle__c", component.get("v.contact.JobTitle__c"))
                        } else {
                            opts.push({label: response.getReturnValue()[i], value: response.getReturnValue()[i]});
                        }
                    }
                    component.set("v.jobTitleOptions", opts);
                });
        });
        $A.enqueueAction(action); 
    },
    
    //Call checkSameHierarchy Action when target Account changed
    toAccountIdChange : function(component, event, helper) {
        
        //Parameters for Action
        var orgLookup = component.find("orgLookup");
        var toAccountId = orgLookup.get("v.value");
        
        var contact = component.get("v.contact");
        var fromAccountId = contact.AccountId;
        
        var sameHierarchyText = component.find("sameHierarchyText").getElement();;
        var differentHierarchyText = component.find("differentHierarchyText").getElement();;
        
        if (!toAccountId){
            
            $A.util.addClass(sameHierarchyText, "slds-transition-hide");
            $A.util.addClass(differentHierarchyText, "slds-transition-hide");
            $A.util.removeClass(sameHierarchyText, "slds-transition-show");
            $A.util.removeClass(differentHierarchyText, "slds-transition-show");
            
        }else{
            
            //Action and error handler
            var action = component.get('c.checkSameHierarchy');
            var toastErrorHandler = component.find('toastErrorHandler');
            
            action.setParams({ fromAccountId : fromAccountId,
                              toAccountId : toAccountId});
            
            //Set Action callback to use toastErrorhandler
            action.setCallback(this, function(response){
                
                toastErrorHandler.handleResponse(
                    response, 
                    function(response){
                        
                        //Set isSameHierarchy with result of Action
                        var isSameHierarchy = response.getReturnValue();
                        component.set('v.isSameHierarchy', isSameHierarchy);
                        
                        if (isSameHierarchy){
                            
                            $A.util.addClass(sameHierarchyText, "slds-transition-show");
                            $A.util.removeClass(sameHierarchyText, "slds-transition-hide");
                            $A.util.addClass(differentHierarchyText, "slds-transition-hide");
                            $A.util.removeClass(differentHierarchyText, "slds-transition-show");
                        }else{
                            
                            $A.util.addClass(differentHierarchyText, "slds-transition-show");
                            $A.util.removeClass(differentHierarchyText, "slds-transition-hide");
                            $A.util.addClass(sameHierarchyText, "slds-transition-hide");
                            $A.util.removeClass(sameHierarchyText, "slds-transition-show");
                        }
                    })
            });
            $A.enqueueAction(action);
        }
    },
    
    //Call Apex controller to save contacts details and create Former Employment record
    save : function(component, event, helper) {
        //Parameters for Action
        var orgLookup = component.find("orgLookup");
        var toAccountId =  (orgLookup.get("v.value") ? orgLookup.get("v.value") : null);
        var newContact = component.get("v.newContact");
        var contact = component.get("v.contact");
        var oldContactId = component.get("v.recordId");
        var inactiveContacts = component.get("v.moveToInactiveContacts");
        var dateLeft = component.get("v.dateLeft");
        var isSameHierarchy = component.get("v.isSameHierarchy");
        debugger;
        //Action and error handler
        var action = component.get('c.doSave');
        var toastErrorHandler = component.find('toastErrorHandler');
        
        action.setParams({ 	oldContactId: oldContactId,
                          newContact : newContact,
                          toAccountId : toAccountId,
                          isSameHierarchy: isSameHierarchy,
                          moveToInactiveContacts: inactiveContacts,
                          dateLeft: dateLeft,
                          oldContact: contact});
        
        //Set Action callback to use toastErrorhandler
        action.setCallback(this, function(response){
            var resp = response.getReturnValue();
            debugger;
            toastErrorHandler.handleResponse(
                response, 
                function(response){
                    
                    //Show success toast 
                    var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        "title": "Success",
                        "message": "Contact successfully moved",
                        "type": "success"
                    });
                    
                    toastEvent.fire();
                    
                    //Close Quick Action dialogue
                    $A.get("e.force:closeQuickAction").fire();
                })
        });
        debugger;
        $A.enqueueAction(action);
    },
    loadConvRelatedContact: function(component, event, helper) {
        var contactId = component.get("v.recordId");
        var action = component.get("c.getConvRelatedContact");
        
        action.setParams({
            "contactId" : contactId
        });
        action.setCallback(this, function(response){
            var state = response.getState();
            if (state === "SUCCESS"){
                var resp = response.getReturnValue();
                if(!$A.util.isEmpty(resp))
                    component.set("v.recordError", "You cannot deactivate this contact because it is linked to the following agreements : "+resp);
				else
                    this.save(component, event, helper);
            }else if (state === "INCOMPLETE"){
                // do something
            }else if (state === "ERROR"){
            }
        });
        debugger;
        $A.enqueueAction(action);
    },
})