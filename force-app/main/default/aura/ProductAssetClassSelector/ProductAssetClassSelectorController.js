({
	afterScriptsLoaded : function(component, event, helper) {
        var assetClasses = window.DataCache.getData("assetClasses");
        if (assetClasses) {
            console.log('Asset classes retrieved from custom cache');
            component.set("v.assetClasses", assetClasses);
        } else {
	    	helper.loadAssetClasses(component);    
        }
	},
    
    assetClassChangeHandler : function(component, event, helper) {
        var changeEvent = component.getEvent("onchange");
        var currentAC_val = component.get("v.selectedValue");
        changeEvent.setParams({
            "value": currentAC_val
        });
        changeEvent.fire();
    },
    
    clearHandler : function(component, event, helper){
        var changeEvent = component.getEvent("onchange");
        var currentAC_val = component.get("v.selectedValue");
        var assetClasses = component.get("v.assetClasses");
        
        for(var i = 0; i < assetClasses.length; i++) {
        	if(assetClasses[i] == ""){
        		var emptyFilter = assetClasses[i];
        		component.set("v.selectedValue", emptyFilter);
        	}
        	if(assetClasses[i].Id == currentAC_val){
        		assetClasses[i].IsSelectedFilter__c = false;

        	}
        }

        changeEvent.setParams({
            "value": ""
        });
        
        changeEvent.fire();
    },
    
    acChangeHandler : function(component, event, helper) {
        /*var acListUpdate = event.getParam("assetClassTypes");
        var currentAC_val = component.get("v.selectedValue");
        
        for (var i = 0; i<acListUpdate.length; i++) {
        	if (acListUpdate[i].Id === currentAC_val) {
				acListUpdate[i].IsSelectedFilter__c = true;
           	}
       	}
       	if (acListUpdate.length == 1 && acListUpdate[0] != "" ){
       		acListUpdate[0].IsSelectedFilter__c = true;
       	    component.set("v.selectedValue", acListUpdate[0]);
        }

        acListUpdate.unshift("");       
        component.set("v.assetClasses", acListUpdate);
        component.find("acSelect").set("v.selectedValue", currentAC_val);*/
    }
    
})