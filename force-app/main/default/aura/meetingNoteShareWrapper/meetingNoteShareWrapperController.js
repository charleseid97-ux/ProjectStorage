({
  handleDone: function(cmp, evt, helper) {
    console.log('[meetingNoteShareWrapper] done received -> closing + refreshing');

    // ferme la quick action
    $A.get("e.force:closeQuickAction").fire();

    // refresh après fermeture
    window.setTimeout(function() {
      $A.get("e.force:refreshView").fire();
    }, 200);
  }
})