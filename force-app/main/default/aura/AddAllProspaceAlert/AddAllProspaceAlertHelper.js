({

    initPickList: function(component,event, helper, contactId) {       
        
        var initializePicklist = component.get("c.initializePicklistAlertType");
        initializePicklist.setParams({
            "aContactId": contactId,
        });
        
        //var elements = document.getElementsByClassName("loading");
        //elements[0].style.display = 'block';
        
        // Configure the response handler for the action
        initializePicklist.setCallback(this, function(response) {
            var state = response.getState();
            console.log("state : "+state);
            if(state === "SUCCESS") {
                
                //var elements = document.getElementsByClassName("loading");
               // elements[0].style.display = 'none';

                var keyValue= [];
                var mapOptions = response.getReturnValue();
                if(mapOptions != null){
                    console.log(mapOptions);
                    for (var key in mapOptions){
                        keyValue.push({value: key, label: mapOptions[key] });
                    }
                    component.set("v.options", keyValue); 
                }
               
            }
            else if (state === "ERROR") {
                console.log('Problem retrieving data, response state: ' + state);
            } else {
                console.log('Unknown problem, response state: ' + state);
            }
        });
        $A.enqueueAction(initializePicklist);
    },

    initPickListPub: function(component,event, helper, contactId) {       
        
        var initializePicklist = component.get("c.initializePicklistAlertTypePub");
        initializePicklist.setParams({
            "aContactId": contactId,
        });

        
        // Configure the response handler for the action
        initializePicklist.setCallback(this, function(response) {
            var state = response.getState();
            if(state === "SUCCESS") {

                var keyValue= [];
                var mapOptions = response.getReturnValue();
                if(mapOptions != null){
                    console.log(mapOptions);
                    for (var key in mapOptions){
                        keyValue.push({value: key, label: mapOptions[key] });
                    }
                    component.set("v.optionsPub", keyValue); 
                }         
            }
            else if (state === "ERROR") {
                console.log('Problem retrieving data, response state: ' + state);
            } else {
                console.log('Unknown problem, response state: ' + state);
            }
        });
        $A.enqueueAction(initializePicklist);
    },


    addAllProspaceAlerts : function (component, event, helper, contactId, selectedAlertTypes) {
        console.log('addAllProspaceAlerts' + selectedAlertTypes);
        var action = component.get("c.addAllProspaceAlerts");
        action.setParams({
            "aContactId": contactId,
            "selectedAlertTypes":selectedAlertTypes
        });
        
        var elementselection = document.getElementsByClassName("selection");
        elementselection[0].style.display = 'none';
        
        var elements = document.getElementsByClassName("loading");
        elements[0].style.display = 'block';
        
        action.setCallback(this, function(response){
            var state = response.getState();
            console.log('response ' + JSON.stringify(response));
            if (state === "SUCCESS") {
                var elements = document.getElementsByClassName("loading");
                elements[0].style.display = 'none';

                var elements = document.getElementsByClassName("loadcomplete");
                elements[0].style.display = 'block';

                //var toggleText = component.find("loadmsg");
                //$A.util.toggleClass(toggleText, "toggle");

                window.setTimeout(
                    $A.getCallback(function() {
                        sforce.one.navigateToSObject(contactId);
                    }), 5500
                );

            //location.reload(sforce.one.navigateToSObject(contactId));
            //var elements = document.getElementsByClassName("test");
            //elements[0].style.display = 'none';
            //sforce.one.navigateToSObject(contactId);
            }else if(state === "ERROR"){
                
                var elements = document.getElementsByClassName("loading");
                elements[0].style.display = 'none';

                var elements = document.getElementsByClassName("loadcomplete");
                elements[0].style.display = 'none';
                
                var elements = document.getElementsByClassName("errorMessage");
                elements[0].style.display = 'block';
                
                window.setTimeout(
                    $A.getCallback(function() {
                        sforce.one.navigateToSObject(contactId);
                    }), 5500
                );

            }
    });
    $A.enqueueAction(action);

    }
})