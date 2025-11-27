({
    doInit: function(component, event, helper) {
        console.log("sobjecttype : "+component.get("v.sobjecttype"));
        console.log("recordId : "+component.get("v.recordId"));
        console.debug("recordId : "+component.get("v.recordId"));
        if(component.get("v.recordId")){
            console.log("doInit In action");
            var action = component.get("c.initializeMembers");
            action.setParams({
                "recordId": component.get("v.recordId"), 
                "sobjecttype": component.get("v.sobjecttype"), 
            });
            
            action.setCallback(this, function(response) {
                var state = response.getState();
                if(state === "SUCCESS") {
                    component.set("v.contacts", response.getReturnValue());
                } else {
                    console.log('Problem getting account, response state: ' + state);
                }
            });
            //component.find("memberStatus").set("v.value", 'Invited');
            $A.enqueueAction(action);
    	}else{
            var delay=2000; //add delay to wait for lightning out to be loaded
            setTimeout(function() {
                // Prepare a toast UI message
                console.log("doInit In else");
                var resultsToast = $A.get("e.force:showToast");
                resultsToast.setParams({
                    "title": "Error",
					"message": $A.get("$Label.c.ADD_TO_EVENT_SELECT_AT_LEAST"),                                        
                    "type": "warning",
                    "duration" : "5000",
                });
                resultsToast.fire();
                $A.get("e.force:closeQuickAction").fire();
            }, delay);
            //component.find("memberStatus").set("v.value", 'Invited');
        }
        //component.find("memberStatus").set("v.value", 'Invited');
    },
	
    initPickList: function(component,event, helper) {
        //Prepare the action to create the new contact
        var campaign = component.get("v.selectedLookUpRecord");
        let buttonAdd = component.find('buttonAdd');
        console.log("campaign : "+campaign.Id);
        var initializePicklist = component.get("c.initializePicklist");
        initializePicklist.setParams({
            "sCampaignId": campaign.Id,    
        });
        
        // Configure the response handler for the action
        initializePicklist.setCallback(this, function(response) {
            var state = response.getState();
            console.log("state : "+state);
            if(state === "SUCCESS") {
                component.set("v.options", response.getReturnValue());                

                //$A.get("e.force:refreshView").fire();
            }
            else if (state === "ERROR") {
                console.log('Problem saving contact, response state: ' + state);
            } else {
                console.log('Unknown problem, response state: ' + state);
            }
        }); 
        $A.enqueueAction(initializePicklist);
        var initializePicklistMember = component.get("c.initializePicklistMember");
        initializePicklistMember.setParams({
            "sCampaignId": campaign.Id,    
        });
        // Configure the response handler for the action
        initializePicklistMember.setCallback(this, function(response) {
            var state = response.getState();
            console.log("state : "+state);
            if(state === "SUCCESS") {
                component.set("v.memberOptions", response.getReturnValue());                
                
                if($A.util.isUndefinedOrNull(campaign.Id)){
                    buttonAdd.set('v.disabled',true);
                }else{
                    buttonAdd.set('v.disabled',false);
                }                   
            }
            else if (state === "ERROR") {
                console.log('Problem saving contact, response state: ' + state);
            } else {
                console.log('Unknown problem, response state: ' + state);
            }
            //component.find("memberStatus").set("v.value", 'Invited');
        });     
        //component.find("memberStatus").set("v.value", 'Invited');
        $A.enqueueAction(initializePicklistMember);   
        //component.find("memberStatus").set("v.value", 'Invited');
    },
    
    addCampaignEvent: function(component,event, helper) {
        var campaign = component.get("v.selectedLookUpRecord");
        var category = component.find('category');
        var memberStatus = component.find('memberStatus');        
    	//let memberExist = component.find('memberExist');
        //var memberExist = true;
        console.log("campaign : "+campaign.Id);
        console.log("category : "+category.get("v.value"));
        console.log("memberStatus : "+memberStatus.get("v.value"));
        //console.log("memberExist : "+memberExist.get("v.value")); 
        var action = component.get("c.addToCampaign");
        /*if(memberStatus.get("v.value") == null ){
            memberStatus = "Invited";
        }else{
            memberStatus = memberStatus.get("v.value");
        }*/
        action.setParams({
            "iCampaignId": campaign.Id, 
            "iCategory": category.get("v.value"), 
            "sMemberStatus": memberStatus.get("v.value"),
            //"sMemberStatus": memberStatus, 
            //"bKeepExistingStatus": memberExist, 
            "contactsOrLeads": component.get("v.contacts"), 
            "sobjecttype": component.get("v.sobjecttype")
        });
        
        action.setCallback(this, function(response) {
            
            var state = response.getState();
            console.log("state : "+state);
            
            if(state === "SUCCESS") {
                var errorMsg = response.getReturnValue();
                console.log('errorMsg from server : ', errorMsg);
                if (errorMsg) {
                    // 🔴 CAS ERREUR (au moins un CM KO → VR, opt out, etc.)
                    var toast = $A.get("e.force:showToast");
                    if (toast) {
                        toast.setParams({
                            "title": "ERROR",
                            "message": errorMsg,
                            "type": "error"
                        });
                        toast.fire();
                        try {
                            window.postMessage({ type: "ADD_TO_EVENT_ERROR", message: errorMsg }, "*");
                        } catch (e) {
                            alert(errorMsg); // dernier recours
                        }
                    }else {
                        // VF / Lightning Out → simple alert
                        alert(errorMsg);
                    }
                }
                else {
                    // Prepare a toast UI message
                    var resultsToast = $A.get("e.force:showToast");
                
                    resultsToast.setParams({
                        "title": "Message",                    
                        "message": $A.get("$Label.c.ADD_TO_EVENT_SUCCESS"),                    
                        "type": "success"
                    });
                    
                    resultsToast.fire();
                }
                $A.get("e.force:closeQuickAction").fire();
                $A.get("e.force:refreshView").fire();
                
                
            }else{
                var errors = response.getError();
                var msg = $A.get("$Label.c.ADD_TO_EVENT_ERROR"); // fallback
                if (errors && errors[0] && errors[0].message) {
                    msg = errors[0].message; // ← message exact de ta VR
                }
                console.log('Problem getting account, response state: ' + state);
                console.log('msg ' + msg);
                // Prepare a toast UI message
                var toast = $A.get("e.force:showToast");
                if (toast) {
                    console.log('toast');
                    toast.setParams({
                        "title": state,
                        "message": msg,                    
                        "type": "error"
                    });
                    toast.fire();
                    // Fermer/réactualiser seulement si on est en quick action
                    var closeQA = $A.get("e.force:closeQuickAction");
                    if (closeQA) closeQA.fire();
                } 
                    console.log('vf');
                    // 2) Fallback VF : envoyer le message au parent
                    try {
                        window.postMessage({ type: "ADD_TO_EVENT_ERROR", message: msg }, "*");
                    } catch (e) {
                        alert(msg); // dernier recours
                    }
                

                
                //$A.get("e.force:refreshView").fire();
            }                       
        });
        //document.getElementById('{!$Component.memberStatus}').value='Invited';
        $A.enqueueAction(action); 
    },
    onChange: function(component) {
         console.log('In onchange drop box');
		 var button = component.find("buttonAdd");
		 button.set("v.disabled", "false");
	 },
    handleCancel: function(component, event, helper) {
        $A.get("e.force:closeQuickAction").fire();
    }
})