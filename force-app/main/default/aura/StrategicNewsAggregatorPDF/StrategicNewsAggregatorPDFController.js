({
    doDownloadPDF : function (component, event, helper) {
        var params = event.getParam('arguments');
        var snIds = params.lSN;
        var aId = params.rId;
        var fileName = component.get('c.ACCFileName');
        fileName.setParams({
            "accId": aId
        });
        fileName.setCallback(this, function(response){
            var state = response.getState();
            if (state === "SUCCESS"){
                component.set("v.fileName", response.getReturnValue()+'.pdf');
                helper.downloadPDF(component, snIds, response.getReturnValue());
            }else if (state === "INCOMPLETE"){
                // do something
            }else if (state === "ERROR"){
            }
        });
        
        $A.enqueueAction(fileName);
    }
})