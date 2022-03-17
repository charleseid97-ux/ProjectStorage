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
       
        
        
        if(sObjectName == "Opportunity"){
            var actionForOpp = component.get("c.confirmLinkedProductsToOpp");
            actionForOpp.setParams({
                "currentOppId": recordId            
            });
            actionForOpp.setCallback(this, function(response){              
                var status = response.getState();
                if (status === 'SUCCESS'){
                    var result = response.getReturnValue();                    
                    if(result.length != 0){
                        
                    }
                    else{
                        var modalEvent = $A.get("e.c:ProductSelectorInitialModalOppEvt");
                        debugger;
                        modalEvent.setParams({
                            "openModal": true,
                            "OppId": recordId,
                            "sObjectName": sObjectName                                
                        });
                        modalEvent.fire();
                    }
                }
            });
            $A.enqueueAction(actionForOpp);
        }
    },
    openProductSelectorUpdate: function(component){
        debugger;
        var sObjectName = component.get("v.sObjectName");
        var recordId = component.get("v.recordId");
        var modalEvent = $A.get("e.c:ProductSelectorInitialModalCOSEvt");
        modalEvent.setParams({
            "openModal": true,
            "COSId": recordId,
            "sObjectName": sObjectName                                
        });
        debugger;
        modalEvent.fire();
    }
})