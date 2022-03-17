({
	downloadPDF : function(component, accName) {
        var recordId = component.get("v.recordId");
		var action = component.get('c.downloadStrategicNews');
        
        action.setParams({
            "url": "/apex/StrategicNewsPDF?id="+recordId+"&accountName="+accName
        });
        
        action.setCallback(this, function(response){
            var state = response.getState();
            var recordId = component.get("v.recordId");
            if (state === "SUCCESS")
            {
                var pdfStrRes = response.getReturnValue();
                var el = component.find("theDlTag").getElement();
                el.href = "data:application/pdf;base64,"+pdfStrRes;
                el.click();
                
                //close quick action modal
                $A.get("e.force:closeQuickAction").fire();
                var closeComp = component.getEvent("closeDownloadOverlay");
        		closeComp.fire();
                
            }else if (state === "INCOMPLETE")
            {
                // do something
            }else if (state === "ERROR")
            {
                var errors = response.getError();
                if (errors)
                {
                    if (errors[0] && errors[0].message)
                    {
                        console.log("Error message: " + errors[0].message);
                    }
                }else
                {
                    console.log("Unknown error");
                }
            }
        });
        
        $A.enqueueAction(action);  
    }
})