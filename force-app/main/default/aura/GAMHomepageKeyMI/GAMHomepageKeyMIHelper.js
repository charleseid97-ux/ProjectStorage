({
	loadLinkedAccount : function(component) {
        var recId = component.get("v.recordId");
        var action = component.get("c.returnGAMAccount");
        
        action.setParams({"HPId" : recId});
        action.setCallback(this, function(actionResult) {
            var status = actionResult.getState();
            if (status === 'SUCCESS') {
                var resp = actionResult.getReturnValue();
                component.set('v.GAMAccount', resp);
                component.set('v.GAMId', resp.Id);
            }
        });
        $A.enqueueAction(action);
    },
    loadOpportunitiesComponent : function(component) {
        $A.createComponent(
            "c:GAMHomepageOpportunitiesModal",
            {
                GAMId: component.get('v.GAMId'),
                GAMAccount: component.get('v.GAMAccount'),
                viewOpportunitiesComponent: true
            },
            function(opportunitiesComponent, status, errorMessage){
                if (status === "SUCCESS") {
                    
                    component.set("v.opportunitiesComponent", opportunitiesComponent);
                    component.set('v.preview', true);
                }
                else if (status === "INCOMPLETE") {
                    console.log("No response from server or client is offline.")
                    // Show offline error
                }
                    else if (status === "ERROR") {
                        console.log("Error: " + errorMessage);
                        // Show error message
                    }
            }
        );
    },
    loadStrategicNewsComponent : function(component) {
        $A.createComponent(
            "c:StrategicNewsAggregatorModal",
            {
                GAMId: component.get('v.GAMId'),
                GAMAccount: component.get('v.GAMAccount'),
                viewSNComponent: true
            },
            function(opportunitiesComponent, status, errorMessage){
                if (status === "SUCCESS") {
                    
                    component.set("v.strategicNewsComponent", opportunitiesComponent);
                    component.set('v.preview', true);
                }
                else if (status === "INCOMPLETE") {
                    console.log("No response from server or client is offline.")
                    // Show offline error
                }
                    else if (status === "ERROR") {
                        console.log("Error: " + errorMessage);
                        // Show error message
                    }
            }
        );
    },
    loadReport : function(component) {
        this.navigateToRecord(component, '01Z1j0000000EcuEAE');
    },
    loadActivityComponent : function(component) {
        var urlEvent = $A.get("e.force:navigateToURL");
        urlEvent.setParams({
            "url": "https://efl-prd.carmignac.com/#/views/Salesforce-Activites_15717257033500/Salesforce-Activities?UltimateParentName="+component.get("v.GAMAccount.Name")
        });
        urlEvent.fire();
    },
    loadAUMComponent : function(component) {
        var urlEvent = $A.get("e.force:navigateToURL");
        urlEvent.setParams({
            //"url": "https://efl-prd.carmignac.com/#/views/Salesforce-HomePage/OPPORTUNITYDASHBOARD?Lev5_Code="+component.get("v.GAMAccount.TECH_CompanyTechSUNID__c")
            "url": "https://efl-prd.carmignac.com/#/views/GAM-AUMANDNETFLOWS-NEWRELEASE/GAMDashboard?:iid="+component.get("v.GAMAccount.TECH_CompanyTechSUNID__c")
        });
        urlEvent.fire();
    },
    loadOpportunityDashComponent : function(component) {
        var urlEvent = $A.get("e.force:navigateToURL");
        urlEvent.setParams({
            "url": "https://efl-prd.carmignac.com/#/views/Salesforce-HomePage/OPPORTUNITYDASHBOARD?Distributor%20Name="+component.get("v.GAMAccount.Name")
        });
        urlEvent.fire();
    },
    navigateToRecord : function(component, recId) {
        var navEvent = $A.get("e.force:navigateToSObject");
        if(navEvent){
            navEvent.setParams({
                recordId: recId
            });
            navEvent.fire();   
        }
        else{
            //window.location.href = '/one/one.app#/sObject/'+component.get("v.contacts").Id+'/view'
        }
	}
})