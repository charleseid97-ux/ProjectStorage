({
	init : function(component, event, helper) {
        var recId = component.get('v.parentObjectId');
        var curObj = {Local_Status__c: '',
                      Comment__c: '',
                      Product__c: '',
                      Id: ''};

        component.set('v.buyListDisplay', curObj);
        
        helper.fetchPickListVal(component, 'Local_Status__c', 'localStatus');
        
        helper.getCurrentIndependantBuyList(component);
    },
    cancelNewBuyList : function(component, event, helper) {
		component.set('v.viewCustomObjectManagement', false);
	},
	saveNewBuyList : function(component, event, helper) {
        helper.saveIndependantBuyList(component);
	},
    deleteLocalBuyList : function(component, event, helper) {
        helper.deleteIndependant(component);
    }

})