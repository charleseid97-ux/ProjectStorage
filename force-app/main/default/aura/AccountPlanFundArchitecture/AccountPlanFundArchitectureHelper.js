/**
 * Created by Noor on 1/19/2021.
 */
({
    initializeBuyListDetail:function(component) {
        var recordId = component.get("v.recordId");
        var actionForAccES = component.get("c.initializeBuyListSummary");
        actionForAccES.setParams({
            "accId": recordId
        });
        //debugger;
        actionForAccES.setCallback(this, function(response){
            var status = response.getState();
            debugger;
            if (status === 'SUCCESS') {
                var result = response.getReturnValue();
                component.set("v.companyNameVal", result.Company__r.Name);
                if(!result.Third_Party_Fund_Architecture__c ){
                    component.set("v.buyListDetailVal", "");
                    component.set("v.buttonStatementES", "Create 3RD PARTY FUND");
                }
                else{
                    component.set("v.buyListDetailVal", result.Third_Party_Fund_Architecture__c);
                    component.set("v.buttonStatementES", "Edit 3RD PARTY FUND");
                }
            }
        });
        $A.enqueueAction(actionForAccES);
    },
    saveBuyListDetail:function(component){
        var recordId = component.get("v.recordId");
        var saveAction = component.get("c.saveBuyListSummaryCtrl");
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
                component.set("v.buttonStatementES", "Edit 3RD PARTY FUND");
                component.set("v.editTrueES", true);
                component.set("v.saveOpenES", false);
                component.set("v.textFieldDisabledES", true);

            }
        });
        $A.enqueueAction(saveAction);
    }

})