({
    removeRow : function(component, event, helper){
        // fire the DeleteRowEvt Lightning Event and pass the deleted Row Index to Event parameter/attribute
        var rowIndex = component.get("v.rowIndex")
        var deleteEvent = $A.get("e.c:ProductSelectorDeleteRowEvt");
        debugger;
        deleteEvent.setParams({
            "indexVar": component.get("v.rowIndex")
        });		
		deleteEvent.fire();
    }
    
})