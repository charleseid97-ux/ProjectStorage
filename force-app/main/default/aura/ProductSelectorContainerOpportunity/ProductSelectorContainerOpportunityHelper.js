({
    saveProductsToOpp: function(component, OppId, sProductList, deleteProductList){
        debugger;
        var insertProductList = [];  
        for(var i = 0; i<sProductList.length; i++){
            if(sProductList[i].Id === undefined){
                insertProductList.push(sProductList[i]);
            }
        }
        
        for(var i = 0; i<deleteProductList.length; i++){
            if(deleteProductList[i].Id === undefined){
                deleteProductList.splice(i,1);
                i--;
            }
        }
        var action = component.get("c.linkProductsToOpp");
        
        action.setParams({
            "insertProductList": insertProductList,
            "deleteProductList": deleteProductList
            
        });
        action.setCallback(this, function(response){
            var state = response.getState();            
            if (state === 'SUCCESS'){
                this.navigateToObject(OppId);
            } 
        });
        $A.enqueueAction(action);
    },
    navigateToObject : function (recordId) {
        var navEvt = $A.get("e.force:navigateToSObject");
        
        navEvt.setParams({
            "recordId": recordId,
            "slideDevName": "Details"
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