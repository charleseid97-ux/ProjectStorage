public class ClientInterestToPreferenceCenter {
    private static Map<String,String> getClientIntrestToPreferenceCenterMap() {

        return MetadataUtils.getPrefCenterFundsFromProductAndCountries();
    }

    private static MeetingNotesMatrixWrapper getMeetingNoteMatrix(List<ClientInterest__c> interests) {
        Map<Id, List<ClientInterest__c>> meetingNoteToInterestMap = new Map<Id, List<ClientInterest__c>>();
        Map<Id, List<Contact>> meetingNoteToContactMap = new Map<Id, List<Contact>>();
    
        // Collect ClientInterests by Meeting Note
        for (ClientInterest__c clInterest : interests) {
            if (meetingNoteToInterestMap.containsKey(clInterest.MeetingNote__c)) {
                meetingNoteToInterestMap.get(clInterest.MeetingNote__c).add(clInterest);
            } else {
                meetingNoteToInterestMap.put(clInterest.MeetingNote__c, new List<ClientInterest__c>{clInterest});
            }
        }
    
        // Query EventRelations to get RelationIds and Meeting Notes
        List<EventRelation> eventRelationList = [SELECT RelationId, Event.Meeting_Note__c FROM EventRelation WHERE Event.Meeting_Note__c IN :meetingNoteToInterestMap.keySet() AND Relation.Type = 'Contact'];
        List<Id> contactIds = new List<Id>();
        for (EventRelation evtRlt : eventRelationList) {
            contactIds.add(evtRlt.RelationId);
        }
        // Query Contacts for WebsiteCountry__c using the RelationIds
        List<Contact> contacts = [SELECT Id, WebsiteCountry__c FROM Contact WHERE Id IN :contactIds];
    
        // Create a map of Contact Id to Contact for easy access
        Map<Id, Contact> contactMap = new Map<Id, Contact>();
        for (Contact contact : contacts) {
            contactMap.put(contact.Id, contact);
        }
    
        // Build the meetingNoteToContactMap
        for (EventRelation eventElt : eventRelationList) {
            Id meetingNoteId = eventElt.Event.Meeting_Note__c;
            Contact contact = contactMap.get(eventElt.RelationId);
    
            if (meetingNoteToContactMap.containsKey(meetingNoteId)) {
                meetingNoteToContactMap.get(meetingNoteId).add(contact);
            } else {
                meetingNoteToContactMap.put(meetingNoteId, new List<Contact>{contact});
            }
        }
        return new MeetingNotesMatrixWrapper(meetingNoteToContactMap, meetingNoteToInterestMap);
    }

    public static void updateContacts(Map<Id, SObject> interestsMap) {
        List<SObject> interests = new List<SObject>();
        for (SObject interest : interestsMap.values()){
            interests.add(interest);
        }

        Map<String,String>  clientIntrestToPreferenceCenterMap =  getClientIntrestToPreferenceCenterMap();
        if(! clientIntrestToPreferenceCenterMap.isEmpty()){
           
            MeetingNotesMatrixWrapper matrix = getMeetingNoteMatrix(interests);
            Map<Id, List<Contact>> meetingNoteToContactMap = matrix.meetingNoteToContactMap ;
            Map<Id, List<ClientInterest__c>> meetingNoteToInterestMap = matrix.meetingNoteToInterestMap ;
            Map<Id, Contact> contactsToUpdateMap = new Map<Id, Contact>();
            String country = '' ;
            // Under a meeting note ALL the related contacts should be updated as follow:
            // If the Client interested on a product > 3 => the concerned contact's field = True
            // If the Client interested on a product < 3 => the concerned contact's field = False
            for (Id noteId : meetingNoteToContactMap.keySet() ) {
                for (Contact tmpContact : meetingNoteToContactMap.get(noteId)) {
                    for (ClientInterest__c tmpInterest  : meetingNoteToInterestMap.get(noteId)) {
                        country = tmpContact.WebsiteCountry__c;
                        if(String.isBlank(country)){
                            country = 'empty';
                        }
                        if(clientIntrestToPreferenceCenterMap.containsKey(tmpInterest.TECH_ProductName__c+'_'+country)){
                            if(tmpInterest.Interest__c > 3){
                                tmpContact.put(clientIntrestToPreferenceCenterMap.get(tmpInterest.TECH_ProductName__c+'_'+country)+'__c', true);
                                contactsToUpdateMap.put(tmpContact.id,tmpContact);
                            }
                            else if(tmpInterest.Interest__c < 3) {
                                tmpContact.put(clientIntrestToPreferenceCenterMap.get(tmpInterest.TECH_ProductName__c+'_'+country)+'__c', false);
                                contactsToUpdateMap.put(tmpContact.id,tmpContact);
                            }

                        }
                    }
                }
            }
            update contactsToUpdateMap.values(); 
        }
    }

    private class MeetingNotesMatrixWrapper {

        Map<Id, List<Contact>> meetingNoteToContactMap; 
        Map<Id, List<ClientInterest__c>> meetingNoteToInterestMap;
        public MeetingNotesMatrixWrapper(Map<Id, List<Contact>> meetingNoteToContactMap , Map<Id, List<ClientInterest__c>> meetingNoteToInterestMap) {
            this.meetingNoteToContactMap = meetingNoteToContactMap;
            this.meetingNoteToInterestMap = meetingNoteToInterestMap;
        }
    
    }
}