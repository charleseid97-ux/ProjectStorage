({
	init : function(component, event, helper) {
        var recId = component.get('v.parentObjectId');
        
        if(component.get('v.mode') == 'EDIT') {
            component.set("v.headerLabel", "Edit  Global Buy List");
        } else {
            component.set("v.headerLabel", "New Global Buy List");
        }

        
        var curObj = {Company__c: component.get("v.parentObjectId"),
                      Product__c: '',
                      Status__c: '',
                      Fund_Selector__c: '',
                      Comment__c: '',
                      Id: ''};

        component.set('v.buyListDisplay', curObj);
        
        helper.fetchPickListVal(component, 'Status__c', 'statusId');
        helper.getLocalBuyList(component);
        
    },
    cancelNewBuyList : function(component, event, helper) {
		component.set('v.viewCustomObjectManagement', false);
	},
	saveNewBuyList : function(component, event, helper) {
        helper.saveBuyList(component);
	},
    deleteLocalBuyList : function(component, event, helper) {
        helper.deleteBuyList(component);
    }

})