/*************************************************************************************************************************
Class Name      :   ContactUtil
Class Desc.     :   Class used for Contact components   
Author          :   Alpha FMC

History
-------
//1.0 BP - Initial build of class on 19/2/2019
***************************************************************************************************************************/

public class ContactUtil {

    @AuraEnabled
    public static Map<String, Object> buildApprovalData(String contactId) {
        Map<String, Object> globalResult = new Map<String, Object>(); 
        Contact currentContact = getCurrentContact(contactId);
        User currentUser = getCurrentUser(currentContact.OwnerId);

        User[] currentHocs = new List<User>();
        currentHocs = getHOCsFromUserId(currentContact.OwnerId);
        User[] proposedHocs = new List<User>();
        proposedHocs = getHOCsFromUserId(currentContact.Proposed_Contact_Owner__c);
        
        List<String> currHocAccess = new List<String>();
        if(!currentContact.Current_HOC_approval__c)
            currHocAccess = addIdsToList(new List<String>(), currentHocs);

        List<String> propHocAccess = new List<String>();
        if(!currentContact.Proposed_HOC_approval__c)
            propHocAccess = addIdsToList(new List<String>(), proposedHocs);
            
        globalResult.put('contact', currentContact);
        globalResult.put('currentUser', currentUser);
        globalResult.put('proposedHOCs', proposedHOCs);
        globalResult.put('currentHOCs', currentHOCs);
        globalResult.put('currHocAccess', currHocAccess);
        globalResult.put('propHOCAccess', propHOCAccess);
        
        return globalResult;
    }
    
    @AuraEnabled
    public static String getContactPersona(String contactId) {
        Contact c = [SELECT Persona__c from Contact WHERE Id =: contactId];
        return c.Persona__c;
    } 
    
    @AuraEnabled
    public static Contact getCurrentContact(String contactId) {
        Contact c = [SELECT Name, 
                     Id, 
                     OwnerId, 
                     Proposed_HOC_approval__c, 
                     Current_HOC_approval__c, 
                     Proposed_Contact_Owner__r.Name, 
                     Proposed_Contact_Owner__c,
                     Owner_Change_Requested_By__c
                     from Contact WHERE Id =: contactId];
        return c;
    }
    
    @AuraEnabled
    public static Boolean autoApproveChange(String currentOwnerRegions, String userRegions) {
        Boolean autoApprove = false;

        if(userRegions == '' || userRegions == null || currentOwnerRegions == '' || currentOwnerRegions == null) {
            autoApprove = true;
        } else {
            if(currentOwnerRegions != '' && currentOwnerRegions != null) {
                String[] currentOwnerRegionsArr = currentOwnerRegions.split(';');
                For(String currRegion : currentOwnerRegionsArr) {
                    if(userRegions.contains(currRegion)) {autoApprove = true;}
                }
            }
        }
        
        return autoApprove;
    }
    
    @AuraEnabled
    public static User getCurrentUser(String currentUserId) {
        User u = [SELECT Name, Id, BusinessDevelopmentRegions__c from User WHERE Id =: currentUserId];
        return u;
    } 
    
    @AuraEnabled
    public static void saveContact(String contactId, Boolean autoApprove, User newOwner) {
        Contact cUpd = getCurrentContact(contactId);
        system.debug('CUPD : ' + contactId + ' - ' + autoApprove + ' - '+ newOwner);
        if(autoApprove){
	        system.debug('CUPD : inAuto');
            cUpd.OwnerId = newOwner.Id;
        } else {
	        system.debug('CUPD : NOTinAuto');
            cUpd.Bypass_Apex__c = true;
            cUpd.Proposed_Contact_Owner__c = newOwner.Id;
            cUpd.Owner_Change_Requested_By__c = UserInfo.getUserId();
        }
        update cUpd;
    } 
    
    @AuraEnabled
    public static Contact approveCurrent(String contactId) {
        Contact cUpd = getCurrentContact(contactId);
        cUpd.Current_HOC_approval__c = true;
        update cUpd;
        return cUpd;    
    } 
    @AuraEnabled
    public static Contact approveProposed(String contactId) {
        Contact cUpd = getCurrentContact(contactId);
        cUpd.Proposed_HOC_approval__c = true;
        update cUpd;
        return cUpd;
    } 

    public static List<String> addIdsToList(List<String> currentIDList, List<User> usersToProcess) {
        for(user u : usersToProcess) {
            currentIDList.add(u.Id);
        }
        
        return currentIdList;
    }
    
    public static List<User> getHOCsFromUserId(String userId) {
        system.debug('hoc userId : '+userId);
        User thisUser = getCurrentUser(userId);
        String BDRCompareString = '';
        Set<String> BDRSet = new Set<String>(); 
        
        List<User> allHOCUsers = [SELECT Name, Id, TECH_TextBusinessDevelopmentRegions__c FROM User 
                    WHERE Position__c = 'Head of Country' AND IsActive = true];
        List<User> HOCUsers = new List<User>();
        
        system.debug('hoc bdr : '+thisUser.BusinessDevelopmentRegions__c);
        
        if(thisUser.BusinessDevelopmentRegions__c != null) {
            String[] HOCRegionArr = thisUser.BusinessDevelopmentRegions__c.split(';');
            For(String HOCRegion : HOCRegionArr) {
                BDRCompareString = BDRCompareString+ '\''+HOCRegion+'\', ';
                BDRSet.add(HOCRegion);
            }
            for(User hoc : allHOCUsers) {
                String[] allHOCRegionArr = hoc.TECH_TextBusinessDevelopmentRegions__c.split(';');
                for(String HOCBDR : allHOCRegionArr) {
                    if(BDRSet.contains(HOCBDR)) {
                        HOCUsers.add(hoc);
                    }
                }
            }
        }
        return HOCUsers;
    }
    
    @AuraEnabled
    public static void rejectOwnershipChange(Contact contact) {
        User requestUser = [SELECT Email, Name FROM User WHERE Id =: contact.Owner_Change_Requested_By__c];
        User rejectUser = [SELECT Email, Name FROM User WHERE Id =: UserInfo.getUserId()];
        String mailbody = 'A Contact Ownership change has been rejected. Details:<br/><br/>'
            +'<strong>Contact : </strong>'+contact.Name
            +'<br/> <strong>Requested by : </strong>'+requestUser.Name
            +'<br/> <strong>Rejected by : </strong>'+rejectUser.Name
        	+'<br/><br/>'
            +'<a href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+contact.Id+'">View Contact</a>';
        //sendMailMethod(requestUser.Email, 'Contact Owner Change Rejected', mailbody);
        
        contact.Bypass_Apex__c = true;
        contact.Proposed_HOC_approval__c = false; 
        contact.Current_HOC_approval__c = false;
        contact.Proposed_Contact_Owner__c = null;
        contact.Owner_Change_Requested_By__c = null;
            
        update contact;
    }
    
    @AuraEnabled 
    public static void sendMailMethod(String mMail ,String mSubject ,String mBody){
     	List<Messaging.SingleEmailMessage> mails =  new List<Messaging.SingleEmailMessage>();     
  
		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    
        List<String> sendTo = new List<String>();
        sendTo.add(mMail);
        mail.setToAddresses(sendTo);

        mail.setReplyTo('info@carmignac.com');
		mail.setSenderDisplayName('Carmignac Info'); 
    
		mail.setSubject(mSubject);
		mail.setHtmlBody(mBody);
    
		mails.add(mail);
    
		Messaging.sendEmail(mails);
        
   }   
}