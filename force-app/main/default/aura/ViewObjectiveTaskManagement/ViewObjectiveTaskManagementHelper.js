({
	getCurrentObjective: function(component) {
        var action = component.get("c.getObjective");
        action.setParams({ ObjectiveId : component.get("v.currentObjectId")});
        
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                component.set("v.objective", response.getReturnValue());
            }
        });
        
        $A.enqueueAction(action);
    },
    getTaskListForObjective: function(component) {
        var action = component.get("c.getTaskList");
        action.setParams({ ObjectiveId : component.get("v.currentObjectId")});
        
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                component.set("v.taskList", response.getReturnValue());
            }
        });
        
        $A.enqueueAction(action);
    },
    createNewTask: function(component) {
    	var evt = $A.get("e.force:createRecord");
        evt.setParams({
           'entityApiName':'Task',
           'defaultFieldValues': {
              'Status':'To Do',
               'WhatId':component.get("v.currentObjectId")
           }
        });
        
        evt.fire();
	},
    viewTask : function(component, taskId) {
        var action = component.get("c.getTask");
        action.setParams({ TaskId : taskId});
        
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                component.set("v.taskDisplay", response.getReturnValue());
                if(component.get("v.taskDisplay.Status")=="Done") {
                    component.set("v.componentPage", "viewtask");
                } else {
			        this.fetchAllPickLists(component);
	                component.set("v.componentPage", "edittask");
                }

            }
        });
        
        $A.enqueueAction(action);
    },
    saveTask: function(component) {
        var task = component.get("v.taskDisplay");
        var action = component.get("c.saveTask");

        action.setParams( {
            ObjectiveId : component.get("v.currentObjectId"), 
            task : task
        });
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The record has been saved successfully."
                });
                toastEvent.fire();
                component.set("v.taskList", response.getReturnValue());
                component.set("v.componentPage", "tasklist");
            } else if(response.getState() === "ERROR") {
                var errors = response.getError();
				component.set('v.message',errors[0].message);
            }
        });
        
        $A.enqueueAction(action);
    },
    deleteTask : function(component, taskId) {
        var action = component.get("c.delTask");
        action.setParams({ 
            ObjectiveId : component.get("v.currentObjectId"),
            TaskId : taskId
        });
        
        action.setCallback(this, function(response) {
            if(component.isValid() && response.getState() === "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "type": "error",
                    "title": "Task Deleted!",
                    "message": "The record has been deleted."
                });
                toastEvent.fire();
                component.set("v.taskList", response.getReturnValue());
                component.set("v.componentPage", "tasklist");
            }
        });
        
        $A.enqueueAction(action);
    },
    fetchAllPickLists : function(component) {
        this.fetchPickListVal(component, 'Status', 'taskStatus');
        this.fetchPickListVal(component, 'Type', 'taskType');
        this.fetchPickListVal(component, 'Priority', 'taskPriority');
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