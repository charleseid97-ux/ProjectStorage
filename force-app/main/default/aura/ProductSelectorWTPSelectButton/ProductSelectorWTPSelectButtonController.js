({
	launchProductSelector : function(component, event, helper) {
		var WTPId = component.get("v.recordId");
        var sObjectName = component.get("v.sObjectName");        
        var openCmp = $A.get("e.force:navigateToComponent");
        debugger;
        openCmp.setParams({
            componentDef: "c:ProductSelectorContainerWTP",
            componentAttributes:{
                WTPRecordId: WTPId,
                currentSObject: sObjectName
            }
        });
        var sObjectPassedThrough = openCmp.getParam("currentSObject");
        debugger;
        openCmp.fire();
	}
})