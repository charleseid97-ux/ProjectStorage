({
    initializeBuyListDetail:function(component) {        
        var recordId = component.get("v.recordId");      
        var actionForAccES = component.get("c.initializeBuyListDetail");
        actionForAccES.setParams({
            "accId": recordId
        });  
        debugger;
        actionForAccES.setCallback(this, function(response){
            var status = response.getState(); 
            debugger;
            if (status === 'SUCCESS') {
                var result = response.getReturnValue();
                if(!result.Buy_List_Information__c ){
                    component.set("v.buyListDetailVal", "");
                    component.set("v.buttonStatementES", "Create Buy List Detail");
                }
                else{
                    component.set("v.buyListDetailVal", result.Buy_List_Information__c);
                    component.set("v.buttonStatementES", "Edit Buy List Detail");
                } 
            }
        });
        $A.enqueueAction(actionForAccES);
    },
    saveBuyListDetail:function(component){
        var recordId = component.get("v.recordId"); 
        var saveAction = component.get("c.saveBuyListDetailCtrl");
        var buyListDetailVal = component.get("v.buyListDetailVal");
        debugger;
        saveAction.setParams({
            "accId": recordId,
            "buyListDetailVal": buyListDetailVal
        });
        saveAction.setCallback(this, function(response){
            var status = response.getState();
            if(status == 'SUCCESS'){
                var result = response.getReturnValue();
                component.set("v.buttonStatementES", "Edit Buy List Detail");
                component.set("v.editTrueES", true);
                component.set("v.saveOpenES", false);
                component.set("v.textFieldDisabledES", true);
        		
            }
        });
        $A.enqueueAction(saveAction);        
    }

})