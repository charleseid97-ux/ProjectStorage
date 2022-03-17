({
    createInitialObjectData: function(component, event) {
        
        var productItemList = component.get("v.productList");
        var currentWTPId = component.get("v.currentWTPId");
        var actionForWTP = component.get("c.confirmLinkedProductsToWTP");
        actionForWTP.setParams({
            "currentWTPId": currentWTPId
        });
        actionForWTP.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS'){
                var result = response.getReturnValue();
                if(result.length != 0){
                    for(var i = 0; i < result.length; i++){
                        
                        productItemList.push({
                            'sobjectType': 'Work_Together_Process_Product__c',
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
                            'Work_Together_Process__c' : component.get("v.currentWTPId")
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
        $A.enqueueAction(actionForWTP);
        
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
            'sobjectType': 'Work_Together_Process_Product__c',
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
            'Work_Together_Process__c' : component.get("v.currentWTPId")
        });
       

        component.set("v.productList", productItemList);
    },
    
    
})