({
	init : function(component, event, helper) {
		
	},
    showTaxiDescription : function(component, event, helper) {
        component.set("v.description", "Coming soon to a screen near you...");
        component.set("v.taxiImage", "/resource/GAMHomepageIcons/Taxi_Report_icon_100x100_Blue.png");
	},
    showMGMTDescription : function(component, event, helper) {
        component.set("v.description", "Coming soon to a screen near you...");
        component.set("v.mgmtImage", "/resource/GAMHomepageIcons/Management_reports_icon_100x100_Blue.png");
	},
    showDailyDescription : function(component, event, helper) {
        component.set("v.description", "Coming soon to a screen near you...");
        component.set("v.dailyImage", "/resource/GAMHomepageIcons/Daily_reports_icon_100x100_Blue.png");
	},
    hideDescription : function(component, event, helper) {
    	component.set("v.description", "");
        component.set("v.taxiImage", "/resource/GAMHomepageIcons/Taxi_Report_icon_100x100_Black.png");
        component.set("v.mgmtImage", "/resource/GAMHomepageIcons/Management_reports_icon_100x100_Black.png");
        component.set("v.dailyImage", "/resource/GAMHomepageIcons/Daily_reports_icon_100x100_Black.png");
	}
})