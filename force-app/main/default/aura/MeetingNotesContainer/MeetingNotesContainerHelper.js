({
    initMeetingNote : function(component) {

        var action = component.get('c.getMeetingNote');
        var toastErrorHandler = component.find('toastErrorHandler');

        action.setParams({ recordId : component.get("v.recordId"),
                             fromId : component.get("v.fromId")});

        action.setCallback(this, function(response){

            toastErrorHandler.handleResponse(
            response, 
            function(response){

                var meetingNoteStructure = response.getReturnValue();
                component.set('v.meetingNotePrefix', meetingNoteStructure.MeetingNotePrefix);
                component.set('v.meetingNote', meetingNoteStructure.MeetingNote);
                component.set('v.meetingNoteLinks', meetingNoteStructure.MeetingLinks);
                component.set('v.meetingNoteStep', 0);

            })
        });
        $A.enqueueAction(action);
    },

    createMeetingNote: function(component, event, helper) {

        component.set('v.meetingNoteStep', -2);
        var meetingNote = component.get("v.meetingNote");
        var detailPane = component.find('detailPane');
        var ownerLookup = detailPane.find('ownerLookup');
        var meetingNoteDate = detailPane.find('Date');
        var meetingType = detailPane.find('MeetingType');
        var purpose = detailPane.find('Purpose');
        var IS = detailPane.find('IS');
        var brand = detailPane.find('Brand');
        var macro = detailPane.find('Macro');
        var toastErrorHandler = component.find('toastErrorHandler');

        meetingNote.OwnerId = ownerLookup.get('v.value');
        meetingNote.Meeting_Type__c = meetingType.get('v.value');
        meetingNote.Purpose__c = purpose.get('v.value');
        meetingNote.Investment_Solution__c = IS.get('v.value');
        meetingNote.Brand__c = brand.get('v.value');
        meetingNote.Macro__c = macro.get('v.value');

        this.createMeetingLinks(component, event, helper, meetingNote)

        var action = component.get("c.saveMeetingNote");

        action.setParams({
            "meetingNote": meetingNote,
            "meetingLinks": meetingNote.Meeting_Links__r,
            "fromId" : component.get("v.fromId")
        });

        action.setCallback(this, function(response){
            toastErrorHandler.handleResponse(
            response, 
            function(response){
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success",
                    "message": "Meeting Note Saved",
                    "type": "success"
                });

                var meetingNoteStructure = response.getReturnValue();
                component.set('v.newRecordId', meetingNoteStructure.MeetingNote.Id);

                var a = component.get('c.back');
                $A.enqueueAction(a);
                toastEvent.fire();
                
                //Close Quick Action dialogue
                $A.get("e.force:closeQuickAction").fire();
            })
            if (response.getState() === "ERROR") {
                var message = '';
                var errors = response.getError();
                if (errors) {
                    for(var i=0; i < errors.length; i++) {
                        for(var j=0; errors[i].pageErrors && j < errors[i].pageErrors.length; j++) {
                            message += (message.length > 0 ? '\n' : '') + errors[i].pageErrors[j].message;
                        }
                        if(errors[i].fieldErrors) {
                            for(var fieldError in errors[i].fieldErrors) {
                                var thisFieldError = errors[i].fieldErrors[fieldError];
                                for(var j=0; j < thisFieldError.length; j++) {
                                    message += (message.length > 0 ? '\n' : '') + thisFieldError[j].message;
                                }
                            }
                        }
                        if(errors[i].message) {
                            message += (message.length > 0 ? '\n' : '') + errors[i].message;
                        }
                    }
                } else {
                    message += (message.length > 0 ? '\n' : '') + 'Unknown error';
                }
                component.set('v.meetingNoteStep', -3);
                component.set("v.message", message);
            }
        });
        $A.enqueueAction(action);
    },

    createMeetingLinks: function(component, event, helper, meetingNote) {

        var relatedList = component.find('relatedList');
        var accountLookup = relatedList.find('accountLookup');
        var contactLookup = relatedList.find('contactLookup');
        var internalContactLookup = relatedList.find('internalContactLookup');
        var productLookup = relatedList.find('productLookup');
        var opportunityLookup = relatedList.find('opportunityLookup');
        var campaignLookup = relatedList.find('campaignLookup');
		var caseLookup = relatedList.find('caseLookup');

        meetingNote.Meeting_Links__r = [];

        this.getSelectedMeetingLinks(accountLookup, 'Account__c', meetingNote);
        this.getSelectedMeetingLinks(contactLookup, 'Contact__c', meetingNote);
        this.getSelectedMeetingLinks(internalContactLookup, 'Employee__c', meetingNote);
        this.getSelectedMeetingLinks(productLookup, 'Product__c', meetingNote, true);
        this.getSelectedMeetingLinks(opportunityLookup, 'Opportunity__c', meetingNote);
        this.getSelectedMeetingLinks(campaignLookup, 'Campaign__c', meetingNote);
		this.getSelectedMeetingLinks(caseLookup, 'Case__c', meetingNote);
    },

    getSelectedMeetingLinks : function(lookup, lookupField, meetingNote, modifier) {

        var meetingLinks = meetingNote.Meeting_Links__r;
        var recordId = meetingNote.Id;
        var values = lookup.get('v.value');

        var modifierField;
        var modifierValue;
        var modifierArray;
        var sentimentField;
        var sentimentValue;
        var sentimentArray;

        if (modifier != null) {
            console.log('Modifier is not null');
            modifierField = lookup.get('v.modifier').split('.')[1];
            modifierValue = lookup.get('v.modifierValue');
            modifierArray = modifierValue.split(';');
        } else {
            console.log('Modifier is null');
        }
        
        if(lookup.get('v.sentimentValue') != null) {
            sentimentField = 'Product_Sentiment__c';
            sentimentValue = lookup.get('v.sentimentValue');
            sentimentArray = sentimentValue.split(';');
        }

        if (values != null)
        {
            if (values.length > 0){

                var valueArray = values.split(";");

                for(var i = 0; i < valueArray.length; i++){

                    if (modifier != null) {
                        meetingLinks.push({
                            sobjectType: 'Meeting_Link__c',
                            Meeting_Note__c: recordId,
                            [lookupField]: valueArray[i],
                            [modifierField]: modifierArray[i],
                            [sentimentField]: sentimentArray[i]
                        });
                    } else {
                        meetingLinks.push({
                            sobjectType:'Meeting_Link__c',
                                           Meeting_Note__c:recordId,
                                           [lookupField]:valueArray[i]
                        });
                    }

                }
            }
        }
    },

    cancel : function(component, event, helper) {
 
        this.back(component, event, helper);
    },
    
    back : function(component, event, helper) {
        
        var recordId = component.get("v.recordId");
        var fromId = component.get("v.fromId");
        var newRecordId = component.get("v.newRecordId");
        
        if(fromId != null) {
            
            this.navigateToObject(component, event, helper, fromId);
        }
        else if(recordId != null) {
            
            this.navigateToObject(component, event, helper, recordId);
        }
        else if(newRecordId != null) {
            
            this.navigateToObject(component, event, helper, newRecordId);
        }
        else
        {
        
            var urlEvent = $A.get("e.force:navigateToURL");
            var prefix = component.get("v.meetingNotePrefix");
            
            console.log('MEETING NOTE PREFIX:' + component.get('v.meetingNotePrefix'));

            urlEvent.setParams({
                "url": `/${prefix}/o`
            });
            urlEvent.fire();
        }
    },
    
    navigateToObject : function (component, event, helper, recordId) {
        
        var navEvt = $A.get("e.force:navigateToSObject");
        
        navEvt.setParams({
          "recordId": recordId,
          "slideDevName": "detail"
        });

        navEvt.fire();
        
        /* In order to get around below issue where e.force:navigateToSObject
        * does not get you the latest set of updated data, we are setting a timeout
		* of 1 second to make sure that the view is refreshed to display the new information
        * Defect: https://success.salesforce.com/issues_view?id=a1p3A000000mCpKQAU
        */
		var delay = 1000;
        setTimeout($A.getCallback(function() {
           	$A.get('e.force:refreshView').fire();
        }), delay);
        
    },
    
    checkDetailPaneMandatoryFields : function (component, event, helper){
        
        var currentStep = component.get("v.meetingNoteStep");
        var detailPane = component.find('detailPane');
        var title = detailPane.find("title");
        var date = detailPane.find("Date");
        //var nextStep = detailPane.find("NextSteps");
        var meetingType = detailPane.find("MeetingType");
        var meetingPurpose = detailPane.find("Purpose");
        var dateError = detailPane.find("dateError");
        var nextStepError = detailPane.find("nextStepError");
        var meetingTypeError = detailPane.find("meetingTypeError");
        var meetingPurposeError = detailPane.find("meetingPurposeError");
        var valid = false;
        var mt = meetingType.get("v.value");
        var mp = meetingPurpose.get("v.value");
        debugger;
        title.showHelpMessageIfInvalid();
        if(meetingType.get("v.value") != '' && meetingPurpose.get("v.value") != ''){
            valid = true;
            this.hideElement(component, event, helper, meetingTypeError);
            this.hideElement(component, event, helper, meetingPurposeError);
        }else{
            if(meetingType.get("v.value") == ''){
               	var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                        "title": "Error!",
                        "message": "Please specify a Meeting Type",
                        "type" : "error"
                });
            	toastEvent.fire();
                this.showElement(component, event, helper, meetingTypeError);
            }else{
                this.hideElement(component, event, helper, meetingTypeError);
            }
            if(meetingPurpose.get("v.value") == ''){
               	var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                        "title": "Error!",
                        "message": "Please specify a Meeting Purrpose",
                        "type" : "error"
                });
            	toastEvent.fire();
                this.showElement(component, event, helper, meetingPurposeError);
            }else{
                this.hideElement(component, event, helper, meetingPurposeError);
            }
        }
        if(title.get("v.validity").valid && valid) 
        {
            component.set("v.validationStep",-1);
        }else{
            component.set("v.validationStep",currentStep);
        }
        
    },
    
    hideElement : function(component, event, helper, elementObj){
        $A.util.addClass(elementObj, 'slds-hide');
        $A.util.removeClass(elementObj, 'slds-show');
    },
    
    showElement : function(component, event, helper, elementObj){
        $A.util.removeClass(elementObj, 'slds-hide');
        $A.util.addClass(elementObj, 'slds-show');
    },
})