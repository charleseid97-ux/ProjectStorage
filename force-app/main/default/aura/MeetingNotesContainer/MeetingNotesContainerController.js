({
    init : function(component, event, helper) {

        helper.initMeetingNote(component);
    },

    createMeetingNote : function(component, event, helper) {
        var newMeetingNote = component.get("v.meetingNote");
        helper.createMeetingNote(component, newMeetingNote);
    },

    cancel : function(component, event, helper) {
        helper.cancel(component);
    },

    back : function(component, event, helper) {
        helper.back(component);
    },

    backToMeetingLinkList : function(component, event, helper) {
        helper.backToMeetingLinkList(component);
    },

    nextStep : function(component, event, helper) {

        var currentStep = component.get("v.meetingNoteStep");
        var nextStep = currentStep + 1;
        var proceed = false;

        if (currentStep == 1){
            helper.checkDetailPaneMandatoryFields(component, event, helper);
        }

        var validationStep = parseInt(component.get("v.validationStep"));

        if (validationStep == -1 ){
            component.set("v.meetingNoteStep", nextStep);
        }
    },

    previousStep : function(component, event) {

        var adder=component.get("v.meetingNoteStep") -1;
        component.set("v.meetingNoteStep", adder);

    },
    handleContactCompanyEvent : function(component, event, helper) {
        var validated =event.getParam("needsContactCompany");
        component.set("v.needsContactCompany",validated);
    },
    handlePathEvent: function(component, event, helper) {

        var data = event.getParams('data').data;
        var results = data.results;

        var path = component.find("path");
        var step = path.get("v.activeChevron");
        var currentStep = component.get("v.meetingNoteStep");
        var meetingNote = component.get("v.meetingNote");

        if (data.type == 'save') {


            if (currentStep == 0){

                helper.checkDetailPaneMandatoryFields(component, event, helper);
            }

            if (step == 2){

                helper.createMeetingLinks(component, event, helper, meetingNote);
                component.set("v.meetingNoteLinks", meetingNote.Meeting_Links__r);
            }

            var validationStep = parseInt(component.get("v.validationStep"));

            if (validationStep != -1 ){

                path.set("v.activeChevron", currentStep);
                path.set("v.error", true);

            }else{
                path.set("v.error", false);
                component.set("v.meetingNoteStep", step);
            }
        }

        if (data.type == 'click') {
        }
    }

})