(function() {
    let hasUnsavedChanges = false;

    function handleBeforeUnload(event) {
        if (hasUnsavedChanges) {
            event.preventDefault();
            event.returnValue = ''; // Required for modern browsers
        }
    }

    function setUnsavedChanges(status) {
        hasUnsavedChanges = status;
    }

    window.addEventListener('beforeunload', handleBeforeUnload);

    // Store the handlers for LWC
    window.preventNavigationHandlers = {
        setUnsavedChanges: setUnsavedChanges,
        beforeUnload: handleBeforeUnload
    };
})();