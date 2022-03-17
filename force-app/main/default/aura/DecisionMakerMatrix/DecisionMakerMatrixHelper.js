({
    getAllPickListVals : function(component) {
        var action1 = component.get("c.returnSelectOptionsMap");
        action1.setParams({
            "objObject": component.get("v.objInfo"),
            "fld": "Level_of_Influence__c"
        });
        action1.setCallback(this, function(response) {
            var state = response.getState();
            var err = response.getError();
            if (response.getState() == "SUCCESS") {
                var valueMap = response.getReturnValue();
                component.set("v.influenceLevelMap", valueMap);
            }
        });
        $A.enqueueAction(action1);
        
        var action2 = component.get("c.returnSelectOptionsMap");
        action2.setParams({
            "objObject": component.get("v.objInfo"),
            "fld": "Level_of_Support__c"
        });
        action2.setCallback(this, function(response) {
            if (response.getState() == "SUCCESS") {
                var valueMap = response.getReturnValue();
                component.set("v.recommendLevelMap", valueMap);
                this.getContactsForCompany(component);
            }
        });
        $A.enqueueAction(action2);
    },
    getContactsForCompany : function(component) {
        var action = component.get("c.returnContacts");
        action.setParams({
            "accId": component.get("v.recordId")
        });
        action.setCallback(this, function(response) {
            if (response.getState() == "SUCCESS") {
                component.set("v.contactList", response.getReturnValue());
                this.getContactTableMap(component);
            }
        });
        $A.enqueueAction(action);
    },
    getContactsForHierarchy : function(component) {
        var action = component.get("c.returnAllContacts");
        action.setParams({
            "accHierarchyList": component.get("v.hierarchyAccounts")
        });
        action.setCallback(this, function(response) {
            if (response.getState() == "SUCCESS") {
                component.set("v.contactList", response.getReturnValue());
                this.getContactTableMap(component);
            }
        });
        $A.enqueueAction(action);
    },
    getContactTableMap : function(component) {
        var action3 = component.get("c.returnContactTableMap");
        action3.setParams({
            "influenceMap": component.get("v.influenceLevelMap"),
            "recommendMap": component.get("v.recommendLevelMap"),
            "contacts": component.get("v.contactList")
        });
        action3.setCallback(this, function(response) {
            if (response.getState() == "SUCCESS") {
                var valueMap = response.getReturnValue();
                component.set("v.contactTableMap", valueMap);
                this.buildTable(component);
            }
        });
        $A.enqueueAction(action3);
    },
    getHierarchyAccounts : function(component) {
        var action = component.get("c.getAccountList");
        action.setParams({
            "UPId" : component.get("v.recordId")
        });
        action.setCallback(this, function(result){
            var accounts = result.getReturnValue();
            component.set("v.hierarchyAccounts", accounts);
        });
        $A.enqueueAction(action);
    },
    buildTable : function(component) {
        var matrixTable = '<table class="slds-scrollable forceRecordLayout slds-table slds-no-row-hover slds-table_fixed-layout uiVirtualDataGrid--default uiVirtualDataGrid list slds-cell-wrap" data-aura-class="uiVirtualDataGrid--default uiVirtualDataGrid"><thead><tr class="matrixRow">';
		var influenceLevelMap = component.get("v.influenceLevelMap");
		var recommendLevelMap = component.get("v.recommendLevelMap");
		var contactTableMap = component.get("v.contactTableMap");
        
        //test older browsers with this!!!
        var influenceSize = Object.keys(influenceLevelMap).length+2;
        var recommendSize = Object.keys(recommendLevelMap).length+2;
        
        for(var r = 1; r < recommendSize; r++){
            for(var i = 1; i < influenceSize; i++){
                matrixTable+='<td class="slds-cell-wrap matrixCell matrixColour'+r+''+i+'">';
                var thisValue = contactTableMap['ct'+r+i];
                if(thisValue!=null)
	                matrixTable+=thisValue+'</br>';
                matrixTable+='</td>';
            }
            matrixTable+='</tr><tr>';
        }
		matrixTable+='</tr></thead></table>';
        component.set("v.matrixTable", matrixTable);
    }
})