({
	init : function(component, event, helper) {
		helper.loadLinkedAccount(component);
	},
    loadStrategicNewsComponent : function(component, event, helper) {
    	helper.loadStrategicNewsComponent(component);
    },
    loadActivityComponent : function(component, event, helper) {
    	helper.loadActivityComponent(component);
	},
    loadOpportunitiesComponent : function(component, event, helper) {
    	helper.loadOpportunitiesComponent(component);
	},
    loadOpportunityDashComponent : function(component, event, helper) {
    	helper.loadOpportunityDashComponent (component);
	},
    loadAUMComponent : function(component, event, helper) {
    	helper.loadAUMComponent(component);
	},
    loadReport : function(component, event, helper) {
    	helper.loadReport(component);
	},
    showCollaborationDescription : function(component, event, helper) {
        component.set("v.description", "Aggregated Strategic News from the entire Hierarchy");
        component.set("v.collaborationImage", "/resource/GAMHomepageIcons/Collaboration_icon_100x100_Blue.png");
	},
    showActivityDescription : function(component, event, helper) {
        component.set("v.description", "Tableau component with detailed Activity reporting");
        component.set("v.activityImage", "/resource/GAMHomepageIcons/Activity_icon_100x100_Blue.png");
	},
    showOpportunityDescription : function(component, event, helper) {
        component.set("v.description", "View an aggregated list of all Open Opportunities in the Hierarchy");
        component.set("v.opportunityImage", "/resource/GAMHomepageIcons/Opportunity_icon_100x100_Blue.png");
	},
    showOpportunityDashDescription : function(component, event, helper) {
        component.set("v.description", "Tableau component with detailed Opportunity reporting");
        component.set("v.opportunity2Image", "/resource/GAMHomepageIcons/Opp_Dashboard_icon_100x100_Blue.png");
	},
    showAUMDescription : function(component, event, helper) {
        component.set("v.description", "Tableau component with AUM and Inflows");
        component.set("v.aumImage", "/resource/GAMHomepageIcons/AuMFlows_icon_100x100_Blue.png");
	},
    showISDescription : function(component, event, helper) {
        component.set("v.description", "Coming soon to a screen near you...");
        component.set("v.isImage", "/resource/GAMHomepageIcons/Investment_Solutions_icon_100x100_Blue.png");
	},
    hideDescription : function(component, event, helper) {
    	component.set("v.description", "");
        component.set("v.collaborationImage", "/resource/GAMHomepageIcons/Collaboration_icon_100x100_Green.png");
        component.set("v.activityImage", "/resource/GAMHomepageIcons/Activity_icon_100x100_Green.png");
        component.set("v.opportunityImage", "/resource/GAMHomepageIcons/Opportunity_icon_100x100_Green.png");
        component.set("v.opportunity2Image", "/resource/GAMHomepageIcons/Opp_Dashboard_icon_100x100_Green.png");
        component.set("v.aumImage", "/resource/GAMHomepageIcons/AuMFlows_icon_100x100_Green.png");
        component.set("v.isImage", "/resource/GAMHomepageIcons/Investment_Solutions_icon_100x100_Black.png");
	}
})