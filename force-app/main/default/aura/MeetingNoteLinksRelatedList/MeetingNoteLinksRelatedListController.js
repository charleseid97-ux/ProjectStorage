({
	init : function(component, event, helper) {
        
		helper.load(component);
	},
    
    handleProductLevelChange : function(component, event, helper){
        helper.productLevelChange(component);
    }
})