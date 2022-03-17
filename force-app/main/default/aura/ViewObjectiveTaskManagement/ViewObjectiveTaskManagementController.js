({
	init : function(component, event, helper) {
        var recId = component.get('v.parentObjectId');
        var curObj = {Organisation__c: recId};
        
        helper.getCurrentObjective(component);
        helper.getTaskListForObjective(component);
    },
    newTask : function(component, event, helper) {
        helper.createNewTask(component);
    },
    newTaskCustom : function(component, event, helper) {
        helper.fetchAllPickLists(component);
        var curObj = {Subject: '',
                      WhatId: component.get("v.currentObjectId"),
                      Description: '',
                      Priority: 'High',
                      Status: 'To Do',
                      Type : 'To Do Action',
                      ActivityDate: '',
                      OwnerId : component.get('v.currentUserId')};
        component.set('v.taskDisplay', curObj);
		
        component.set("v.componentPage", "newtask");
    },
    cancelNewTask : function(component, event, helper) {
        component.set("v.componentPage", "tasklist");
    },
    saveThisTask : function(component, event, helper){
        debugger;
        var isValidDate = true; 
        var dateField = component.find("dueDate");
        var dateFieldValue = dateField.get("v.value");

        var isValidSubject = true;
        var subjectField = component.find("subject");
        var subjectFieldValue = subjectField.get("v.value");
        
        if(!$A.util.isEmpty(dateFieldValue) && !$A.util.isEmpty(subjectFieldValue)){
            $A.util.removeClass(dateField, 'slds-has-error');
            $A.util.removeClass(subjectField, 'slds-has-error');
            component.set("v.recordError", "");
            isValidDate = true;
            isValidSubject = true;
        } 
        if($A.util.isEmpty(dateFieldValue)) {
            isValidDate = false;
        }
        if($A.util.isEmpty(subjectFieldValue)) {
            isValidSubject = false
        }
        
        if(isValidDate && isValidSubject){
            helper.saveTask(component);
        } else {
            var errorMessage = "";
            if(!isValidDate) {
	            $A.util.addClass(dateField, 'slds-has-error');
	            errorMessage = "A valid Date must be entered";
            }
            if(!isValidSubject) {
                $A.util.addClass(subjectField, 'slds-has-error');
                errorMessage += (errorMessage == "") ? "" : ", ";
                errorMessage += "A valid Action Name must be entered";
            }
            component.set("v.recordError", errorMessage);
        }
    },
    deleteTaskCtrl : function(component, event, helper) {
        if(confirm('Are you sure you want to delete this Task?')) {
	        helper.deleteTask(component, component.get("v.currentTaskId"));
        }
    },
    viewTaskCtrl : function(component, event, helper) {
        var recordIdFromList = event.getSource().get("v.value");
        component.set("v.currentTaskId", recordIdFromList);
        helper.viewTask(component, recordIdFromList);
    },
    closeComponent : function(component, event, helper) {
		component.set('v.viewCustomObjectManagement', false);
	}
})