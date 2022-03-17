({
    findSelectedUser : function(component, newReviewUserId){
        var getReviewerAction = component.get("c.getCurrentUser");
        getReviewerAction.setParams({
            "currentUserId": newReviewUserId
        });
        
        var sameBDRText = component.find("sameBDRText").getElement();
        var differentBDRText = component.find("differentBDRText").getElement();                
        
        $A.util.addClass(sameBDRText, "slds-transition-hide");
        $A.util.addClass(differentBDRText, "slds-transition-hide");
        $A.util.removeClass(sameBDRText, "slds-transition-show");
        $A.util.removeClass(differentBDRText, "slds-transition-show");
        
        getReviewerAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS'){
                var responseValue = response.getReturnValue();
                component.set("v.newOwner", responseValue);
                component.set("v.userRegions", responseValue.BusinessDevelopmentRegions__c);
                this.checkAutoApprove(component);
            }
        });
        $A.enqueueAction(getReviewerAction);
    },
    findCurrentOwner : function(component, currentOwnerId){
        var getOwnerAction = component.get("c.getCurrentUser");
        getOwnerAction.setParams({
            "currentUserId": currentOwnerId
        });
       
        getOwnerAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS'){
                var responseValue = response.getReturnValue();
                component.set("v.currentOwner", responseValue);
                component.set("v.currentOwnerRegions", responseValue.BusinessDevelopmentRegions__c);
            }
        });
        $A.enqueueAction(getOwnerAction);
    },
    getCurrentContact : function(component) {
        var getContactAction = component.get("c.getCurrentContact");
        var contactId = component.get("v.recordId");
        getContactAction.setParams({
            "contactId": contactId
        });
        getContactAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS'){                
                var responseValue = response.getReturnValue();
                component.set("v.contact", responseValue);
                this.findCurrentOwner(component, responseValue.OwnerId);
            }
        });
        $A.enqueueAction(getContactAction);
    },
    checkAutoApprove : function(component) {
        var currentOwnerRegions = component.get("v.currentOwnerRegions");
        var userRegions = component.get("v.userRegions");
        
        var validateAutoApprove = component.get("c.autoApproveChange");
        
        var sameBDRText = component.find("sameBDRText").getElement();
        var differentBDRText = component.find("differentBDRText").getElement();

        validateAutoApprove.setParams({
            "currentOwnerRegions" : currentOwnerRegions,
            "userRegions" : userRegions
        });
        validateAutoApprove.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS'){                
                var responseValue = response.getReturnValue();
                component.set("v.autoApproveChange", responseValue);
                if(responseValue) {
                    $A.util.removeClass(sameBDRText, "slds-transition-hide");
                    $A.util.addClass(sameBDRText, "slds-transition-show");
                } else {
                    $A.util.removeClass(differentBDRText, "slds-transition-hide");
                    $A.util.addClass(differentBDRText, "slds-transition-show");
                }
            }
        });
        $A.enqueueAction(validateAutoApprove);
    },
    saveContact : function(component) {
        debugger;
        var saveContactAction = component.get("c.saveContact");
        var contactId = component.get("v.recordId");
        var autoApproveChange = component.get("v.autoApproveChange");
        var newOwner = component.get("v.newOwner");
        saveContactAction.setParams({
            "contactId": contactId,
            "autoApprove" : autoApproveChange,
            "newOwner" : newOwner
        });
        saveContactAction.setCallback(this, function(response){
        debugger;
            var status = response.getState();
            var responseValue = response.getReturnValue();
            var toastEvent = $A.get("e.force:showToast");
            
            if (status === 'SUCCESS'){
                var saveMessage = autoApproveChange ? "Contact Owner has been updated and saved": "The new Proposed Contact owner is awaiting approval";
                toastEvent.setParams({
                    title: "Success",
                    message: saveMessage
                });
                toastEvent.fire();
                $A.get('e.force:refreshView').fire();
                this.closeOwnerChange(component);
            }
            
            if (status === 'ERROR'){  
                var errors = response.getError();
                var toastParams = {
                    title: "Error",
                    message: "Unknown error",
                    type: "error"
                };
                if (errors && Array.isArray(errors) && errors.length > 0) {
                    toastParams.message = errors[0].message;
                }
                toastEvent.setParams(toastParams);
                toastEvent.fire();
                this.closeOwnerChange(component);
            }
        });
        $A.enqueueAction(saveContactAction);
    },
    closeOwnerChange : function(component) {
        $A.get("e.force:closeQuickAction").fire();
    }
})