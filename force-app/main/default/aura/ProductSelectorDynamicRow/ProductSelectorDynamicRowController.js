({
    
    // function call on component Load
    init: function(component, event, helper) {
        
    },
    
    onOppSet: function(component, event, helper) {
        var RFPId = component.get("v.currentOppId");
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
        var saveProductsEvent = $A.get("e.c:ProductSelectorSaveListToOpp"); 
        saveProductsEvent.setParams({
            "selectedProducts" : productList,
            "deleteProductList" : deleteProductList           
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
            'sobjectType': 'Opportunity_Product__c',
            'Name':AllRowsList[index].Name,
            'Id': AllRowsList[index].Id
        });
      
        AllRowsList.splice(index, 1);
        var AllRowsAfterSplice = AllRowsList;
        debugger;
        // set the contactList after remove selected row element  
        component.set("v.productList", AllRowsList);
    },
})