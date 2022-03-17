({
    doInit : function(component, event, helper) {
        //sets the WTP id attribute of the child cmp ProductSelectorDynamicRow
        component.find('ProductsDynamicList').set('v.currentWTPId', component.get("v.WTPRecordId"));
        
        var passSObjectName = $A.get("e.c:ProductSelectorPassSObjectNameEvt");
        passSObjectName.setParams({
            "sObjectName": component.get("v.currentSObject"),
            "recordId": component.get("v.WTPRecordId")
            
        });       
        passSObjectName.fire();
        
        
    },
    saveProductToWTP: function(component, event, helper){
        debugger;
        var WTPId = component.get("v.WTPRecordId");
        var sProductList = event.getParam("selectedProducts");
        var deleteProductList = event.getParam("deleteProductList");
        var selectedSharesList = event.getParam("selectedShares");
        var wtpId = event.getParam("wtpId");
        console.log('SLI >>><<< ',JSON.stringify(event.getParam("selectedShares")));
        helper.saveProductsToWTP(component, WTPId, sProductList, deleteProductList, selectedSharesList, wtpId);
    }
})