({
   openModel: function(component, event, helper) {
      // for Display Model,set the "isOpen" attribute to "true"
       debugger;
       var OppId = event.getParam("OppId");
       var sObjectName = event.getParam("sObjectName");
       component.set("v.currentOppId", OppId);
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