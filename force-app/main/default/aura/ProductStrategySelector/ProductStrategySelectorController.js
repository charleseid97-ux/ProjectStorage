({
	afterScriptsLoaded : function(component, event, helper) {
        var strategies = window.DataCache.getData("strategies");
        if (strategies) {
            console.log('Strategies retrieved from custom cache');
            component.set("v.strategies", strategies);
        } else {
	    	helper.loadStrategies(component);    
        }
	},
    
    strategyChangeHandler : function(component, event, helper) {
        var changeEvent = component.getEvent("onchange");
        changeEvent.setParams({
            "value": component.get("v.selectedValue")
        });
        changeEvent.fire();
    },
    
    clearHandler : function(component, event, helper){
    	var changeEvent = component.getEvent("onchange");
        var currentStrat_val = component.get("v.selectedValue");
        var strategies = component.get("v.strategies");

        for(var i = 0; i < strategies.length; i++){
        	if(strategies[i] == ""){
        		var emptyFilter = strategies[i];
        		component.set("v.selectedValue", emptyFilter);        
        			
        	}
        	if(strategies[i].Id == currentStrat_val){
        		strategies[i].IsSelectedFilter__c = false;              
        	}
        }      
     
        changeEvent.setParams({
            "value": ""
        });
        changeEvent.fire();
    },
    
    sChangeHandler : function(component, event, helper) {
       	var stratListUpdate = event.getParam("strategyTypes");
       	var currentStratVal = component.get("v.selectedValue");
        
       	for (var i = 0; i<stratListUpdate.length; i++) {
       	if (stratListUpdate[i].Id === currentStratVal) {
            stratListUpdate[i].IsSelectedFilter__c = true;
        	}
        }
        if (stratListUpdate.length == 1 && stratListUpdate[0] != "" ){
            stratListUpdate[0].IsSelectedFilter__c = true;
            component.set("v.selectedValue", stratListUpdate[0]);
		}
        
        stratListUpdate.unshift("");
        component.set("v.strategies", stratListUpdate);
        component.find("strategySelect").set("v.selectedValue",currentStratVal);
    }
    
})