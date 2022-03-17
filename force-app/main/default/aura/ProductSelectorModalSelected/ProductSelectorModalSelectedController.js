({
       openModel: function(component, event, helper) {
          // for Display Model,set the "isOpen" attribute to "true"
     
          	var selectedProdName = event.getParam("prodName");
          	var selectedProdId = event.getParam("prodId");
         	component.set("v.selectedProdName", selectedProdName);
           	component.set("v.selectedProdId", selectedProdId);
          	component.set("v.isOpen", true);
       },
     
       closeModel: function(component, event, helper) {
          // for Hide/Close Model,set the "isOpen" attribute to "False"  
          component.set("v.isOpen", false);
          
          //need to reOpen ProductTileListCOS - is onyl recieved by the ProductTileListCOS so will not affect ProductTileList
          var modalEvent = $A.get("e.c:ProductSelectorReOpenCOSTilesEvt");
	      modalEvent.setParams({
	          "openProdlist": true                                
	        });
	      modalEvent.fire();
          
       },
 	
    
   	confirmSelection: function(component, event, helper) {
        var confirmProdSelectedEvent = $A.get("e.c:ProductTileSelectedUserConfirmationEvent");
        var prodId = component.get("v.selectedProdId");
        confirmProdSelectedEvent.setParams({
                "confirmProductTileSelected": "True",
            	"confirmProdId" : prodId    
        });
        confirmProdSelectedEvent.fire();
      	//closes modal box 
      	component.set("v.isOpen", false);
   	},
})