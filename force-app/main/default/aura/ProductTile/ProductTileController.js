({	
    
    doInit: function(component, event, helper) {
       	
        var abbre = component.get("v.abbreviation");
		var productType = component.get("v.product.RecordType.DeveloperName");
        var assetClassName = '';
        if (productType ==  'Asset_Class'){
            assetClassName = component.get("v.product.Name");
        } else if (productType ==  'Fund'){
            assetClassName = component.get("v.product.Legal_Status__c");
        } else if(component.get("v.product.Asset_Class__r.Name")) {
            assetClassName = component.get("v.product.Asset_Class__r.Name"); 
        } else {
            assetClassName = 'Asset Class'; 
        }

        var assetClassNameWordList = '';

        assetClassNameWordList = assetClassName.split(" ");
       
        if(assetClassNameWordList.length == 1){
            component.set("v.abbreviation", assetClassNameWordList[0].substring(0,2));
        }
        else if(assetClassNameWordList.length == 2 && /^[a-zA-Z]+$/.test(assetClassNameWordList[1]) ){
            var firstLetter = assetClassNameWordList[0].substring(0,1);
            var secondLetter = assetClassNameWordList[1].substring(0,1);
            component.set("v.abbreviation", firstLetter + secondLetter);
        }
        else if(assetClassNameWordList.length == 3 && /^[a-zA-Z]+$/.test(assetClassNameWordList[2]) ){
            var firstLetter = assetClassNameWordList[0].substring(0,1);
            var secondLetter = assetClassNameWordList[2].substring(0,1);
            component.set("v.abbreviation", firstLetter + secondLetter);
        }
    }, 
    
    
    productSelected : function(component, event, helper) {
        debugger;
        var sproduct = component.get("v.product.Id");
        var sProductName = component.get("v.product.Name");
        var productRecordType = component.get("v.product.RecordType.Name");
		var productTileIdEvent = $A.get("e.c:ProductGetProdIdEvent");
		productTileIdEvent.setParams({
            "prodId": sproduct,
            "prodName": sProductName,
            "prodRecordType": productRecordType
        });		
		productTileIdEvent.fire();
	}
    
   
    
})