({
    init: function(component, event, helper) {
        var curObj = ({Id:"", Name:""});
        component.set("v.contactOwner", curObj);
        helper.getCurrentContact(component);
    },
    changeContactOwner: function(component, event, helper){
    	var newReviewUserId = component.find("userLookup").get("v.value");
    	
    	if(newReviewUserId == ""){
    		component.set("v.contactOwner.Name", "");
    		component.set("v.contactOwner.Email", "");  	
    		component.set("v.userRegions", "");
    		component.set("v.reviewerName", "");
    		component.set("v.autoApproveChange", false);
            var sameBDRText = component.find("sameBDRText").getElement();
            var differentBDRText = component.find("differentBDRText").getElement();                
            
            $A.util.addClass(sameBDRText, "slds-transition-hide");
            $A.util.addClass(differentBDRText, "slds-transition-hide");
            $A.util.removeClass(sameBDRText, "slds-transition-show");
            $A.util.removeClass(differentBDRText, "slds-transition-show");

    	}
    	
    	if((component.get("v.contactOwner.Name") == "")){
    		helper.findSelectedUser(component, newReviewUserId);
    	}
    },
    save : function(component, event, helper) {
        helper.saveContact(component);
    },
    closeComponent : function(component, event, helper) {
		helper.closeOwnerChange(component);
	}
})