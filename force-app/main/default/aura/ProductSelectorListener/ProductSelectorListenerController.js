({
    /*
     * Upon initialization I need to set sObject Type and assess whether a Product has been linked
     */
    doInit: function(component, event, helper) {
        debugger;
       	helper.openProductSelector(component);
       
    },
    openUpdateModal: function(component, event, helper) {
      component.set("v.productSelectorOpen", true);       
    }
    
})