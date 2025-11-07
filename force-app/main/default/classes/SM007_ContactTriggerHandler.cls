/** 
* @author: Fabien BRACONNIER
* @date : Creation 01/02/2019
* @date : creation 
* @description : This Class is a COPY of SM007_ContactTriggerHandler allows to handle trigger events in contact entity with batch computation.
*/
public class SM007_ContactTriggerHandler {
    
    private static String CLASS_NAME = SM007_ContactTriggerHandler.class.getName();
    
    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();
    
    /**
    * @auteur : Briag GUEMARD
    * @date : Creation 04/04/2017
    * @date : Modification 10/12/2019
    * @description : This method
    * @param : List<Contact> contacts This parameter is the the new triggered contacts.
    * @return : N/A.
    */
    public static void onBeforeInsert(List<Contact> contacts) {
        
        //Get custom settings which store the last Technical id for Lead/Contact
        Id_Tech_Sun_Legacy__c setting = Id_Tech_Sun_Legacy__c.getAll().get('Sun_ID');
        system.debug('Id_Tech_Sun_Legacy__c = ' + Id_Tech_Sun_Legacy__c.getAll().get('Sun_ID'));
         
        for (Contact c : contacts) {
            if (c.Technical_ID__c == null && setting != null) {
                c.Technical_ID__c = setting.Sun_ID__c;
                system.debug(setting.Sun_ID__c);
                setting.Sun_ID__c = setting.Sun_ID__c + 1;
            }
            if(c.To_Delete__c == true || c.GDPR_external_request_for_data_deletion__c == true || c.ContactStatus__c == 'false'){
                c.HasOptedOutOfEmail = true ;
            }
            if(c.HasOptedOutOfEmail == true){
                c.Newsletter_Opt_Out__c = true ; 
                c.Invitation_Opt_Out__c = true ; 
                c.Prospace_Opt_Out__c = true ;
            }
        }
        //Update incremental value in custom settings
        if (setting != null) {
            update setting;
        }

        UtilitiesSObject.initPreferenceCenter((List<SObject>) contacts);
    }
    
    public static void onBeforeUpdateStatus(List<Contact> aContactList) {
        
        String methodName = 'onBeforeUpdate';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [aContactList] : ' + aContactList);
        
        for (Contact c : aContactList){
            if (c.ContactStatus__c == 'true') {
                c.Prospace_Status__c = 'Validated';
            } else {
                c.Prospace_Status__c = 'Disabled';
            }
        } 
    }

    public static void onBeforeUpdate(List<Contact> newContacts, Map<Id, Contact> oldContacts) {
        
        //Check the preference center and hasoptoutofemail fiels
        //Some fields may be checked or unchecked based on other fields changes
        UtilitiesSObject.checkPreferenceCenterFields(newContacts, oldContacts);
        
        for (Contact c : newContacts) {

            if(c.ContactStatus__c == 'false' && oldContacts.get(c.id).ContactStatus__c!=c.ContactStatus__c){
                c.Email = (String.isNotBlank(c.Email) && !c.Email.endsWithIgnoreCase('.inactif'))?(c.Email + '.inactif'):c.Email;
                if(c.Email?.length() > 80) c.Email = c.Email?.substring(0,80); //in case of long email 
                c.HasOptedOutOfEmail = true ;
                c.OptOut_Reason__c = 'Desactivated Contact' ;
            }

            if((c.To_Delete__c == true && oldContacts.get(c.id).To_Delete__c!=c.To_Delete__c) || (c.GDPR_external_request_for_data_deletion__c == true && oldContacts.get(c.id).GDPR_external_request_for_data_deletion__c!= c.GDPR_external_request_for_data_deletion__c ) ){
                c.HasOptedOutOfEmail = true ;
            }

            if(c.Global_Hardbounced__c && c.Email != oldContacts.get(c.id).Email){
                c.pi__pardot_hard_bounced__c = false ;
                c.Hardbounced_Message__c = 'The email address has been updated for Pardot, and the hard bounce will reset within 15 minutes.';
            }

            if(c.Global_Hardbounced__c && c.WebsiteLogin__c != oldContacts.get(c.id).WebsiteLogin__c){
                c.HardBounced_Mandrill__c = false ;
                c.Synchrostatus__c = 'To be synced';  
            }

            if(c.HasOptedOutOfEmail == true && oldContacts.get(c.id).HasOptedOutOfEmail != c.HasOptedOutOfEmail ){
                c.Newsletter_Opt_Out__c = true ; 
                c.Invitation_Opt_Out__c = true ; 
                c.Prospace_Opt_Out__c = true ; 
            } 

            if(c.HasOptedOutOfEmail == true && (c.Newsletter_Opt_Out__c == false || c.Invitation_Opt_Out__c == false || c.Prospace_Opt_Out__c == false ) )
            {
                c.HasOptedOutOfEmail = false ; 
            }

            if(c.HasOptedOutOfEmail == false && oldContacts.get(c.id).HasOptedOutOfEmail != c.HasOptedOutOfEmail && UserInfo.getName() =='B2BMA Integration' )
            {
                c.Newsletter_Opt_Out__c = false ; 
                c.Invitation_Opt_Out__c = false ; 
                c.Prospace_Opt_Out__c = false ; 
            }
        }
    }

    
    /**
    * @auteur : Pape DIOUF
    * @date : Creation 06/09/2016
    * @date : Modification 13/09/2016
    * @description : This method
    * @param : List<Contact> contacts This parameter is the the new triggered contacts.
    * @return : N/A.
    */
    public static void onAfterInsert(List<Contact> contacts) {
        
        String methodName = 'onAfterInsert';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [contacts] : ' + contacts);
        
        if (!ObjectUtil.isAccountServiceUser()) { //Check if not user Interface
            
            /* Call Website webservice 2.0*/
            List<Contact> contactsToBeSync = new List<Contact>();
            
            for (Contact contact : contacts) {
                if (isWebsiteSync(contact)) { //check status before creating
                    contactsToBeSync.add(contact);
                }
            }
            if (contactsToBeSync.size() > 0 && !Pad.SKIP_STRIGGER_MAP.containsKey('SyncContact')) {
                //System.enqueueJob(new SendSelectedContactsAsync(contactsToBeSync, 0, 1));
                System.debug('DEV --- - - contactsToBeSync' + contactsToBeSync);
                SM026_Contact_Website.sendAsyncWebsiteContact(contactsToBeSync);
                Pad.SKIP_STRIGGER_MAP.put('SyncContact', 'prevent double execution');
                Pad.SKIP_STRIGGER_MAP.put('ContactAfterInsert', 'prevent double execution');
                
            }
        }
        EM023_Log.insertLogError(listLogError);
    }
    
    /**
    * @auteur : Pape DIOUF
    * @date : Creation 06/09/2016
    * @date : Modification 06/02/19 FBR
    * @description : This method
    * @param : List<Contact> contacts This parameter is the the new triggered contacts.
    * @return : N/A.
    **/
    public static void onAfterUpdate(List<Contact> contacts, Map<Id, Contact> oldContacts) {
        
        String methodName = 'onAfterUpdate';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [contacts] : ' + contacts);
        
        List<String> ContactIds = new List<String>();
        Set<Id> contactsAlertToDeactivate = new Set<Id>();
        
        /* Call Website webservice 2.0*/
        List<Contact> contactsToBeSync = new List<Contact>();
        
        for (Contact c : contacts) {
            if (isWebsiteSync(c)) { //check status before creating
                contactsToBeSync.add(c);
                ContactIds.add(c.Id);
            }
            
            Contact oldcontact = oldContacts.get(c.ID);
            //No need cauz general OptedOut will be triggered , so all alert will be disabled by the flow 
            /*if ((c.ContactStatus__c != oldcontact.ContactStatus__c) && (c.ContactStatus__c == 'false')) {
                contactsAlertToDeactivate.add(c.Id);
            }*/
            
            if ((c.Prospace_Status__c != oldcontact.Prospace_Status__c) && (c.Prospace_Status__c == 'Disabled')) {
                contactsAlertToDeactivate.add(c.Id);
            }
        }
        if (contactsToBeSync.size() > 0 && !Pad.SKIP_STRIGGER_MAP.containsKey('SyncContact')) {
            SM026_Contact_Website.sendAsyncWebsiteContact(contactsToBeSync);
            Pad.SKIP_STRIGGER_MAP.put('SyncContact', 'prevent double execution');
            Pad.SKIP_STRIGGER_MAP.put('ContactAfterUpdate', 'prevent double execution');   
        }

        if (contactsAlertToDeactivate.size() > 0) {
            //SM029_WebCommunication.delAllContactAlerts(contactsAlertToDeleteList);
            SM029_WebCommunication.deactivateAllWebCommunication('Contact', contactsAlertToDeactivate);
        }
        
        EM023_Log.insertLogError(listLogError);
    }
    
    public static void onAfterDelete(List<Contact> aContactList) {
        
        String methodName = 'onAfterDelete';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [aContactList] : ' + aContactList);
        
        List<Contact> contactToDeleteList = new List<Contact>();
        
        for (Contact cont : aContactList) {
            if (!String.isEmpty(cont.TECH_WebSiteID__c)){
                contactToDeleteList.add(cont);
            }
        }
        
        if (contactToDeleteList.size() > 0){
            SM026_Contact_Website.deleteAsyncWebsiteContact(contactToDeleteList);
            //SM029_WebCommunication.deleteEmptyWebCommunication();
            EM023_Log.insertLogError(listLogError);
        }
    }
    
    private static boolean isWebsiteSync(Contact contact){
        return contact.Synchrostatus__c != null && contact.Synchrostatus__c.equalsIgnoreCase('To be synced');        
    }
    private static String getUserNameById(Id userId) {
        User user = [SELECT Name FROM User WHERE Id = :userId LIMIT 1];
        return user.Name;
    }
}