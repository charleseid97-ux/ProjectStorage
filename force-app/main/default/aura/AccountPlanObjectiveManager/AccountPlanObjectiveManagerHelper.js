({
    getObjective : function(component) {
        var action = component.get("c.getObjectiveCtrl");
        action.setParams({ 
            ObjectiveId : component.get("v.currentObjectId")
        });
        
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                var resp = response.getReturnValue();
                if(resp!=null) {
                    debugger;
                    var curObj = {Account_Plan__c : resp.Account_Plan__c,
                                  Name: resp.Name,
                                  Objective_Type__c: resp.Objective_Type__c,
                                  Due_Date__c: resp.Due_Date__c,
                                  Priority__c: resp.Priority__c,
                                  Objective_Details__c : resp.Objective_Details__c,
                                  Id: resp.Id};
                        
                    component.set('v.Objective', curObj);
                    component.set("v.companyLinks", resp.Account_Plan_Objective_Companies__r);
                }
            }
        });
        
        $A.enqueueAction(action);
    },
    saveObjective: function(component, event, helper) {
        var action = component.get("c.saveObjectiveCtrl");
        var objective = component.get("v.Objective");
        
        this.createCompanyLinks(component, event, helper, objective);
        component.set("v.companyLinks", objective.Account_Plan_Objective_Companies__r);
        debugger;
        
        action.setParams( {
            "objective" : objective,
            "companyLinks" : objective.Account_Plan_Objective_Companies__r,
        });
        debugger;
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The record has been saved successfully."
                });
                toastEvent.fire();
				component.set('v.viewCustomObjectManagement', false);
                $A.get('e.force:refreshView').fire();
            } else if(response.getState() === "ERROR") {
                var errors = response.getError();
				component.set('v.message','Please ensure all mandatory fields are filled in');
            }
        });
        
        $A.enqueueAction(action);
    },
    createCompanyLinks: function(component, event, helper, objective) {
        var apLookup = component.find('apLookup');
        
        objective.Account_Plan_Objective_Companies__r = [];
        
        this.getSelectedCompanyLinks(component, apLookup, 'Company__c', objective);
        
    },
    
    getSelectedCompanyLinks : function(component, lookup, lookupField, objective){
        var companyLinks = objective.Account_Plan_Objective_Companies__r;
        var recordId = objective.Id;
        var values = lookup.get('v.value');
        
        if (values != null)
        {
            if (values.length > 0){
                
                var valueArray = values.split(";");

                for(var i = 0; i < valueArray.length; i++){
                    debugger;
                    companyLinks.push({sobjectType:'Account_Plan_Objective_Company__c', 
                                       Account_Plan_Objective__c:recordId, 
                                       [lookupField]:valueArray[i]});
                }
            }
        }
        objective.Account_Plan_Objective_Companies__r = companyLinks;
        debugger;
        component.set("v.objective", objective);
    },
    load : function(component) {
        var companyLinks = component.get("v.companyLinks")
        var accountIds = [];
        
        if (companyLinks){
            
            for (var index in companyLinks){
                
                var companyLink = companyLinks[index];
                
                if (companyLink.Company__c){
                    accountIds.push(companyLink.Company__c);
                }
            }
            
            component.find('apLookup').set('v.value', accountIds.join(';'));
        }
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