({
    init : function(component, event, helper) {
        
        //Default Date Left to today
        var today = new Date();
        //component.set('v.dateLeft', today.getFullYear() + "-" + (today.getMonth() + 1) + "-" + today.getDate());
        
        component.set('v.dateLeft', today);
        
        //Load CorporateTitle__c  picklist values
        helper.loadCorporateTitle(component, event, helper);
        //Load JobFunction__c  picklist values
        helper.loadJobFunction(component, event, helper);
        //Load Job_Title__c picklist values
        helper.loadJobTitle(component, event, helper);
    },
    
    save : function(component, event, helper) {
        var isValid = false;
        var emailField = component.find("emailrequired");
        var emailFieldValue = emailField.get("v.value");
        var moveToInactiveContacts = component.get("v.moveToInactiveContacts");
        
        var contactId = component.get("v.recordId");
        
        var regExpEmailformat = /^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;  
        
        if(!moveToInactiveContacts) {
            if(!$A.util.isEmpty(emailFieldValue) || emailFieldValue.match(regExpEmailformat)){
                component.set("v.recordError", "");
                $A.util.removeClass(emailField, 'slds-has-error');
                isValid = true;
            }else{
                $A.util.addClass(emailField, 'slds-has-error');
                component.set("v.recordError", "A valid email address must be entered");
            }
        } else{
            helper.loadConvRelatedContact(component, event, helper);
            isValid = false;
        }
        
        if(isValid){
            helper.save(component, event, helper);
            $A.get('e.force:refreshView').fire();
        } 
    },
    
    //Call checkSameHierarchy Action when target Account changed
    toAccountIdChange : function(component, event, helper) {
        
        helper.toAccountIdChange(component, event, helper);
        
    },
    
    //Hide Account lookup and new Contact details sections if moving to inactive contacts Account
    inactiveContactsChange : function(component, event, helper) {
        
        var moveToActiveDiv = component.find("moveToActiveDiv").getElement();
        
        $A.util.toggleClass(moveToActiveDiv, "slds-transition-hide");
        $A.util.toggleClass(moveToActiveDiv, "slds-transition-show");
    },
    
    //Lightning Data Services handlers
    handleRecordUpdated: function(component, event, helper) {
        
        var eventParams = event.getParams();
        
        if(eventParams.changeType === "LOADED") {
            
            var contact = component.get("v.contact");
            
        } else if(eventParams.changeType === "ERROR") {
            // there’s an error while loading, saving, or deleting the record
        }
    }
})