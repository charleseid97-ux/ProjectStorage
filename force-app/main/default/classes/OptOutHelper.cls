/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 04-05-2024
 * @last modified by  : SILA Nicolas
**/

public class OptOutHelper {
    private static final Map<String, String> CODE_TO_EXPLANATION_MAP = new Map<String, String>{ 
    '5.0.0'=>'Unknown issue', '5.1.0'=>'Other address status'  , '5.1.1'=>'Bad destination mailbox address'  , 
    '5.1.2'=>'Bad destination system address'  , '5.1.3'=>'Bad destination mailbox address syntax', '5.1.4'=>'Destination mailbox address ambiguous', 
    '5.1.5'=>'Destination mailbox address valid', '5.1.6'=>'Mailbox has moved', '5.1.7'=>'Bad sender’s mailbox address syntax', '5.1.8' =>'Bad sender’s system address', 
    '5.2.0'=>'Other or undefined mailbox status', '5.2.1'=>'Mailbox disabled, not accepting messages', '5.2.2'=>'Mailbox full', '5.2.3'=>'Message length exceeds administrative limit', 
    '5.2.4'=>'Mailing list expansion problem', '5.3.0'=>'Other or undefined mail system status', '5.3.1'=>'Mail system full', '5.3.2'=>'System not accepting network messages', 
    '5.3.3'=>'System not capable of selected features', '5.3.4'=>'Message too big for system', '5.4.0'=>'Other or undefined network or routing status', '5.4.1'=>'No answer from host', 
    '5.4.2'=>'Bad connection', '5.4.3'=>'Routing server failure', '5.4.4'=>'Unable to route', '5.4.5'=>'Network congestion', '5.4.6'=>'Routing loop detected', '5.4.7'=>'Delivery time expired', 
    '5.5.0'=>'Other or undefined protocol status', '5.5.1'=>'Invalid command', '5.5.2'=>'Syntax error', '5.5.3'=>'Too many recipients', '5.5.4'=>'Invalid command arguments', '5.5.5'=>'Wrong protocol version', 
    '5.6.0'=>'Other or undefined media error' , '5.6.1'=>'Media not supported' , '5.6.2'=>'Conversion required and prohibited' , '5.6.3'=>'Conversion required but not supported' , 
    '5.6.4'=>'Conversion with loss performed' , '5.6.5'=>'Conversion failed' , '5.7.0'=>'Other or undefined security status' , '5.7.1'=>'Delivery not authorized, message refused' , 
    '5.7.2'=>'Mailing list expansion prohibited' , '5.7.3'=>'Security conversion required but not possible' , '5.7.4'=>'Security features not supported' , '5.7.5'=>'Cryptographic failure' , 
    '5.7.6'=>'Cryptographic algorithm not supported' , '5.7.7'=>'Message integrity failure'  };



    private static final String HARD_BOUNCED_FIELD = 'pi__pardot_hard_bounced__c';
    private static final String MANDRILL_HARD_BOUNCED_FIELD = 'HardBounced_Mandrill__c';
    private static final String OPT_OUT_FIELD = 'HasOptedOutOfEmail';
    private static final String GDPR_OPT_OUT_FIELD = 'GDPR_external_request_for_data_deletion__c';
    private static final String DELETE_FLAG_FIELD = 'To_Delete__c';
    private static final String SF_EMAIL_BOUNCED = 'IsEmailBounced';
    
    public static String addOptOutMessage(Contact record, Contact oldContact, String toggleField, String messageField) {
        if ( oldContact.get(toggleField) != record.get(toggleField)) {
            if (toggleField == HARD_BOUNCED_FIELD || toggleField == MANDRILL_HARD_BOUNCED_FIELD || toggleField == SF_EMAIL_BOUNCED){
                if(record.get(HARD_BOUNCED_FIELD) == true){
                    return generateHardBounceMessage(record.EmailBouncedReason, 'Pardot');
                } else if (record.get(MANDRILL_HARD_BOUNCED_FIELD) == true){
                    return generateHardBounceMessage(record.HardBounced_Mandrill_Reason__c, 'Prospace');
                } else if(record.get(SF_EMAIL_BOUNCED) == true){
                    return generateHardBounceMessage(record.EmailBouncedReason, 'Salesforce');
                }
                return '';
            } else if (record.get(toggleField) == false || (toggleField != OPT_OUT_FIELD && record.get(OPT_OUT_FIELD) == true)) {
                return '';
            } else {
                return generateOptOutMessage(record,toggleField);
            }
        }
        else if(record.get(toggleField) == false){
            return '';
        }
        return (String) record.get(messageField);
    }

    private static String generateHardBounceMessage(String bounceReason, String service) {
        String errorMessage = 'Unknown Error';
        for (String code : CODE_TO_EXPLANATION_MAP.keySet()) {
            if (bounceReason != null && bounceReason.contains(code)) {
                errorMessage = CODE_TO_EXPLANATION_MAP.get(code);
            }
        }
        return service + ' hard bounce occurred due to: ' + errorMessage;
    }

    private static String generateOptOutMessage(Contact record, String toggleField) {
        String currentUser = UserInfo.getName();
        String currentDate = Datetime.now().format('dd-MM-yyyy') + ' at ' + Datetime.now().format('HH:mm:ss');
        if (currentUser == 'B2BMA Integration') {
            return 'Client has opted out on ' + currentDate;
        } else {
            String optOutReason = record.OptOut_Reason__c != null ? ' due to the following reason: ' + record.OptOut_Reason__c : '';
            if (record.GDPR_external_request_for_data_deletion__c) {
                return currentUser + ' has flagged this contact for GDPR external request for data deletion on ' + currentDate;
            } else if (record.To_Delete__c) {
                return currentUser + ' has flagged this contact for GDPR flag for deletion on ' + currentDate;
            } else if (toggleField != 'HasOptedOutOfEmail') {
                return currentUser+ ' opted out the client on ' + currentDate;                
            } else {
                return currentUser + ' opted out the client on ' + currentDate + optOutReason;
            }
        }
    }

    public static void getLastModifiedOptOut(List<Contact> records, Map<Id, Contact> oldContacts) {
        try {
            for (Contact record : records) {
                Contact oldContact = oldContacts.get(record.Id);
                record.General_Opt_Out_Message__c = addOptOutMessage(record, oldContact, OPT_OUT_FIELD, 'General_Opt_Out_Message__c');
                record.Newsletter_Opt_Out_Message__c = addOptOutMessage(record, oldContact, 'Newsletter_Opt_Out__c', 'Newsletter_Opt_Out_Message__c');
                record.Prospace_Opt_Out_Message__c = addOptOutMessage(record, oldContact, 'Prospace_Opt_Out__c', 'Prospace_Opt_Out_Message__c');
                record.Invitation_Opt_Out_Message__c = addOptOutMessage(record, oldContact, 'Invitation_Opt_Out__c', 'Invitation_Opt_Out_Message__c');
                record.Hardbounced_Message__c = addOptOutMessage(record, oldContact, HARD_BOUNCED_FIELD, 'Hardbounced_Message__c');
                if (String.isBlank(record.Hardbounced_Message__c)) {
                    record.Hardbounced_Message__c = addOptOutMessage(record, oldContact, MANDRILL_HARD_BOUNCED_FIELD, 'Hardbounced_Message__c');
                } else if(String.isBlank(record.Hardbounced_Message__c)){
                    record.Hardbounced_Message__c = addOptOutMessage(record, oldContact, SF_EMAIL_BOUNCED, 'Hardbounced_Message__c');
                }
            }
        } catch (Exception e) {
            System.debug(e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
}