({
	loadStrategies : function(component) {
        var action = component.get("c.getStrategies");
    	action.setCallback(this, function(response) {
            var strategies = response.getReturnValue();
            strategies.unshift("");
            window.DataCache.setData("strategies", strategies);            
            component.set("v.strategies", strategies);           
            console.log("Strategies retrieved from server");
    	});
    	$A.enqueueAction(action);
	}

})