({
    //controller function to call the visualforce page,
	//pass the query string parameters and
	//download pdf page
    doInit : function(component, event, helper)
    {         
        var recordId = component.get("v.recordId");

        var fileName = component.get('c.accPlanFileName');
        fileName.setParams({
            "accPlanId": recordId
        });
        fileName.setCallback(this, function(response){
            var state = response.getState();
            if (state === "SUCCESS"){
                component.set("v.fileName", response.getReturnValue()+'.pdf');
                helper.downloadPDF(component);
            }else if (state === "INCOMPLETE"){
                // do something
            }else if (state === "ERROR"){
            }
        });
        
        $A.enqueueAction(fileName);  
    }
})