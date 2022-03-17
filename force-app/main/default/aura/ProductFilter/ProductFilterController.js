({
    doInit: function(component, event, helper) {
        var prodFilt = component.get("v.objectType");
        component.find('searchBar').set('v.objectType', prodFilt);
    },
    
    searchKeyChangeHandler : function(component, event, helper) {
        
        var productFilterChangeEvent = $A.get("e.c:ProductFilterChange");
        var prodFilt = component.get("v.objectType");
        if(prodFilt != 'COS'){
            productFilterChangeEvent.setParams({
                "searchKey": event.getParam("value"),
            });
        }else{
            productFilterChangeEvent.setParams({
                "searchKey": event.getParam("value")
            });
        }
        productFilterChangeEvent.fire();
    },
    
    assetClassChangeHandler : function(component, event, helper) {
        var productFilterChangeEvent = $A.get("e.c:ProductFilterChange");
        var prodFilt = component.get("v.objectType");
        
        var subAssetClassSel = component.find("subAssetClassSel");
        var subAssetClassValue = subAssetClassSel.get("v.selectedValue");    	        	
        var newValue = event.getParam("value");
        debugger;
        productFilterChangeEvent.setParams({
            "assetClass": newValue,
            "subAssetClass": subAssetClassValue.Id
        });            
        //component.find("subAssetClassSel").set("v.selectedValue", "");
        //component.find("stratgegySel").set("v.selectedValue", "");
        productFilterChangeEvent.fire();
        
    },
    
    subAssetClassChangeHandler : function(component, event, helper) {
        var productFilterChangeEvent = $A.get("e.c:ProductFilterChange");
        var prodFilt = component.get("v.objectType");
        
        //Retain values of other filters that were populated automatically when only one value was present. Blank out values below this level
        var assetClassSel = component.find("assetClassSel");
        var assetClassValue = assetClassSel.get("v.selectedValue");    	        	
        var newValue = event.getParam("value");

        productFilterChangeEvent.setParams({                
            "assetClass": assetClassValue.Id,
            "subAssetClass": newValue
        });            
        //component.find("stratgegySel").set("v.selectedValue", ""); 
        productFilterChangeEvent.fire();
    },
    
    sriChangeHandler : function(component, event, helper) {
        
        var sriChkBx = component.find("sriChkBx");
        
        var fundFilterChangeEvent = $A.get("e.c:ProductFilterChange");
        fundFilterChangeEvent.setParams({
            "sri": sriChkBx.get("v.value")
        });
        fundFilterChangeEvent.fire();
    },

    oeicChangeHandler : function(component, event, helper) {
        
        var oeicChkBx = component.find("oeicChkBx");
        
        var fundFilterChangeEvent = $A.get("e.c:ProductFilterChange");
        fundFilterChangeEvent.setParams({
            "oeic": oeicChkBx.get("v.value")
        });
        fundFilterChangeEvent.fire();
    },
    
    /*,
    strategyChangeHandler : function(component, event, helper) {
        
        var productFilterChangeEvent = $A.get("e.c:ProductFilterChange");
        var newValue = event.getParam("value");
        var prodFilt = component.get("v.objectType");
        
        var assetClassSel = component.find("assetClassSel");
        var assetClassValue = assetClassSel.get("v.selectedValue");
        
        var subAssetClassSel = component.find("subAssetClassSel");
        var subAssetClassValue = subAssetClassSel.get("v.selectedValue");
        
        productFilterChangeEvent.setParams({
            "strategy": newValue,
            "assetClass": assetClassValue.Id,
            "subAssetClass": subAssetClassValue.Id,
        });
        productFilterChangeEvent.fire();
    }		*/
})