({
	returnMetrics : function(component, event, helper) {
        var contactId = component.get("v.recordId");
        var metricsAction = component.get("c.getContactEngagementMetrics");
        metricsAction.setParams({
            "contactId": contactId            
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