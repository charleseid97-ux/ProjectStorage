({
	handleSendClick : function(component, event, helper) {
        
        var sendButton = component.find('sendButton');
        sendButton.set("v.disabled", true);
        sendButton.set("v.label", 'Sending...')
        
		var emailAddress = component.find('emailAddress').get('v.value');
        
        var users = component.find('Users').get('v.value');
        if(users != null){
            users = users.split(';');
        }
        console.log('Users value:' + users);
        var meetingNoteId = component.get('v.recordId');

		var action = component.get("c.emailPDF");
        action.setParams({
             'meetingNoteId': meetingNoteId,
             'userIds': users,
          });
          //set callback   
         action.setCallback(this, function(response) {
             if (response.getState() == "SUCCESS") {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The PDF has been sent!",
                    "type": "success"
                });
                toastEvent.fire();
                
                component.find('sendButton').set("v.disabled", false);
                component.find('sendButton').set("v.label", "Send");
                component.find('Users').set("v.value", "")
             }
             if(response.getState() == "ERROR"){
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Error!",
                    "message": "Something has gone wrong and the PDF has not been sent.",
                    "type": "error"
                });
                toastEvent.fire();
               	component.find('sendButton').set("v.disabled", false);
                component.find('sendButton').set("v.label", "Send");
             }
          });
          $A.enqueueAction(action);
        }
    })