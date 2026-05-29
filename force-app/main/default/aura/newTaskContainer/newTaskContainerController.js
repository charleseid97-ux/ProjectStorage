({
  doInit: function(cmp) {
    console.log('[newTaskContainer] recordId =', cmp.get('v.recordId'));
  },
  handleDone: function(cmp, evt, helper) {
        console.log('[newTaskContainer] done received -> closing + refreshing');

        // ✅ ferme la quick action
        $A.get("e.force:closeQuickAction").fire();

        // ✅ refresh de la page (après fermeture)
        window.setTimeout(function() {
            $A.get("e.force:refreshView").fire();
        }, 200);
    }
})