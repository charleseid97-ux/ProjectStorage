public class ContactTH {

    public static void onBeforeInsert(List<Contact> contacts){
        for(Contact c : contacts) {
            if(c.Proposed_Contact_Owner__c!=null) {
                User currentOwner = ContactUtil.getCurrentUser(c.ownerId);
                User proposedOwner = ContactUtil.getCurrentUser(c.Proposed_Contact_Owner__c);
                Boolean autoApprove = ContactUtil.autoApproveChange(currentOwner.BusinessDevelopmentRegions__c, proposedOwner.BusinessDevelopmentRegions__c);
                if(autoApprove) {
                    c.OwnerId = c.Proposed_Contact_Owner__c;
                    c.Proposed_Contact_Owner__c = null;
                }
            }
        }
    }
}