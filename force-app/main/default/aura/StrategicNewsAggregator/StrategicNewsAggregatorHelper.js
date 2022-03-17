({
    getAllPickListVals : function(component) {
        var action1 = component.get("c.getselectOptions");
        action1.setParams({
            "objObject": component.get("v.objInfo"),
            "fld": "Type__c"
        });
        action1.setCallback(this, function(response) {
            var state = response.getState();
            var err = response.getError();
            if (response.getState() == "SUCCESS") {
                var valueMap = response.getReturnValue();
                component.set("v.TypeMap", valueMap);
            }
        });
        $A.enqueueAction(action1);
    },
    getHierarchyAccounts : function(component) {
        var action = component.get("c.getAccountList");
        action.setParams({
            "UPId" : component.get("v.recordId")
        });
        action.setCallback(this, function(result){
            var accountIds = result.getReturnValue();
            component.set("v.hierarchyAccountIds", accountIds);
            this.getStrategicNews(component);
        });
        $A.enqueueAction(action);
    },
    getStrategicNews : function(component) {
        var action = component.get("c.getStrategicNewsList");
        action.setParams({
            "type" : component.get("v.currentType"),
            "accIds" : component.get("v.hierarchyAccountIds") 
        });
        action.setCallback(this, function(result){
            var SNs = result.getReturnValue();
            component.set("v.strategicNewsList", SNs);
        });
        $A.enqueueAction(action);
    },
    getStrategicNewsIDs : function(component) {
        var action = component.get("c.getStrategicNews");
        action.setParams({
            "selectedSN" : component.get("v.selectedSN")
        });
        action.setCallback(this, function(result){
            var SNIDs = result.getReturnValue();
            component.set("v.getStrategicNewsIDs", SNIDs);
        });
        $A.enqueueAction(action);
    }
})