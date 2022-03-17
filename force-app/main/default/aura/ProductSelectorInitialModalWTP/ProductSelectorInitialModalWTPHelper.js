({
    
  
	openProductSelector: function(component){
        
        var WTPId = component.get("v.currentWTPId");
        var sObjectName = component.get("v.sObjectName");        
        var openCmp = $A.get("e.force:navigateToComponent");
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