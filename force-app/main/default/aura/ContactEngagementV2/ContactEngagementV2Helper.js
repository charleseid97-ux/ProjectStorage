({
	returnMetrics : function(component, event, helper) {
        var contactId = component.get("v.recordId");
        var metricsAction = component.get("c.getContactDigitalInteractionMetrics");
        var currentTheme = component.get("v.currentTheme");
        metricsAction.setParams({
            "contactId": contactId,
            "currentTheme": currentTheme
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
    },
    getDrillDown : function(component, clickedSection) {
        var contactId = component.get("v.recordId");
        var currentTheme = component.get("v.currentTheme");
        var actionDI = component.get("c.getDrillDownData");
        
        actionDI.setParams({
            "contactId": contactId,
            "clickedSection": clickedSection,
            "currentTheme": currentTheme
        });
        
        actionDI.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                component.set('v.digitalInteractions', actionResult.getReturnValue());
            }
        });
        $A.enqueueAction(actionDI);

    }
})