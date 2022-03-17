({
    createInitialObjectData: function(component, event) {
        
        var productItemList = component.get("v.productList");
        var currentOppId = component.get("v.currentOppId");
        var actionForOpp = component.get("c.confirmLinkedProductsToOpp");
        actionForOpp.setParams({
            "currentOppId": currentOppId
        });
        actionForOpp.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS'){
                var result = response.getReturnValue();
                if(result.length != 0){
                    for(var i = 0; i < result.length; i++){
                        
                        productItemList.push({
                            'sobjectType': 'Opportunity_Product__c',
                            'Id': result[i].Id,
                            'Name': result[i].Product__r.Name,
                            'Product__r': {
                                			'Name':result[i].Product__r.Name , 
                                			'sobjectType':'Product__c',
                                			'RecordType' : {
                                                'sobjectType':'RecordType',
                                                'Name': result[i].Product__r.RecordType.Name
                                            }
                            			},
                            'Product__c' : result[i].Product__c,
                            'Opportunity__c' : component.get("v.currentOppId")
                        });
                        
                    }
                }
            }
            /*
             * Initializing both lists as the same
             */
            
            component.set("v.productList", productItemList);
            component.set("v.deleteProductList", []);
        });
        $A.enqueueAction(actionForOpp);
        
    },
    
    
    updateProductList: function(component, event, prodId, prodName, recordType){
        var productItemList = component.get("v.productList");
        for(var i = 0; i < productItemList.length; i++){           
            if(productItemList[i].Product__c == prodId){
                alert("You have already added " + prodName);
				return;                
            }
        }
        
        productItemList.push({
            'sobjectType': 'Opportunity_Product__c',
            'Name': prodName,
            'Product__r': {
                'Id': prodId,
                'Name':prodName , 
                'sobjectType':'Product__c',
                'RecordType' : {
                    'sobjectType':'RecordType',
                    'Name': recordType
                }
            },
            'Product__c' : prodId,
            'Opportunity__c' : component.get("v.currentOppId")
        });
       

        component.set("v.productList", productItemList);
    },
    
    
})