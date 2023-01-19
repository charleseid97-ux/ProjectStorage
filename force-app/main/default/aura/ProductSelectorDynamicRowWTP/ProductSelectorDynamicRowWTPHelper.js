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
    // START : JLC MODIFICATION : All Products Selection Handler Method  : 14/06/2022
    loadAllProducts : function(component,event,helper){
        let action = component.get("c.getProductListUnfiltered");
        action.setCallback(this, function(response) {
            let state = response.getState();
            if (state === "SUCCESS") {  
                let resultObtained = response.getReturnValue();
				//List to store product ids list
                let productIdsList = [];
                //Getting the final list to send to APEX. 
                let productItemList = component.get("v.productList");
                //Retrieving the IDs of the Products from the Product List
                for(let i = 0; i < productItemList.length; i++){
                    productIdsList.push(productItemList[i].Product__c);
                }
                //Filtering the results list from APEX
                let filteredResultsList = resultObtained.filter(filteredItem => !productIdsList.includes(filteredItem.Id));
                
                //Populating and Structuring the Product Item List
                for(let x = 0; x < filteredResultsList.length; x++){
                    productItemList.push({
                        'sobjectType': 'Work_Together_Process_Product__c',
                        'Name': filteredResultsList[x].Name,
                        'Product__r': {
                            'Id': filteredResultsList[x].Id,
                            'Name':filteredResultsList[x].Name, 
                            'sobjectType':'Product__c',
                            'RecordType' : {
                                'sobjectType':'RecordType',
                                'Name': filteredResultsList[x].RecordType.Name
                            }
                        },
                        'Product__c' : filteredResultsList[x].Id,
                        'Work_Together_Process__c' : component.get("v.currentWTPId")
                    });
                } 
                //Setting the final Product List with the updated list of all products
                component.set("v.productList", productItemList);
                //Getting the button's source that fired the method.
                let allProductsButton = event.getSource();
                //Disabling the button after selecting all products to avoid reselection
                allProductsButton.set('v.disabled',true);
                //Informing the user about the next action by changing the label of button
                allProductsButton.set('v.label','All Products Added. Proceed to Save.');

            }
            else if (state === "INCOMPLETE") {
                console.log('JLC : TRANSACTION INCOMPLETE');
            } else if (state === "ERROR") {
                let errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("JLC : Error message: " + errors[0].message);
                    }
                } else {
                    console.log("JLC : Unknown error");
                }
            }
        });
        $A.enqueueAction(action);
    },
    // END : JLC MODIFICATION : All Products Selection Handler Method   : 14/06/2022
 
})