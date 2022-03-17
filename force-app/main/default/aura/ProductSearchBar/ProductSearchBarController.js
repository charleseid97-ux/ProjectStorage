({
    changePlaceHolderText: function(component, event, helper) {
        var objectType = component.get("v.objectType");
        if(objectType != 'COS'){
            component.set("v.placeHolder", "Search Products..");
        }else{
            component.set("v.placeHolder", "Search Investment Strategies..");
        }
    },
    keypressHandler : function(component, event, helper) {
        if (event.keyCode !== 13) {
            return;
        }
         var objectType = component.get("v.objectType");
        debugger;
        var changeEvent = component.getEvent("onchange");
        changeEvent.setParams({
            "value": event.target.value
        });
        changeEvent.fire();
    },
    clearHandler : function(component, event, helper) {
        component.find("searchInput").getElement().value = "";
        var changeEvent = component.getEvent("onchange");
        changeEvent.setParams({
            "value": ""
        });
        changeEvent.fire();
    }
})