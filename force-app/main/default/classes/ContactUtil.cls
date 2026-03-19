/*************************************************************************************************************************
Class Name      :   ContactUtil
Class Desc.     :   Class used for Contact components   
Author          :   Alpha FMC

History
-------
//1.0 BP - Initial build of class on 19/2/2019
***************************************************************************************************************************/

public inherited sharing class ContactUtil {

    private static void checkContactReadAccess() {
    if (!Schema.sObjectType.Contact.isAccessible()
        || !Schema.sObjectType.Contact.fields.Id.isAccessible()
        || !Schema.sObjectType.Contact.fields.Name.isAccessible()
        || !Schema.sObjectType.Contact.fields.OwnerId.isAccessible()
        || !Schema.sObjectType.Contact.fields.Proposed_HOC_approval__c.isAccessible()
        || !Schema.sObjectType.Contact.fields.Current_HOC_approval__c.isAccessible()
        || !Schema.sObjectType.Contact.fields.Proposed_Contact_Owner__c.isAccessible()
        || !Schema.sObjectType.Contact.fields.Owner_Change_Requested_By__c.isAccessible()
        || !Schema.sObjectType.Contact.fields.BypassProposedOwnerVR__c.isAccessible()
        || !Schema.sObjectType.Contact.fields.Bypass_Apex__c.isAccessible()
        || !Schema.sObjectType.User.isAccessible()
        || !Schema.sObjectType.User.fields.Name.isAccessible()) {
        throw new AuraHandledException('Access denied to Contact fields.');
    }
}

    private static void checkContactPersonaReadAccess() {
        if (!Schema.sObjectType.Contact.isAccessible()
            || !Schema.sObjectType.Contact.fields.Persona__c.isAccessible()) {
            throw new AuraHandledException('Access denied to Contact Persona.');
        }
    }

    private static void checkUserReadAccess() {
        if (!Schema.sObjectType.User.isAccessible()
            || !Schema.sObjectType.User.fields.Id.isAccessible()
            || !Schema.sObjectType.User.fields.Name.isAccessible()
            || !Schema.sObjectType.User.fields.BusinessDevelopmentRegions__c.isAccessible()) {
            throw new AuraHandledException('Access denied to User fields.');
        }
    }

    private static void checkHocUserReadAccess() {
        if (!Schema.sObjectType.User.isAccessible()
            || !Schema.sObjectType.User.fields.Id.isAccessible()
            || !Schema.sObjectType.User.fields.Name.isAccessible()
            || !Schema.sObjectType.User.fields.Position__c.isAccessible()
            || !Schema.sObjectType.User.fields.IsActive.isAccessible()
            || !Schema.sObjectType.User.fields.TECH_TextBusinessDevelopmentRegions__c.isAccessible()) {
            throw new AuraHandledException('Access denied to HOC User fields.');
        }
    }

    private static void checkContactUpdateAccess() {
        if (!Schema.sObjectType.Contact.isUpdateable()) {
            throw new AuraHandledException('No update access on Contact.');
        }
    }

    @AuraEnabled
    public static Map<String, Object> buildApprovalData(String contactId) {
        Map<String, Object> globalResult = new Map<String, Object>();

        Contact currentContact = getCurrentContact(contactId);
        User currentUser = getCurrentUser(currentContact.OwnerId);

        List<User> currentHocs = getHOCsFromUserId(currentContact.OwnerId);
        List<User> proposedHocs = new List<User>();

        if (currentContact.Proposed_Contact_Owner__c != null) {
            proposedHocs = getHOCsFromUserId(currentContact.Proposed_Contact_Owner__c);
        }

        List<String> currHocAccess = new List<String>();
        if (!currentContact.Current_HOC_approval__c) {
            currHocAccess = addIdsToList(new List<String>(), currentHocs);
        }

        List<String> propHocAccess = new List<String>();
        if (!currentContact.Proposed_HOC_approval__c) {
            propHocAccess = addIdsToList(new List<String>(), proposedHocs);
        }

        globalResult.put('contact', currentContact);
        globalResult.put('currentUser', currentUser);
        globalResult.put('proposedHOCs', proposedHocs);
        globalResult.put('currentHOCs', currentHocs);
        globalResult.put('currHocAccess', currHocAccess);
        globalResult.put('propHOCAccess', propHocAccess);

        return globalResult;
    }

    @AuraEnabled
    public static String getContactPersona(String contactId) {
        checkContactPersonaReadAccess();

        Contact c = [
            SELECT Persona__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        return c.Persona__c;
    }

    @AuraEnabled
    public static Contact getCurrentContact(String contactId) {
        checkContactReadAccess();

        return [
            SELECT Name,
                   Id,
                   OwnerId,
                   Proposed_HOC_approval__c,
                   Current_HOC_approval__c,
                   Proposed_Contact_Owner__r.Name,
                   Proposed_Contact_Owner__c,
                   Owner_Change_Requested_By__c,
                   BypassProposedOwnerVR__c,
                   Bypass_Apex__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static Boolean autoApproveChange(String currentOwnerRegions, String userRegions) {
        if (String.isBlank(userRegions) || String.isBlank(currentOwnerRegions)) {
            return true;
        }

        List<String> currentOwnerRegionsArr = currentOwnerRegions.split(';');
        for (String currRegion : currentOwnerRegionsArr) {
            if (!String.isBlank(currRegion) && userRegions.contains(currRegion)) {
                return true;
            }
        }

        return false;
    }

    @AuraEnabled
    public static User getCurrentUser(String currentUserId) {
        checkUserReadAccess();

        return [
            SELECT Name, Id, BusinessDevelopmentRegions__c
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static void saveContact(String contactId, Boolean autoApprove, User newOwner) {
        checkContactReadAccess();
        checkContactUpdateAccess();

        Contact cUpd = getCurrentContact(contactId);

        if (autoApprove) {
            if (!Schema.sObjectType.Contact.fields.OwnerId.isUpdateable()) {
                throw new AuraHandledException('No access to update Contact Owner.');
            }
            cUpd.OwnerId = newOwner.Id;
        } else {
            if (!Schema.sObjectType.Contact.fields.BypassProposedOwnerVR__c.isUpdateable()
                || !Schema.sObjectType.Contact.fields.Bypass_Apex__c.isUpdateable()
                || !Schema.sObjectType.Contact.fields.Proposed_Contact_Owner__c.isUpdateable()
                || !Schema.sObjectType.Contact.fields.Current_HOC_approval__c.isUpdateable()
                || !Schema.sObjectType.Contact.fields.Proposed_HOC_approval__c.isUpdateable()
                || !Schema.sObjectType.Contact.fields.Owner_Change_Requested_By__c.isUpdateable()) {
                throw new AuraHandledException('No access to update Contact fields.');
            }

            cUpd.BypassProposedOwnerVR__c = true;
            cUpd.Bypass_Apex__c = true;
            cUpd.Proposed_Contact_Owner__c = newOwner.Id;
            cUpd.Current_HOC_approval__c = false;
            cUpd.Proposed_HOC_approval__c = false;
            cUpd.Owner_Change_Requested_By__c = UserInfo.getUserId();
        }

        update cUpd;
    }

    @AuraEnabled
    public static Contact approveCurrent(String contactId) {
        checkContactReadAccess();
        checkContactUpdateAccess();

        if (!Schema.sObjectType.Contact.fields.Current_HOC_approval__c.isUpdateable()) {
            throw new AuraHandledException('No access to update Current HOC approval.');
        }

        Contact cUpd = getCurrentContact(contactId);
        cUpd.Current_HOC_approval__c = true;
        update cUpd;
        return cUpd;
    }

    @AuraEnabled
    public static Contact approveProposed(String contactId) {
        checkContactReadAccess();
        checkContactUpdateAccess();

        if (!Schema.sObjectType.Contact.fields.Proposed_HOC_approval__c.isUpdateable()
            || !Schema.sObjectType.Contact.fields.BypassProposedOwnerVR__c.isUpdateable()) {
            throw new AuraHandledException('No access to update Proposed HOC approval.');
        }

        Contact cUpd = getCurrentContact(contactId);
        cUpd.Proposed_HOC_approval__c = true;
        cUpd.BypassProposedOwnerVR__c = false;
        update cUpd;
        return cUpd;
    }

    public static List<String> addIdsToList(List<String> currentIDList, List<User> usersToProcess) {
        for (User u : usersToProcess) {
            currentIDList.add(u.Id);
        }
        return currentIDList;
    }

    public static List<User> getHOCsFromUserId(String userId) {
        checkUserReadAccess();
        checkHocUserReadAccess();

        User thisUser = getCurrentUser(userId);
        Set<String> bdrSet = new Set<String>();
        Map<Id, User> uniqueHocUsers = new Map<Id, User>();

        List<User> allHOCUsers = [
            SELECT Name, Id, TECH_TextBusinessDevelopmentRegions__c
            FROM User
            WHERE Position__c = 'Head of Country'
              AND IsActive = true
        ];

        if (!String.isBlank(thisUser.BusinessDevelopmentRegions__c)) {
            for (String hocRegion : thisUser.BusinessDevelopmentRegions__c.split(';')) {
                if (!String.isBlank(hocRegion)) {
                    bdrSet.add(hocRegion.trim());
                }
            }

            for (User hoc : allHOCUsers) {
                if (String.isBlank(hoc.TECH_TextBusinessDevelopmentRegions__c)) {
                    continue;
                }

                for (String hocBdr : hoc.TECH_TextBusinessDevelopmentRegions__c.split(';')) {
                    if (!String.isBlank(hocBdr) && bdrSet.contains(hocBdr.trim())) {
                        uniqueHocUsers.put(hoc.Id, hoc);
                        break;
                    }
                }
            }
        }

        return uniqueHocUsers.values();
    }

    @AuraEnabled
    public static void rejectOwnershipChange(Contact contact) {
        checkContactUpdateAccess();

        if (!Schema.sObjectType.Contact.isAccessible()
            || !Schema.sObjectType.Contact.fields.Name.isAccessible()
            || !Schema.sObjectType.Contact.fields.Owner_Change_Requested_By__c.isAccessible()
            || !Schema.sObjectType.Contact.fields.Bypass_Apex__c.isUpdateable()
            || !Schema.sObjectType.Contact.fields.BypassProposedOwnerVR__c.isUpdateable()
            || !Schema.sObjectType.Contact.fields.Proposed_HOC_approval__c.isUpdateable()
            || !Schema.sObjectType.Contact.fields.Current_HOC_approval__c.isUpdateable()
            || !Schema.sObjectType.Contact.fields.Proposed_Contact_Owner__c.isUpdateable()
            || !Schema.sObjectType.Contact.fields.Owner_Change_Requested_By__c.isUpdateable()
            || !Schema.sObjectType.User.isAccessible()
            || !Schema.sObjectType.User.fields.Name.isAccessible()
            || !Schema.sObjectType.User.fields.Email.isAccessible()) {
            throw new AuraHandledException('Access denied.');
        }

        User requestUser = null;
        if (contact.Owner_Change_Requested_By__c != null) {
            requestUser = [
                SELECT Email, Name
                FROM User
                WHERE Id = :contact.Owner_Change_Requested_By__c
                LIMIT 1
            ];
        }

        User rejectUser = [
            SELECT Email, Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        String requestUserName = requestUser != null ? requestUser.Name : '';
        String mailbody = 'A Contact Ownership change has been rejected. Details:<br/><br/>'
            + '<strong>Contact : </strong>' + contact.Name
            + '<br/> <strong>Requested by : </strong>' + requestUserName
            + '<br/> <strong>Rejected by : </strong>' + rejectUser.Name
            + '<br/><br/>'
            + '<a href="' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + contact.Id + '">View Contact</a>';

        // sendMailMethod(requestUser != null ? requestUser.Email : null, 'Contact Owner Change Rejected', mailbody);

        contact.Bypass_Apex__c = true;
        contact.BypassProposedOwnerVR__c = false;
        contact.Proposed_HOC_approval__c = false;
        contact.Current_HOC_approval__c = false;
        contact.Proposed_Contact_Owner__c = null;
        contact.Owner_Change_Requested_By__c = null;

        update contact;
    }

    @AuraEnabled
    public static void sendMailMethod(String mMail, String mSubject, String mBody) {
        if (String.isBlank(mMail)) {
            return;
        }

        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        mail.setToAddresses(new List<String>{ mMail });
        mail.setReplyTo('info@carmignac.com');
        mail.setSenderDisplayName('Carmignac Info');
        mail.setSubject(mSubject);
        mail.setHtmlBody(mBody);

        mails.add(mail);
        Messaging.sendEmail(mails);
    }
}