({
	doInit : function(component, event, helper){        
        helper.returnMetrics(component);
    },
    showQRCIText : function(component, event, helper) {
        component.set("v.CIText", "Quarterly Report");
	},
    showFNCIText : function(component, event, helper) {
        component.set("v.CIText", "Flash Note");
	},
    showVCIText : function(component, event, helper) {
        component.set("v.CIText", "Video");
	},
    showFFCIText : function(component, event, helper) {
        component.set("v.CIText", "Funds Focus");
	},
    showCNCIText : function(component, event, helper) {
        component.set("v.CIText", "Carmignac Note");
	},
    showPSCIText : function(component, event, helper) {
        component.set("v.CIText", "Pro Space");
	},
    hideCIText : function(component, event, helper) {
    	component.set("v.CIText", "");
	},
    showNMAText : function(component, event, helper) {
        component.set("v.MAText", "Newsletters");
	},
    showEMAText : function(component, event, helper) {
        component.set("v.MAText", "Events");
	},
    showWMAText : function(component, event, helper) {
        component.set("v.MAText", "Webinars");
	},
    hideMAText : function(component, event, helper) {
    	component.set("v.MAText", "");
	}
})