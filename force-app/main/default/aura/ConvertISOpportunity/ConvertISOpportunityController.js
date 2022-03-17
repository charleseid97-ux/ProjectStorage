({
	init : function(component, event, helper) {
		helper.returnInterestedParties(component);
	},
	convertOpp : function(component, event, helper) {
        var recordIdFromList = event.getSource().get("v.value");
        component.set("v.conversionStep", 1);
        helper.loadConvertOpp(component, recordIdFromList);
    }
})