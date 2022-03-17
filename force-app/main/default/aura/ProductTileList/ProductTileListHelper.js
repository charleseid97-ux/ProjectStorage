({
	loadProducts : function(component, page) {
        
        var action = component.get("c.getProducts");
        
        //action.setStorable();
		var pageSize = component.get("v.pageSize");
        var filterObj = component.get("v.filterObject");
		action.setParams({
      		"filters": JSON.stringify(filterObj),
            "pageSize": pageSize,
            "pageNumber": page || 1
    	});
    	action.setCallback(this, function(response) {
    		
            console.log('# getProducts callback %f', (performance.now() - startTime));

            var result = response.getReturnValue();
            component.set("v.products", result.products);
            component.set("v.asset_classes", result.asset_classes);
            component.set("v.sub_asset_classes", result.sub_asset_classes);
            component.set("v.strategies", result.strategies);
      
            console.log('Asset classes retrieved from custom cache');
            console.log('v.products: ' + result.products);
            component.set("v.page", result.page);
            component.set("v.total", result.total);
            component.set("v.pages", Math.ceil(result.total/pageSize));
    	});
        var startTime = performance.now();
    	$A.enqueueAction(action);
	},
    /*
     * 
     * need to fire event to top level container
     * 
     */
    
    navigateToObject : function (recordId) {
		var navEvt = $A.get("e.force:navigateToSObject");
        navEvt.setParams({
          "recordId": recordId,
          "slideDevName": "detail"
        });
        navEvt.fire();
        
        /* In order to get around below issue where e.force:navigateToSObject
        * does not get you the latest set of updated data, we are setting a timeout
		* of 1 second to make sure that the view is refreshed to display the new information
        * Defect: https://success.salesforce.com/issues_view?id=a1p3A000000mCpKQAU
        */
		var delay = 1000;
        setTimeout($A.getCallback(function() {
           	$A.get('e.force:refreshView').fire();
        }), delay);
    }
})