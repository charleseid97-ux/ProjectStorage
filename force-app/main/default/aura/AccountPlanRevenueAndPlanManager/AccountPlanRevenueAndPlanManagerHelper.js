({
    initializePlanAndRevenue:function(component) {        
        var recordId = component.get("v.recordId");      
        var actionForAccES = component.get("c.initializeExecutiveSummary");
        actionForAccES.setParams({
            "accId": recordId
        });  
        debugger;
        actionForAccES.setCallback(this, function(response){
            var status = response.getState(); 
            debugger;
            if (status === 'SUCCESS') {
                var result = response.getReturnValue();
                component.set("v.companyNameVal", result.Company__r.Name);
                if(!result.Executive_Summary__c ){
                    component.set("v.executiveSummaryVal", "");
                    component.set("v.buttonStatementES", "Create Executive Summary");
                }
                else{
                    component.set("v.executiveSummaryVal", result.Executive_Summary__c);
                    component.set("v.buttonStatementES", "Edit Executive Summary");
                } 
            }
        });
        $A.enqueueAction(actionForAccES);
    },
    saveExecutiveSummary:function(component){
        var recordId = component.get("v.recordId"); 
        var saveAction = component.get("c.saveExecutiveSummaryCtrl");
        var executiveSummaryVal = component.get("v.executiveSummaryVal");
        debugger;
        saveAction.setParams({
            "accId": recordId,
            "executiveSummaryVal": executiveSummaryVal
        });
        saveAction.setCallback(this, function(response){
            var status = response.getState();
            if(status == 'SUCCESS'){
                var result = response.getReturnValue();
                component.set("v.buttonStatementES", "Edit Executive Summary");
                component.set("v.editTrueES", true);
                component.set("v.saveOpenES", false);
                component.set("v.textFieldDisabledES", true);
        		
            }
        });
        $A.enqueueAction(saveAction);        
    }

})