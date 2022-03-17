/**
 * Created by Noor on 1/19/2021.
 */

({
    init: function(component, event, helper) {
        helper.initializeBuyListDetail(component);
    },

    editBuyListDetail: function(component, event, helper){
        component.set("v.saveOpenES", true);
        component.set("v.editTrueES", false);
        component.set("v.textFieldDisabledES", false);
    },

    saveBuyListDetail: function(component, event, helper){
        helper.saveBuyListDetail(component);
    }

})