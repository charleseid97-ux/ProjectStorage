({
    load : function(component) {

        var meetingNote = component.get("v.meetingNote");

        component.find('meetingNoteProgressMeter').set('v.completed', this.calcProgressPercentage(component, meetingNote));

    },
    calcProgressPercentage : function(component, meetingNoteVar) {

        var meetingLinks = component.get("v.meetingNoteLinks");
        var externalContactLinked = false;
        var organisationLinked = false;
        var opportunityLinked = false;
        var productLinked = false;
        var notesEntered = false;
        var campaignLinked = false;

        if(meetingNoteVar.Note__c){
            notesEntered = true;
        }

        for (var index in meetingLinks){

            if(meetingLinks[index].Account__c){
                organisationLinked = true;
            }

            if (meetingLinks[index].Contact__c){
                externalContactLinked = true;
            }

            if (meetingLinks[index].Product__c){
                productLinked = true;
            }

            if (meetingLinks[index].Opportunity__c){
                opportunityLinked = true;
            }
            
            if(meetingLinks[index].Campaign__c){
                campaignLinked = true;
            }
        }

        component.set("v.organisationLinked", organisationLinked);
        component.set("v.externalContactLinked", externalContactLinked);
        component.set("v.productLinked", productLinked);
        component.set("v.opportunityLinked", opportunityLinked);
        component.set("v.notesEntered", notesEntered);
        component.set("v.campaignLinked", campaignLinked);

        var progressPercentage = 0;

        if (notesEntered){
            progressPercentage += 40;
        }

        if (externalContactLinked){
            progressPercentage += 20;
        }

        if (productLinked || opportunityLinked || campaignLinked){
            progressPercentage += 20;
        }

        if (organisationLinked)
            progressPercentage += 20;
        
        if(!externalContactLinked && !organisationLinked) {
            var compEvents = component.getEvent("contactCompanyFired");
            compEvents.setParams({ "needsContactCompany" : true });
            compEvents.fire();
        } else {
            var compEvents = component.getEvent("contactCompanyFired");
            compEvents.setParams({ "needsContactCompany" : false });
            compEvents.fire();
        }

        return progressPercentage;
    }
})