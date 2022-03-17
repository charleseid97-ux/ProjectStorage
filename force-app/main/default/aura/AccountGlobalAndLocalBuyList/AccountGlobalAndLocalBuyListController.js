({
    //Init component
    init : function(component, event, helper) {
        var dtForm = component.get("v.dataFormatter");
        // load data from server
        helper.loadData(component);
    },
    newRecord : function(component, event, helper) {
        if( component.get("v.customCreationManagement")) {
            helper.loadCustomCreationManager(component, "CREATE");
            return;
        }
        var createAcountContactEvent = $A.get("e.force:createRecord");
        var defaultFieldValues = {};
        defaultFieldValues[component.get('v.parentId')] = component.get('v.recordId');
        var windowHash = window.location.hash;
        createAcountContactEvent.setParams({
            entityApiName: component.get('v.objectName'),
            defaultFieldValues: defaultFieldValues,
            inContextOfRecordId : component.get('v.recordId'),
            navigationLocation : 'RELATED_LIST_ROW',
            navigationLocationId :  component.get('v.objectName')
        });
        
        createAcountContactEvent.fire();
    },
    customView : function(component, event, helper) {
        var recordIdFromList = event.getSource().get("v.value");
        helper.loadCustomView(component, "CREATE", recordIdFromList);
    },
    customEdit : function(component, event, helper) {
        var recordIdFromList = event.getSource().get("v.value");
        helper.loadCustomEdit(component, "EDIT", recordIdFromList);
    },
    customDel : function(component, event, helper) {
        var recordIdFromList = event.getSource().get("v.value");
        if(confirm("Are you sure you want to delete this record?")) {
	        helper.DeleteIndependent(component, recordIdFromList);
        }
    },
    //Update sorting
    updateColumnSorting: function (cmp, event, helper) { 
        //get sorting field name
        var fieldName = event.getParam('fieldName');
        //get direction sort 
        var sortDirection = event.getParam('sortDirection');
        //set sort parameter in component
        cmp.set("v.sortedBy", fieldName);
        cmp.set("v.sortedDirection", sortDirection);
        //sort data
        helper.sortData(cmp, fieldName, sortDirection, 'dataResult');
        helper.sortData(cmp, fieldName, sortDirection, 'dataDisplay');
    },
    //filtring data
    filterData: function (cmp, event, helper) {
        //filtering data
        helper.filterData(cmp);
    },
    showPreview: function (cmp, event, helper) {
        cmp.set("v.preview", true);
    },
    showTable: function (cmp, event, helper) {
        cmp.set("v.preview", false);
    },
    //select action on data table
    handleRowAction: function (cmp, event, helper) {
        var action = event.getParam('action');
        var row = event.getParam('row');
        helper.eventManager(cmp, action.name, row.Id);
        
    }
})