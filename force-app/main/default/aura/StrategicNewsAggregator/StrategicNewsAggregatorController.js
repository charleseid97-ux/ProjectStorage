({
    init : function(component, event, helper) {
        helper.getAllPickListVals(component);
        helper.getHierarchyAccounts(component);
    },
    changeSNType : function(component, event, helper) {
        component.set("v.currentType", event.getSource().get("v.value"));
        helper.getStrategicNews(component);
    },
    expandNews : function(component, event, helper) {
        var recordIdFromList = event.getSource().get("v.value");
        var expandDiv = document.getElementById("SN"+recordIdFromList);
        $A.util.toggleClass(expandDiv, "slds-transition-hide");
        $A.util.toggleClass(expandDiv, "slds-transition-show");
        
        var label = event.getSource().get("v.label");
        if(label == 'expand') {
            event.getSource().set("v.label","collapse")
        } else {
            event.getSource().set("v.label","expand")
        }
    },
    callCheckboxMethod : function(component, event, helper) {
        var capturedCheckboxName = event.getSource().get("v.value");
        var selectedSN =  component.get("v.selectedSN");
        if(selectedSN.indexOf(capturedCheckboxName) > -1){
            selectedSN.splice(selectedSN.indexOf(capturedCheckboxName), 1);
        }
        else{
            selectedSN.push(capturedCheckboxName);
        }
        component.set("v.selectedSN", selectedSN);
        helper.getStrategicNewsIDs(component);
    },
    onGeneratePDF : function(component, event, helper) {
        var lSN =  component.get("v.selectedSN");
        var rId = component.get("v.recordId");
        var SNAComponent = component.find('SNADownloadPDF');
        SNAComponent.downloadPDF(lSN, rId);
    }
})