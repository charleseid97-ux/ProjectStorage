({
    init : function(component, event, helper) {
        var recId = component.get('v.parentObjectId');
        var vcomp = component.get('v.viewCustomObjectManagement');
        var curObj = {parentId: component.get("v.parentObjectId"),
                      Name: '',
                      BusinessDevelopmentRegion__c: '',
                      Id: ''};
        
        component.set('v.fsuDisplay', curObj);
        
    },
    existingFSU : function(component, event, helper) {
        var curObj = {parentId: component.get("v.parentObjectId"),
                      Name: '',
                      BusinessDevelopmentRegion__c: '',
                      Id: ''};
        component.set('v.newFSU', curObj);
        component.set('v.processStep', 0.5);
        component.set("v.headerLabel", "Existing FSU Setup");
    },
    newFSU : function(component, event, helper) {
        component.set('v.processStep', 1);
        component.set("v.headerLabel", "New FSU Setup");
        helper.fetchPickListVal(component, 'BusinessDevelopmentRegion__c', 'businessRegion');
        
    },
    selectProducts : function(component, event, helper) {
        var valid = true;
        var FSUError = component.find("FSUError");
        var FSU = component.find('parentId');

        helper.hideElement(component, event, helper, FSUError);

        if(FSU.get("v.value") == ''){
            valid = false;
            helper.showElement(component, event, helper, FSUError);
        }
        if(valid) {
            helper.getStrategyList(component);
            component.set('v.processStep', 2);
        }
    },
    checkRegion : function(component, event, helper) {
        component.set("v.fsuDisplay.parentId", null);
        component.set("v.createFSUGroup", false);
        component.set("v.foundFSUGroup", false);
        component.set("v.pOverride", false);

        var action = component.get("c.checkRegionForFSU");
        var fsuDisplay = component.get("v.fsuDisplay");
        action.setParams( {
            parentRecordId : component.get("v.parentObjectId"),
            regionStr : fsuDisplay.BusinessDevelopmentRegion__c
        });
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                if(response.getReturnValue() != null) {
                    component.set("v.fsuDisplay.parentId", response.getReturnValue());
                    component.set("v.foundFSUGroup", true);
                    component.set("v.createFSUGroup", false);
                } else {
                    component.set("v.createFSUGroup", true);
                    component.set("v.foundFSUGroup", false);
                }
            } else if(response.getState() === "ERROR") {
                component.set("v.createFSUGroup", true);
            }
        });
        
        $A.enqueueAction(action);
    },
    callCheckboxMethod : function(component, event, helper) {
        var capturedCheckboxName = event.getSource().get("v.value");
        var selectedProducts =  component.get("v.selectedProducts");
        if(selectedProducts.indexOf(capturedCheckboxName) > -1){
            selectedProducts.splice(selectedProducts.indexOf(capturedCheckboxName), 1);
        }
        else{
            selectedProducts.push(capturedCheckboxName);
        }
        component.set("v.selectedProducts", selectedProducts);
    },
    parentOverride : function(component, event, helper) {
        if(component.get("v.pOverride")) {
        } else {
            component.set("v.fsuDisplay.parentId", null);
        }
    },
    cancelNewFSU : function(component, event, helper) {
        component.set('v.viewCustomObjectManagement', false);
    },
    saveNewFSU : function(component, event, helper) {
		var valid = true;
        var NError = component.find("NError");
        var BRError = component.find("BRError");
        var Name = component.find('name');
        var BR = component.find('businessRegion');

        helper.hideElement(component, event, helper, BRError);
        helper.hideElement(component, event, helper, NError);
        
        if(Name.get("v.value") == ''){
            valid = false;
            helper.showElement(component, event, helper, NError);            
        }
        if(BR.get("v.value") == ''){
            valid = false;
            helper.showElement(component, event, helper, BRError);            
        }
        if(valid) {
	        helper.saveFSU(component);
        }
    },
    createBuyList : function(component, event, helper) {
        helper.createBuyList(component);
    }
})