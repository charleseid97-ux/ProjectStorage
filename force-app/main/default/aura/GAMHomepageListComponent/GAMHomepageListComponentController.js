({
	init : function(component, event, helper) {
        debugger;
		helper.getGAMHPRecordsT0(component);
		helper.getGAMHPRecordsT1(component);
	},
    viewGAMHomepage : function(component, event, helper) {
        var ctarget = event.currentTarget;
	    var GAMIdVal = ctarget.dataset.value;
    
        helper.navigateToRecord(component, GAMIdVal);
    }
})