({
	cancel : function(component, event, helper) {
		$A.get("e.force:closeQuickAction").fire();
    },
    getGAMRecord : function(component) {
        var accId = component.get("v.recordId");
        var returnGAM = component.get("c.returnGAMAccount");
        returnGAM.setParams({
            "accId": accId            
        });
        
        returnGAM.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS') {
                var responseValue = response.getReturnValue();
                component.set("v.GAM", responseValue);
            }
        });
        $A.enqueueAction(returnGAM);
    },
    buildGroupsForGAM : function(component) {
        component.set("v.GAMProcessStep", 5);
        var accId = component.get("v.recordId");
        var buildGroupEntities = component.get("c.buildGroups");
        buildGroupEntities.setParams({
            "GAMId": accId            
        });
        
        buildGroupEntities.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS') {
                component.set("v.GAMGroupMap", response.getReturnValue());
                component.set("v.GAMProcessStep", 2);
            }
        });
        $A.enqueueAction(buildGroupEntities);
	},
    deleteGroupsForGAM : function(component) {
        component.set("v.GAMProcessStep", 5);
      	var delAction = component.get('c.deleteGroups');
        var groupIdMap = component.get("v.GAMGroupMap");
        delAction.setParams({
            "groupsToDelete" : groupIdMap
		});
        delAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS') {
                component.set("v.GAMGroupNames", response.getReturnValue());
                component.set("v.GAMProcessStep", 4);
            }
        });
        $A.enqueueAction(delAction);
    },
    overrideDeleteGroups : function(component) {
        var delAction = component.get('c.overrideDeleteGroups');
        delAction.setParams({
            "GAMId" : component.get("v.recordId")
		});
        delAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS') {
                component.set("v.GAMProcessStep", 6);
            }
        });
        $A.enqueueAction(delAction);
    },
    buildHierarchyForGAM : function(component) {
        component.set("v.GAMProcessStep", 5);
        var accId = component.get("v.recordId");
        var buildHierarchyEntities = component.get("c.buildHierarchy");
        var groupIdMap = component.get("v.GAMGroupMap");
        buildHierarchyEntities.setParams({
            "GAMId": accId,
            "GroupMap" : groupIdMap
        });
        
        buildHierarchyEntities.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS') {
                component.set("v.GAMProcessStep", 3);
            }
        });
        $A.enqueueAction(buildHierarchyEntities);
    }
})