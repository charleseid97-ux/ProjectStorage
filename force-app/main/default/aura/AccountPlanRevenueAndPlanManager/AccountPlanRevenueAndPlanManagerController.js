({
    init: function(component, event, helper) {   
        helper.initializePlanAndRevenue(component);
    },
    
    editExecutiveSummary: function(component, event, helper){
        component.set("v.saveOpenES", true);     
        component.set("v.editTrueES", false);
        component.set("v.textFieldDisabledES", false);
    },
    
    saveExecutiveSummary: function(component, event, helper){
        helper.saveExecutiveSummary(component);        
    }
    
})