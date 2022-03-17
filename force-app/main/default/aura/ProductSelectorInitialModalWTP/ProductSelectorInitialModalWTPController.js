({
   openModel: function(component, event, helper) {
      // for Display Model,set the "isOpen" attribute to "true"
       debugger;
       var WTPId = event.getParam("WTPId");
       var sObjectName = event.getParam("sObjectName");
       component.set("v.currentWTPId", WTPId);
       component.set("v.sObjectName", sObjectName);
       component.set("v.isOpen", true);
   },

    selectProduct: function(component, event, helper) {
      // for Hide/Close Model,set the "isOpen" attribute to "Fasle"
      helper.openProductSelector(component);
      debugger;  
      component.set("v.isOpen", false);
   }
})