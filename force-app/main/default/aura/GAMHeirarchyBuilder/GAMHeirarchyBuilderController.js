({
	init : function(component, event, helper) {
        helper.getGAMRecord(component);
    },
    cancel : function(component, event, helper) {
        helper.cancel(component);
    },
    buildGroupsCtrl : function(component, event, helper) {
        helper.buildGroupsForGAM(component);
    },
    deleteGroupingsCtrl : function(component, event, helper) {
        helper.deleteGroupsForGAM(component);
    },
    overrideDeleteGroupsCtrl : function(component, event, helper) {
        helper.overrideDeleteGroups(component);
    },
    buildHierarchyCtrl : function(component, event, helper) {
        helper.buildHierarchyForGAM(component);
    }
})