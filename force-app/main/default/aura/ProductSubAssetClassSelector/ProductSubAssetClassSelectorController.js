({
	afterScriptsLoaded : function(component, event, helper) {
        var subAssetClasses = window.DataCache.getData("subAssetClasses");
        if (subAssetClasses) {
            console.log('Sub Asset classes retrieved from custom cache');
            component.set("v.subAssetClasses", subAssetClasses);
        } else {
	    	helper.loadSubAssetClasses(component);    
        }
	},
    
    subAssetClassChangeHandler : function(component, event, helper) {
        var changeEvent = component.getEvent("onchange");
        var currentSAC_val = component.get("v.selectedValue");
        changeEvent.setParams({
            "value": currentSAC_val
        });
        changeEvent.fire();
    },
    
    clearHandler : function(component, event, helper){
    	var changeEvent = component.getEvent("onchange");
        var currentAC_val = component.get("v.selectedValue");
        var subAssetClasses = component.get("v.subAssetClasses");
        
        for(var i = 0; i < subAssetClasses.length; i++){
        	if(subAssetClasses[i] == ""){
        		var emptyFilter = subAssetClasses[i];
        		component.set("v.selectedValue", emptyFilter);
        	}
        	if(subAssetClasses[i].Id == currentAC_val){
        		subAssetClasses[i].IsSelectedFilter = false;
        	}       
        
        }       

        changeEvent.setParams({
            "value": ""
        });
        changeEvent.fire();
    },
    
    
    sacChangeHandler : function(component, event, helper) {
        /*var sacListUpdate = event.getParam("subAssetClassTypes");
        var currentSAC_val = component.get("v.selectedValue");
        
        for(var i = 0; i<sacListUpdate.length; i++){
        	if(sacListUpdate[i].Id === currentSAC_val){
        		sacListUpdate[i].IsSelectedFilter__c = true; 
            } 
        }
        
        if (sacListUpdate.length == 1 && sacListUpdate[0] != "" ){
        	sacListUpdate[0].IsSelectedFilter__c = true;
            component.set("v.selectedValue", sacListUpdate[0]);           
        }
                
        sacListUpdate.unshift("");
        component.set("v.subAssetClasses", sacListUpdate);
        component.find("sacSelect").set("v.selectedValue",currentSAC_val);*/
    }
    
})