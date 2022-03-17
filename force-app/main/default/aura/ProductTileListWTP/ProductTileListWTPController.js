({
    doInit: function(component, event, helper) {
        
        var filterObject = {
            searchKey: '',
            assetClass: '',
            subAssetClass: '',
            strategy: ''
        }
        
        component.set("v.filterObject", filterObject);        
        //sets the openModal attribute to true which in turn will trigger an event to open the Initial Modal screen
        helper.loadProducts(component);
    },
    
    onPreviousPage: function(component, event, helper) {
        var page = component.get("v.page") || 1;
        var direction = event.getParam("direction");
        page = page - 1;
        helper.loadProducts(component, page);
    },
    
    onNextPage: function(component, event, helper) {
        var page = component.get("v.page") || 1;
        var direction = event.getParam("direction");
        page = page + 1;
        helper.loadProducts(component, page);
        
    },
    
    
    onModalInitialization: function(component, event, helper) {
        
        //helper.getLinkedProduct(component);
    },
    
    // Need to set the sObject Name attribute and RFp RecordId
    setSObjectName: function(component, event, helper) {
        var sObjectName = event.getParam("sObjectName");
        
        if(sObjectName == 'Case'){
            var WTPRecordId = event.getParam("recordId"); 
            component.set("v.sObjectName", sObjectName);
            component.set("v.WTPId", WTPRecordId);            
        }
        
    },
    
    
    
    productFilterChangeHandler: function(component, event, helper) {     
        var filterObject = component.get("v.filterObject");
        if (event.getParam("searchKey") !== undefined) {
            filterObject.searchKey = event.getParam("searchKey");
        }
        if (event.getParam("assetClass") !== undefined) {
            filterObject.assetClass = event.getParam("assetClass");
        }
        if (event.getParam("subAssetClass") !== undefined) {
            var subAssetClass = event.getParam("subAssetClass");
            filterObject.subAssetClass = event.getParam("subAssetClass");
        }
        if (event.getParam("strategy") !== undefined) {
            var strategy = event.getParam("strategy");
            filterObject.strategy = event.getParam("strategy");
        }
        if (event.getParam("sri") !== undefined) {
            filterObject.sri = event.getParam("sri");
        }
        
        if (event.getParam("oeic") !== undefined) {
            filterObject.oeic = event.getParam("oeic");
        }
        
        console.log(filterObject);
        helper.loadProducts(component);
    },
    
    onAssetClassFilterChange: function(component, event, helper){             
        
        var acOptionChange = $A.get("e.c:ProductSelectorAssetClassFilterEvent");     
        var resultingACs = component.get("v.asset_classes");     
        var acOptionChangesValues = acOptionChange.getParam("assetClassTypes");
        acOptionChange.setParams({"assetClassTypes" : resultingACs});
        acOptionChange.fire(); 
        
    },
    
    onSubAssetClassFilterChange: function(component, event, helper){               
        
        var sacOptionChange = $A.get("e.c:ProductSelectorSubAssetClassFilterEvent");     
        var resultingSACs = component.get("v.sub_asset_classes");
        var sacOptionChangesValues = sacOptionChange.getParam("subAssetClassTypes");
        sacOptionChange.setParams({"subAssetClassTypes" : resultingSACs});            
        sacOptionChange.fire(); 
    },
    
    /*onStrategyFilterChange: function(component, event, helper){  
        var stratOptionChange = $A.get("e.c:ProductSelectorStrategyFilterEvent");
        var resultingStrats = component.get("v.strategies");
        var stratOptionChangesValues = stratOptionChange.getParam("strategyTypes");
        stratOptionChange.setParams({"strategyTypes" : resultingStrats});
        stratOptionChange.fire(); 
        
    },*/
    confirmSelectedProduct: function(component, event, helper){
        var selectProdName = event.getParam("prodName");
        var selectProdId = event.getParam("prodId");
        var selectProdRecordType = event.getParam("prodRecordType");
        var sObjectName = component.get("v.sObjectName");
        if(sObjectName === 'Case'){
            component.set("v.productSelectedName", selectProdName);
            var prodSelectedEvent = $A.get("e.c:ProductSelectorTileSelectedAddToDynamicListWTPEvt");
            prodSelectedEvent.setParams({
                "prodName": selectProdName,
                "prodId": selectProdId,
                "prodRecordType": selectProdRecordType
                
            });
            prodSelectedEvent.fire();
        }
    }
})