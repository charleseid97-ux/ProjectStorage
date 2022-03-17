({
	returnMetrics : function(component, event, helper) {
        var companyId = component.get("v.recordId");
        var metricsAction = component.get("c.getCompanyEngagementMetrics");
        metricsAction.setParams({
            "companyId": companyId
        });

        metricsAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS') {
               
                var metricResult = response.getReturnValue();
                debugger;
                component.set('v.metricResult', metricResult);
                
            }
        });
        $A.enqueueAction(metricsAction);
    }
})