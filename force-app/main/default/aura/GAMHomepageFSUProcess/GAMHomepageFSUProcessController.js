({
	init : function(component, event, helper) {
		helper.loadLinkedAccount(component);
	},
    loadProcessComponent : function(component, event, helper) {
    	helper.loadProcessComponent(component);
	},
    loadGlobalLocalReport : function(component, event, helper) {
    	helper.loadGlobalLocalReport(component);
	},
    loadFullBuyListComponent : function(component, event, helper) {
    	helper.loadFullBuyListComponent(component);
	},
    showGlobalDescription : function(component, event, helper) {
        component.set("v.description", "Consolidated Global & Local buy lists report");
        component.set("v.globalImage", "/resource/GAMHomepageIcons/GlobalLocal_Buy_List_icon_100x100_Blue.png");
	},
    showProcessDescription : function(component, event, helper) {
        component.set("v.description", "Identify Fund Selection Unit and Fund Selection Product reach of influence");
        component.set("v.processImage", "/resource/GAMHomepageIcons/FS_Process_Overview_icon_100x100_Blue.png");
	},
    showBuyListDescription : function(component, event, helper) {
        component.set("v.description", "Client’s Buy List (pdf) including Carmignac funds and ALL other funds");
        component.set("v.buyListImage", "/resource/GAMHomepageIcons/Full_Clients_Buy_List_icon_100x100_Blue.png");
	},
    hideDescription : function(component, event, helper) {
    	component.set("v.description", "");
        component.set("v.globalImage", "/resource/GAMHomepageIcons/GlobalLocal_Buy_List_icon_100x100_Green.png");
        component.set("v.processImage", "/resource/GAMHomepageIcons/FS_Process_Overview_icon_100x100_Green.png");
        component.set("v.buyListImage", "/resource/GAMHomepageIcons/Full_Clients_Buy_List_icon_100x100_Green.png");
	}
})