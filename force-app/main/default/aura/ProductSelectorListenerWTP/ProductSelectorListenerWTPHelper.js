({
    
    
    openProductSelector: function(component){
        var sObjectName = component.get("v.sObjectName");
         var recordId = component.get("v.recordId");
        if(component.get("v.vfRecordId")){
        	recordId = component.get("v.vfRecordId");
        }
        
       if(component.get("v.vfSObject")){
        	sObjectName = component.get("v.vfSObject");
        }
        debugger;
        
        if(sObjectName == "Case"){
            var actionForWTP = component.get("c.confirmLinkedProductsToWTP");
            actionForWTP.setParams({
                "currentWTPId": recordId            
            });
            actionForWTP.setCallback(this, function(response){              
                var status = response.getState();
                if (status === 'SUCCESS'){
                    var result = response.getReturnValue();                    
                    if(result.length != 0){
                        
                    }
                    else{
                        var modalEvent = $A.get("e.c:ProductSelectorInitialModalWTPEvt");
                        debugger;
                        modalEvent.setParams({
                            "openModal": true,
                            "WTPId": recordId,
                            "sObjectName": sObjectName                                
                        });
                        modalEvent.fire();
                    }
                }
            });
            $A.enqueueAction(actionForWTP);
        }
    },
    openProductSelectorUpdate: function(component){
        debugger;
        var sObjectName = component.get("v.sObjectName");
        var recordId = component.get("v.recordId");
        var modalEvent = $A.get("e.c:ProductSelectorInitialModalWTPEvt");
        modalEvent.setParams({
            "openModal": true,
            "WTPId": recordId,
            "sObjectName": sObjectName                                
        });
        debugger;
        modalEvent.fire();
    }
})