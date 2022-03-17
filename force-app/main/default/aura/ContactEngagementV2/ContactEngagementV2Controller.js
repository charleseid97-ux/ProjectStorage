({
	doInit : function(component, event, helper){        
        helper.returnMetrics(component);
    },
    drillDownProduct : function(component, event, helper) {
        var clickedSection = event.getSource().get("v.value");
        component.set("v.currentType", clickedSection);
        component.set("v.engagementScreen", 2);
        component.set("v.currentSection", "product");
        helper.getDrillDown(component, clickedSection);
    },
    drillDownContent : function(component, event, helper) {
        var clickedSection = event.getSource().get("v.value");
        component.set("v.currentType", clickedSection);
        component.set("v.engagementScreen", 3);
        component.set("v.currentSection", "content");
        helper.getDrillDown(component, clickedSection);
    },
    drillDownMarketing : function(component, event, helper) {
        var clickedSection = event.getSource().get("v.value");
        component.set("v.currentType", clickedSection);
        component.set("v.engagementScreen", 4);
        component.set("v.currentSection", "marketing");
        helper.getDrillDown(component, clickedSection);
    },
    filterResults : function(component, event, helper) {
        var clickedTheme = event.getSource().get("v.value");
        component.set("v.currentTheme", clickedTheme);
        var currentPage = component.get("v.engagementScreen");
        var clickedSection = component.get("v.currentType");
        if(currentPage == 1) {
            helper.returnMetrics(component);
        } else {
            helper.getDrillDown(component, clickedSection);
        }
    },
    engagementMain : function(component, event, helper) {
        component.set("v.engagementScreen", 1);
        component.set("v.digitalInteractions", null);
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