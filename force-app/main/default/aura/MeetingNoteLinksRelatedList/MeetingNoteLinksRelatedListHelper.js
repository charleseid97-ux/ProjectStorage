({
    load : function(component) {

        var meetingLinks = component.get("v.meetingNoteLinks");
        var accountIds = [];
        var contactIds = [];
        var internalContactIds = [];
        var productIds = [];
        var productInterests = [];
        var productSentiments = [];
        var opportunityIds = [];
        var campaignIds = [];
		var caseIds = [];

        if (meetingLinks) {

            for (var index in meetingLinks){

                var meetingLink = meetingLinks[index];

                if (meetingLink.Account__c){
                    accountIds.push(meetingLink.Account__c);
                }
                else if (meetingLink.Contact__c){
                    contactIds.push(meetingLink.Contact__c);
                }
                else if (meetingLink.Employee__c){
                    internalContactIds.push(meetingLink.Employee__c);
                }
                else if (meetingLink.Product__c){
                    productIds.push(meetingLink.Product__c);
                    productInterests.push(meetingLink.Interest_Level__c);
                    productSentiments.push(meetingLink.Product_Sentiment__c);
                }
                else if (meetingLink.Opportunity__c){
                    opportunityIds.push(meetingLink.Opportunity__c);
                }
                else if(meetingLink.Campaign__c){
                    campaignIds.push(meetingLink.Campaign__c);
                }
				else if(meetingLink.Case__c){
                    caseIds.push(meetingLink.Case__c);
                }
            }
            component.find('accountLookup').set('v.value', accountIds.join(';'));
            component.find('contactLookup').set('v.value', contactIds.join(';'));
            component.find('internalContactLookup').set('v.value', internalContactIds.join(';'));
            component.find('productLookup').set('v.value', productIds.join(';'));
            component.find('productLookup').set('v.modifierValue', productInterests.join(';'));
            component.find('productLookup').set('v.sentimentValue', productSentiments.join(';'));
            component.find('opportunityLookup').set('v.value', opportunityIds.join(';'));
            component.find('campaignLookup').set('v.value', campaignIds.join(';'));
			component.find('caseLookup').set('v.value', caseIds.join(';'));
        }
    },
    
    productLevelChange : function(component){
        var prodLevel = component.find('productLevel').get('v.value');
        var whereClause = '';
        
        if(prodLevel != 'All'){
            whereClause = 'RecordType.DeveloperName = \'' + prodLevel + '\'';
        }
        console.log(whereClause);
        
        component.find('productLookup').set('v.filter', whereClause);
    }
})