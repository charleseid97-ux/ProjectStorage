({
	getCompany : function(component) {
		var accId = component.get("v.recordId");
        var companyAction = component.get("c.returnCompanyInformation");
        companyAction.setParams({
            accId: accId            
        });

        companyAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS') {
                var result = response.getReturnValue();
				component.set("v.company", result.account);
				component.set("v.relatedContacts", result.relatedContacts);
                
				component.set("v.hasContacts", result.hasContacts);
				component.set("v.hasRelated", result.hasRelated);
            }
        });
        $A.enqueueAction(companyAction);
	},
    deactivateCompany : function(component) {
        component.set("v.ProcessStep", 2);
        var deactivateAction = component.get("c.deactivateCompanyCtrl");
        var company = component.get("v.company");
        var deactivateAllContacts = component.get("v.deactivateAllContacts");
        var relatedContactList = component.get("v.relatedContacts");
        var deactivateAllRelationships = component.get("v.deactivateAllRelationships");

        deactivateAction.setParams({
            company: company,
            linkedContacts : company.Contacts,
            deactivateAllContacts : deactivateAllContacts,
            relatedContacts : relatedContactList,
            deactivateAllRelationships : deactivateAllRelationships
        });
        debugger;
        deactivateAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS') {
                var result = response.getReturnValue();
                var closeAction = $A.get("e.force:closeQuickAction");
                closeAction.fire();
                $A.get('e.force:refreshView').fire();
            }
        });
        $A.enqueueAction(deactivateAction);    
    },
    convertProspect : function(component) {
        component.set("v.ProcessStep", 2);
        var prospectAction = component.get("c.convertProspectCtrl");
        var company = component.get("v.company");

        prospectAction.setParams({
            company: company
        });
        debugger;
        prospectAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS') {
                var result = response.getReturnValue();
                var closeAction = $A.get("e.force:closeQuickAction");
                closeAction.fire();
                $A.get('e.force:refreshView').fire();
            }
        });
        $A.enqueueAction(prospectAction);    
    }
})