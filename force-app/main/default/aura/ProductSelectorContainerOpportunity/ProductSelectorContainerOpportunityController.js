({
    doInit : function(component, event, helper) {
        //sets the Opp id attribute of the child cmp ProductSelectorDynamicRow
        component.find('ProductsDynamicList').set('v.currentOppId', component.get("v.OppRecordId"));
        
        var passSObjectName = $A.get("e.c:ProductSelectorPassSObjectNameEvt");
        passSObjectName.setParams({
            "sObjectName": component.get("v.currentSObject"),
            "recordId": component.get("v.OppRecordId")
            
        });       
        passSObjectName.fire();
        
        
    },
    saveProductToOpp: function(component, event, helper){
        debugger;
        var OppId = component.get("v.OppRecordId");
        var sProductList = event.getParam("selectedProducts");
        var deleteProductList = event.getParam("deleteProductList");
        helper.saveProductsToOpp(component, OppId, sProductList, deleteProductList);
    }
})