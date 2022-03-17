({
	init : function(component, event, helper) {
		helper.loadLinkedAccount(component);
	},
    loadAccountPlan : function(component, event, helper) {
        helper.accountPlanRedirect(component);
    },
    loadHierarchyComponent : function(component, event, helper) {
    	helper.loadHierarchyComponent(component);
	},
    loadKeyContactsComponent : function(component, event, helper) {
    	helper.loadKeyContactsComponentModal(component);
	},
    loadOrganigramComponent : function(component, event, helper) {
    	helper.loadOrganigramComponent(component);
	},
    loadTieringComponent : function(component, event, helper) {
    	helper.loadTieringComponent(component);
	},
    loadSocialComponent : function(component, event, helper) {
    	helper.loadSocialComponent(component);
	},
    showHierarchyDescription : function(component, event, helper) {
        component.set("v.description", "Group all instances of a client (e.g. BNP) into an Account hierarchy that reflects the global sales strategy, identifying the Ultimate Parent Company and all the related sub-accounts");
        component.set("v.hierarchyImage", "/resource/GAMHomepageIcons/Hierarchy_icon_100x100_Blue.png");
	},
    showTieringDescription : function(component, event, helper) {
        component.set("v.description", "Resource Allocation Matrix (pdf) & relevant company tier");
        component.set("v.tieringImage", "/resource/GAMHomepageIcons/Tiering_icon_100x100_Blue.png");
	},
    showOrganigramDescription : function(component, event, helper) {
        component.set("v.description", "Specific document to reflect the client’s organisation");
        component.set("v.organigramImage", "/resource/GAMHomepageIcons/Organigram_icon_100x100_Blue.png");
	},
    showPlanDescription : function(component, event, helper) {
        component.set("v.description", "Overview of the account background, account revenue potential, SWOT and provides the high level goals as well as detailed actions needed to reach strategic objectives");
        component.set("v.planImage", "/resource/GAMHomepageIcons/Account_Plan_icon_100x100_Blue.png");
	},
    showKeyContactDescription : function(component, event, helper) {
        component.set("v.description", "Decision Maker Matrix");
        component.set("v.keyContactsImage", "/resource/GAMHomepageIcons/Key_contacts_icon_100x100_Blue.png");
	},
    showSocialDescription : function(component, event, helper) {
        component.set("v.description", "Easy links to Google, LinkedIn and Twitter search results");
        component.set("v.socialImage", "/resource/GAMHomepageIcons/Social_Medias_icon_Black_100x100_Blue.png");
	},
    hideDescription : function(component, event, helper) {
    	component.set("v.description", "");
        component.set("v.hierarchyImage", "/resource/GAMHomepageIcons/Hierarchy_icon_100x100_Green.png");
        component.set("v.tieringImage", "/resource/GAMHomepageIcons/Tiering_icon_100x100_Green.png");
        component.set("v.organigramImage", "/resource/GAMHomepageIcons/Organigram_icon_100x100_Green.png");
        component.set("v.planImage", "/resource/GAMHomepageIcons/Account_Plan_icon_100x100_Green.png");
        component.set("v.keyContactsImage", "/resource/GAMHomepageIcons/Key_contacts_icon_100x100_Green.png");
        component.set("v.socialImage", "/resource/GAMHomepageIcons/Social_Medias_icon_Black_100x100_Green.png");
	}
})