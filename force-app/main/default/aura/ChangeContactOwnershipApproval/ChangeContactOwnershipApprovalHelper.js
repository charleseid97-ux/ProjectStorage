({
    buildData : function(component) {
        debugger;
        var contactId = component.get("v.recordId");
        var buildAction = component.get("c.buildApprovalData");
        buildAction.setParams({
            "contactId": contactId
        });
        buildAction.setCallback(this, function(response){
        debugger;
            var status = response.getState();
            if (status === 'SUCCESS'){
                debugger;
                var responseValue = response.getReturnValue();
                component.set("v.contact", responseValue.contact);
				component.set("v.currentOwner", responseValue.currentUser);
                component.set("v.currentOwnerRegions", responseValue.currentUser.BusinessDevelopmentRegions__c);
                component.set("v.proposedHOCs", responseValue.proposedHOCs);
                component.set("v.currentHOCs", responseValue.currentHOCs);
                component.set("v.CurrHOCIdsForAccess", responseValue.currHocAccess);
                component.set("v.PropHOCIdsForAccess", responseValue.propHOCAccess);
                this.checkHasAccess(component, true);
            }
        });
        $A.enqueueAction(buildAction);
    },
    approveCurrent : function(component){
        debugger;
        var approveCurrentAction = component.get("c.approveCurrent");
        var cId = component.get("v.recordId");
        approveCurrentAction.setParams({
            "contactId": cId
        });
       
        approveCurrentAction.setCallback(this, function(response){
        debugger;
            var status = response.getState();
            var error = response.getError();
        debugger;
            if (status === 'SUCCESS'){
                var responseValue = response.getReturnValue();
                component.set("v.contact", responseValue);
                this.buildData(component);
                $A.get('e.force:refreshView').fire();
            }
        });
        $A.enqueueAction(approveCurrentAction);
    },
    approveProposed : function(component){
        var approveProposedAction = component.get("c.approveProposed");
        approveProposedAction.setParams({
            "contactId": component.get("v.recordId")
        });
       
        approveProposedAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS'){
                var responseValue = response.getReturnValue();
                component.set("v.contact", responseValue);
                this.buildData(component);
                $A.get('e.force:refreshView').fire();
            }
        });
        $A.enqueueAction(approveProposedAction);
    },
    rejectChange : function(component){
        var rejectAction = component.get("c.rejectOwnershipChange");
        rejectAction.setParams({
            "contact": component.get("v.contact")
        });
       
        rejectAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS'){
                var responseValue = response.getReturnValue();
                $A.get('e.force:refreshView').fire();
            }
        });
        $A.enqueueAction(rejectAction);
    },
    checkHasAccess : function(component, curr) {
        debugger;
        var getCurrList = component.get('v.CurrHOCIdsForAccess');
        var getPropList = component.get('v.PropHOCIdsForAccess');
        var getElement = component.get('v.currentUserId');
        var getCurrElementIndex = getCurrList.indexOf(getElement);
        var getPropElementIndex = getPropList.indexOf(getElement);
       
        if(getCurrElementIndex != -1){ 
          component.set('v.currentUserCurrAccess',true);
        }else{
          component.set('v.currentUserCurrAccess',false);
        }
        if(getPropElementIndex != -1){ 
          component.set('v.currentUserPropAccess',true);
        }else{
          component.set('v.currentUserPropAccess',false);
        }
        if(component.get('v.currentUserCurrAccess') == true || component.get('v.currentUserPropAccess') == true) {
            component.set('v.currentUserView',false);
            component.set('v.currentUserAccess',true);
        } else {
            component.set('v.currentUserView',true);
            component.set('v.currentUserAccess',false);
        }
    }
})