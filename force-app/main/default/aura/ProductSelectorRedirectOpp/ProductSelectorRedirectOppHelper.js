({
	openProductSelector: function(component){
        
        var OppId = component.get("v.recordId");
        var sObjectName = component.get("v.sObjectName");        
        var openCmp = $A.get("e.force:navigateToComponent");
        openCmp.setParams({
            componentDef: "c:ProductSelectorContainerOpportunity",
            componentAttributes:{
                OppRecordId: OppId,
                currentSObject: sObjectName
            }
        });
        var sObjectPassedThrough = openCmp.getParam("currentSObject");
        debugger;
        openCmp.fire();
     
  	}
})