({
    init : function (c) {
        var action = c.get("c.getAllTags");
        action.setCallback(this, function(result) {
            if (result.getState() === "SUCCESS") {
                c.set('v.allTags', result.getReturnValue());
                c.set('v.filteredTags', result.getReturnValue());
            } else if (result.getState() === "ERROR") {
                console.log("Error happened!");
            }
        });
        $A.enqueueAction(action);
        c.set('v.previousData', c.get('v.fieldData'));
    },
    
    keyCheck : function (c, e, h) {
        if (e.which === 35)
            h.startTag(c);
        else if (c.get('v.writingTag'))
            h.writeTag(c, e);
    },
    
    keyCheckDown : function (c, e, h) {
        c.set('v.previousData', c.get('v.fieldData'));
        if (e.which === 8) {
            if (c.get('v.currentTag') === '') h.endTag(c);
            else {
                c.set('v.currentTag', c.get('v.currentTag').slice(0, -1));
                h.filterTagList(c);
            }
        }
        if (e.which === 27 || e.which === 13 || e.which === 9) h.endTag(c);
    },
    
    completeTag : function (c, e, h) {
        let target = e.target || e.srcElement;
        h.completeData(c, e.target.innerText);
    }
})