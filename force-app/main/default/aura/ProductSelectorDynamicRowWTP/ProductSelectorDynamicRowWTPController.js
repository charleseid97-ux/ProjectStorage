({
    
    // function call on component Load
    init: function(component, event, helper) {
        
    },
    
    onWTPSet: function(component, event, helper) {
        var RFPId = component.get("v.currentWTPId");
        helper.createInitialObjectData(component, event);
    },
    
    updateProductList: function(component, event, helper) {
        var prodId = event.getParam("prodId");
        var prodName = event.getParam("prodName");
        var recordType = event.getParam("prodRecordType");        
        helper.updateProductList(component, event, prodId, prodName, recordType);
    },
    
    // function to save the Records 
    Save: function(component, event, helper) {
        var productList = component.get("v.productList");
        var deleteProductList = component.get("v.deleteProductList");
        var shareList = component.get("v.selectedShares");
        var saveProductsEvent = $A.get("e.c:ProductSelectorSaveListToWTP");
        var RFPId = component.get("v.currentWTPId");


        console.log('SLI <> ', RFPId);

        saveProductsEvent.setParams({
            "selectedProducts" : productList,
            "deleteProductList" : deleteProductList,
            "selectedShares": shareList,
            "wtpId": RFPId
        });
        saveProductsEvent.fire();
        
    },
    
    
    removeDeletedRow: function(component, event, helper) {
        // get the selected row Index for delete, from Lightning Event Attribute  
        var index = event.getParam("indexVar");
        var AllRowsList = component.get("v.productList");
        var deleteProductList = component.get("v.deleteProductList");
        //push to delete row list
        deleteProductList.push({
            'sobjectType': 'Work_Together_Process_Product__c',
            'Name':AllRowsList[index].Name,
            'Id': AllRowsList[index].Id
        });
      
        AllRowsList.splice(index, 1);
        var AllRowsAfterSplice = AllRowsList;
        // set the contactList after remove selected row element  
        component.set("v.productList", AllRowsList);
    },


    getSharesAdded: function(component, event, helper)
    {
        component.set("v.selectedShares", event.getParam('value'));
        console.log('SLI >>> ', JSON.stringify(event.getParam('value')));
    }
})