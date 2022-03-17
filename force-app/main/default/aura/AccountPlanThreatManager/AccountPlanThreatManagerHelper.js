({
	loadThreat: function(component, recId) {
        var action = component.get("c.loadThreat");
        action.setParams({ objectId : component.get("v.currentObjectId")});
        
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                component.set("v.threat", response.getReturnValue());
            }
        });
        
        $A.enqueueAction(action);
    },
    saveThreat: function(component) {
        var action = component.get("c.saveThreat");
        var threat = component.get("v.threat");
        var parentRecordIdVal = threat.Company__c;

        action.setParams( {
            parentRecordId : parentRecordIdVal, 
            currentObjectId : component.get("v.currentObjectId"),
            threatText : threat.Threat__c,
            threatType : threat.Threat_Type__c
        });
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The record has been saved successfully."
                });
                toastEvent.fire();
                component.set('v.viewCustomObjectManagement', false);
            } else if(response.getState() === "ERROR") {
                var errors = response.getError();
				component.set('v.message',errors[0].message);
            }
        });
        
        $A.enqueueAction(action);
    },
    fetchPickListVal: function(component, fieldName, elementId) {
        var action = component.get("c.getselectOptions");
        action.setParams({
            "objObject": component.get("v.objInfo"),
            "fld": fieldName
        });
        var opts = [];
        action.setCallback(this, function(response) {
            if (response.getState() == "SUCCESS") {
                var allValues = response.getReturnValue();
    
                if (allValues != undefined && allValues.length > 0) {
                    opts.push({
                        class: "optionClass",
                        label: "--- None ---",
                        value: ""
                    });
                }
                for (var i = 0; i < allValues.length; i++) {
                    opts.push({
                        class: "optionClass",
                        label: allValues[i],
                        value: allValues[i]
                    });
                }
                component.find(elementId).set("v.options", opts);
            }
        });
        $A.enqueueAction(action);
	}
})