/**
* Created by Noor Nabee on 7/30/2019.
*/

public with sharing class SM026_Contact_Website {

    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();

    /**
     * @author  Noor
     * @description  Send the contact to website asynchronously
     * @param aContactList
     */
    public static void sendAsyncWebsiteContact(List<Contact> aContactList) {
        //Set<Id> contactIdSet = processIdContacts();
        List<Contact> contactList = retrieveContacts(new Set<Contact>(aContactList));
        //The list of contact is send one by one to the website since the website API doesnot support list
        System.enqueueJob(new SM026_SendSelectedContactsAsync(contactList, 0, 1));
    }

    /**
     * @author  Noor
     * @description  Delete the contact to website asynchronously
     * @param aContactList
     */
    public static void deleteAsyncWebsiteContact(List<Contact> aContactList) {
        //The list of contact is send one by one to the website since the website API doesnot support list
        System.enqueueJob(new SM026_DeleteWebsiteContactsAsync(aContactList, 0, 1));
    }

    /**
     * @author  Noor
     * @description  retrieve contact fields from Id
     *
     * @param aContactIdSet
     *
     * @return
     */
    public static List<Contact> retrieveContacts(Set<Contact> aContactIdSet) {

        List<Contact> contactList = [
                SELECT Id, FirstName, LastName, Email, MailingStreet, MailingCity, MailingCountry, MobilePhone, Phone, Account.Type,BlockEmail__c,
                        Account.Name, Salutation, Prospace_Status__c, MailingCountryCode, Language__c, Business_Card_Title__c, WebsiteLogin__c, MailingPostalCode,
                        WebsiteCompany__c, WebsiteCountry__c, WebsiteLanguage__c, JobTitle__c, Address1__c, City__c, Title, ContactStatus__c,Account.Competitor__c,
                        Country__c, PostalCode__c, PhoneNumber__c, TECH_WebSiteID__c, WebsiteSalutation__c, FirstNameWebsite__c, LastNameWebsite__c, WebsiteJobTitle__c
                FROM Contact
                WHERE Id IN :aContactIdSet
                LIMIT 50000
        ];

        return contactList;

    }


    public static void processSelectedContacts(List<Contact> aContactToSendList) {

        String websiteEndpoint = '/webservice/v2/contacts';
        //Build JSON contact body to send to website
        String contactJson = generateContactJson(aContactToSendList);
        System.debug('processSelectedContacts request :' + contactJson);
        //Check if contact external Id is present, if null create new contact in website, else update contact in website
        if (aContactToSendList[0].TECH_WebSiteID__c != null)
            connectAndSendContacts(contactJson, aContactToSendList[0], websiteEndpoint +'/'+ aContactToSendList[0].TECH_WebSiteID__c, 'PUT');
        else
            connectAndSendContacts(contactJson, aContactToSendList[0], websiteEndpoint, 'POST');

    }

    public static void connectAndSendContacts(String aContactJson, Contact aContactToSent, String aWebsiteEndpoint, String aWebsiteMethod) {

        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        Http http = new Http();
        req.setEndpoint('callout:CarmignacWebsite' + aWebsiteEndpoint);
        req.setMethod(aWebsiteMethod);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(aContactJson);

        try {

            if (!Test.isRunningTest()) {
                res = http.send(req);
            } else {
                MCK012_WebsiteMockWS mockContactWS = new MCK012_WebsiteMockWS();
                res = mockContactWS.syncContact(req, aWebsiteMethod, 'success');
            }

            if (res.getStatusCode() == 200) {
                System.debug('Success!');
                if (aWebsiteMethod == 'DELETE') {
                    return;
                }
                if (res.getBody() == '' || res.getBody() == null) {
                    aContactToSent.WebsiteResponse__c = String.valueOf(res.getStatusCode());
                } else {
                    aContactToSent.WebsiteResponse__c = String.valueOf(res.getBody());
                }
                aContactToSent.Synchrostatus__c = 'Success';

                if (aContactToSent.Account.Competitor__c == 'Yes' || aContactToSent.Account.Type == 'Competitor') {
                    aContactToSent.Prospace_Status__c = 'Disabled';
                } else if (aContactToSent.Prospace_Status__c == '' || aContactToSent.Prospace_Status__c == null) {
                    aContactToSent.Prospace_Status__c = 'Validated';
                }

                if (aContactToSent.TECH_WebSiteID__c == null) {
                    Map<String, Object> o = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    aContactToSent.TECH_WebSiteID__c = String.valueof(o.get('id'));
                }


            } else {
                try {
                    if (aWebsiteMethod == 'DELETE') {
                        return;
                    }
                    Map<String, Object> o = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    if (o.get('message') != null) {
                        String errMessage = EncodingUtil.urlDecode(String.valueof(o.get('message')), 'utf-8');
                        aContactToSent.WebsiteResponse__c = 'ERROR: ' + errMessage;

                    } else {
                        aContactToSent.WebsiteResponse__c = 'ERROR: ' + res.getBody();

                    }
                } catch (Exception e) {
                    System.debug('Error retrieving content');
                    aContactToSent.WebsiteResponse__c = 'ERROR: Website connection error';
                }
                aContactToSent.Synchrostatus__c = 'Failed';
            }

            Database.update(aContactToSent, true);


        } catch (System.CalloutException e) {
            EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(res, req, aContactToSent.Id, 'SM026_Contact_Website', 'connectAndSendContacts');
            listLogError.add(newErro);
            System.debug('Callout error: ' + e);
        }

        if (listLogError.size() > 0) {
            EM023_Log.insertLogError(listLogError);
        }

    }

    private static String generateContactJson(List<Contact> aContactToSendList) {

        JSONGenerator gen = JSON.createGenerator(true);

        //uncomment for sending contacts in bulk, bode to build array of JSON
        //gen.writeStartObject();
        // gen.writeFieldName('contacts');
        // gen.writeStartArray();
        for (integer i = 0; i < aContactToSendList.size(); i++) {


            gen.writeStartObject();
            JSONGeneratorChecker.writeStringField(gen, 'SalesForceId', String.valueOf(aContactToSendList[i].id));
            JSONGeneratorChecker.writeStringField(gen, 'FirstName', aContactToSendList[i].FirstNameWebsite__c);
            JSONGeneratorChecker.writeStringField(gen, 'LastName', aContactToSendList[i].LastNameWebsite__c);
            JSONGeneratorChecker.writeStringField(gen, 'Email', aContactToSendList[i].WebsiteLogin__c);
            JSONGeneratorChecker.writeStringField(gen, 'WebsiteCompany', aContactToSendList[i].WebsiteCompany__c);
            JSONGeneratorChecker.writeStringField(gen, 'WebsiteCountry', aContactToSendList[i].WebsiteCountry__c);
            JSONGeneratorChecker.writeStringField(gen, 'WebsiteLanguage', aContactToSendList[i].WebsiteLanguage__c);
            JSONGeneratorChecker.writeStringField(gen, 'CivilityTitle', aContactToSendList[i].WebsiteSalutation__c);
            JSONGeneratorChecker.writeStringField(gen, 'JobTitle', aContactToSendList[i].WebsiteJobTitle__c);
            JSONGeneratorChecker.writeStringField(gen, 'Address', aContactToSendList[i].Address1__c);
            JSONGeneratorChecker.writeStringField(gen, 'AddressZip', aContactToSendList[i].PostalCode__c);
            JSONGeneratorChecker.writeStringField(gen, 'AddressCity', aContactToSendList[i].City__c);
            JSONGeneratorChecker.writeStringField(gen, 'AddressCountry', aContactToSendList[i].Country__c);
            JSONGeneratorChecker.writeStringField(gen, 'PhoneNumber', aContactToSendList[i].PhoneNumber__c);
            JSONGeneratorChecker.writeStringField(gen, 'BlockEmail__c', aContactToSendList[i].BlockEmail__c? '1':'0');
            JSONGeneratorChecker.writeStringField(gen, 'Language', String.IsBlank(aContactToSendList[i].Language__c) ? 'English' : aContactToSendList[i].Language__c);
            //JSONGeneratorChecker.writeStringField(gen, 'PlainPassword', 'Test01*01SaX');
            if (aContactToSendList[i].ContactStatus__c == 'true') {
                JSONGeneratorChecker.writeStringField(gen, 'Active', '1');
            } else {
                JSONGeneratorChecker.writeStringField(gen, 'Active', '0');
            }
            JSONGeneratorChecker.writeStringField(gen, 'ObjectType', 'Contact');
            String prospacestatus = aContactToSendList[i].Prospace_Status__c;

            if (aContactToSendList[i].Account.Competitor__c == 'Yes' || aContactToSendList[i].Account.Type == 'Competitor') {
                prospacestatus = ' Disabled';
            }

            if (prospacestatus == null || prospacestatus == '') {
                JSONGeneratorChecker.writeStringField(gen, 'ProSpaceStatus', 'Validated');
            } else {
                JSONGeneratorChecker.writeStringField(gen, 'ProSpaceStatus', prospacestatus);
            }
            gen.writeEndObject();

        }


        String jsonS = gen.getAsString();

        return jsonS;

    }


    public static void processResetContactPassword(List<Contact> aContactList) {

        //build JSON to reset password
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        JSONGeneratorChecker.writeStringField(gen, 'contactId', String.valueOf(aContactList[0].id));
        gen.writeEndObject();

        String jsonS = gen.getAsString();

        //Reset password endpoints
        String resetPasswordEndpoint = '/webservice/v2/contacts/' + aContactList[0].TECH_WebSiteID__c + '/reset-password';
        String resetPasswordMethod = 'POST';

        //call method to connect to website
        connectAndSendContacts(jsonS, aContactList[0], resetPasswordEndpoint, resetPasswordMethod);

    }

    public static void deleteWebsiteContact(List<Contact> aContactList) {

        //build JSON to reset password
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        JSONGeneratorChecker.writeStringField(gen, 'contactId', '003');
        gen.writeEndObject();

        String jsonS = gen.getAsString();

        //Delete password endpoints
        String deletePasswordEndpoint = '/webservice/v2/contacts/' + aContactList[0].TECH_WebSiteID__c;
        String deletePasswordMethod = 'DELETE';

        //call method to connect to website
        connectAndSendContacts(jsonS, aContactList[0], deletePasswordEndpoint, deletePasswordMethod);

    }

}