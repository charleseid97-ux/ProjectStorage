({
	getCurrentGAMHomepage : function(component) {
        var GAMHPAction = component.get("c.returnGAMHP");
        GAMHPAction.setParams({"HPId":component.get("v.recordId")});
        GAMHPAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS'){
                var responseValue = response.getReturnValue();
                component.set("v.GAMHomepage", responseValue);
            }
        });
        $A.enqueueAction(GAMHPAction);
	},
    getCurrentGAMAccount : function(component) {
        var GAMAccountAction = component.get("c.returnGAMAccount");
        GAMAccountAction.setParams({"HPId":component.get("v.recordId")});
        GAMAccountAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS'){
                var responseValue = response.getReturnValue();
                component.set("v.GAMAccount", responseValue);
                component.set("v.GAMAUM", numeral(component.get("v.GAMAccount").AUMToDate__c).format('0.0a'))
                this.getLatestStrategicNews(component, responseValue.Id);
            }
        });
        $A.enqueueAction(GAMAccountAction);
	},
    getLatestStrategicNews : function(component, GAMId) {
        var GAMSNAction = component.get("c.returnGAMStrategicNews");
        GAMSNAction.setParams({"accId":GAMId});
        GAMSNAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS'){
                debugger;
                var responseValue = response.getReturnValue();
                component.set("v.GAMNewsItem", responseValue);
                component.set("v.GAMNewsItemDate", $A.localizationService.formatDate(responseValue.LastModifiedDate));
            }
        });
        $A.enqueueAction(GAMSNAction);
	}

})