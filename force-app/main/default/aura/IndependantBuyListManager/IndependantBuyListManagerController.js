({
	init : function(component, event, helper) {
        var recId = component.get('v.parentObjectId');
        var curObj = {Local_Status__c: '',
                      Comment__c: '',
                      Product__c: '',
                      Id: '',
                      Company__c: component.get("v.parentObjectId")};

        component.set('v.buyListDisplay', curObj);
        
        helper.fetchPickListVal(component, 'Local_Status__c', 'localStatus');
        
    },
    cancelNewBuyList : function(component, event, helper) {
		component.set('v.viewCustomObjectManagement', false);
	},
	saveNewBuyList : function(component, event, helper) {
        helper.saveLocalBuyList(component);
	},
    deleteLocalBuyList : function(component, event, helper) {
        helper.deleteLocal(component);
    }
})