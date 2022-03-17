({
	init : function(component, event, helper) {
        var recId = component.get('v.parentObjectId');
        
        if(component.get('v.mode') == 'EDIT') {
            component.set("v.headerLabel", "Edit Account Plan Objective");
        } else {
            component.set("v.headerLabel", "New Account Plan Objective");
        }
        
        var curObj = {Account_Plan__c: recId,
                      Name: '',
                      Objective_Type__c: '',
                      Due_Date__c: '',
                      Priority__c: '',
                      Objective_Details__c : '',
                      Id: null};
        
        component.set('v.Objective', curObj);
        helper.fetchPickListVal(component, 'Objective_Type__c', 'typeId');
        helper.fetchPickListVal(component, 'Priority__c', 'priorityId');
        helper.getObjective(component);
        helper.load(component);

    },
    load : function(component, event, helper){
        helper.load(component);
    },
    saveComponent : function(component, event, helper) {
        helper.saveObjective(component, event, helper);
	},
    closeComponent : function(component, event, helper) {
		component.set('v.viewCustomObjectManagement', false);
	},
})