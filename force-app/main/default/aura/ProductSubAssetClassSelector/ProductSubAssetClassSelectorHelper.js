({
	loadSubAssetClasses : function(component) {
        var action = component.get("c.getSubAssetClasses");
    	action.setCallback(this, function(response) {
            var subAssetClasses = response.getReturnValue();
            subAssetClasses.unshift("");
            window.DataCache.setData("subAssetClasses", subAssetClasses);
            component.set("v.subAssetClasses", subAssetClasses);
            console.log("Sub Asset classes retrieved from server");
    	});
    	$A.enqueueAction(action);
	}

})