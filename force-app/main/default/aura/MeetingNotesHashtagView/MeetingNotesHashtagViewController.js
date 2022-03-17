({
    init : function(c, e, h) {
        var action = c.get("c.getNotes");
        action.setParams({
            notesId : c.get("v.recordId")
        });
        
        action.setCallback(this, function(result) {
            if (result.getState() === "SUCCESS") {
        		c.set('v.htmlData', h.buildHtml(c, result.getReturnValue()));
            } else if (result.getState() === "ERROR") {
                console.log("Error happened!");
            }
        });
        $A.enqueueAction(action);
    }
})