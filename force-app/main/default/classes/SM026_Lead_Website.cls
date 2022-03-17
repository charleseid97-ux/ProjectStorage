public with sharing class SM026_Lead_Website {
    
    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();
    
    
    public static void sendAsyncWebsiteLead(Map<Id, Lead> newItems,  Map<Id, Lead> oldItems){

        System.debug('sendAsyncWebsiteLead : '+newItems);

        Set<Id> leadsToSend = new Set<Id>();

        for(Lead aLead : newItems.values()){

            if(isWebsiteSync(aLead, oldItems)){
                leadsToSend.add(aLead.Id);
                Pad.SKIP_STRIGGER_MAP.put('sendAsyncWebsiteLead', 'prevent double execution');
            }
        }
        
        if(leadsToSend.size() > 0) System.enqueueJob(new SM026_SendSelectedLeadsAsync(retrieveLeads(leadsToSend), 0, 1));

    }

    private static boolean isWebsiteSync(Lead aLead, Map<Id, Lead> oldItems) {

        System.debug('isWebsiteSync : '+aLead);
        return aLead.TECH_WebSiteID__c != null  && aLead.Synchrostatus__c != oldItems.get(aLead.id).Synchrostatus__c && aLead.Synchrostatus__c == 'To be synced';
    }

    /*
    * When lead is converted transfer prospace alert and update  custom field on contact
    */
    /**
     * @author Noor
     * @date 20/11/2020
     * @description Perform actions when a prospace Lead is converted.
     *
     * @param newItems
     */
    public static void processConvertedLead(Map<Id, Lead> newItems) {

        Map<Id, Id> leadIdByContactIdMap = new Map<Id, Id>();
        Map<Id, Lead> contactIdByLeadMap = new Map<Id, Lead>();

        Id websiteLeadRT = UtilitiesSObject.getRecordTypeIdByDeveloperName(Lead.SObjectType, 'Website_Lead');

        for (Lead ld : newItems.values()) {
            if (ld.IsConverted && ld.RecordTypeId == websiteLeadRT && ld.TECH_WebSiteID__c != null) {
                leadIdByContactIdMap.put(ld.Id, ld.ConvertedContactId);
                contactIdByLeadMap.put(ld.ConvertedContactId, ld);
            }
        }

        if (!leadIdByContactIdMap.isEmpty()) transferProspaceAlert(leadIdByContactIdMap);

        if(!contactIdByLeadMap.isEmpty()) updateConvertedContactFields(contactIdByLeadMap);

        Pad.SKIP_STRIGGER_MAP.put('processConvertedLead', 'prevent double execution');

    }

    /**
     * @author Noor
     * @description Method used when a lead is converted, if a new contact is created or an existing contact with no TECH_Website Id is used
     *              all website infomation from the lead is mapped on the Contact
     *              If in case the lead is converted to to an existing contact which has a TECH_Website Id, the existing contact is used
      *             then the website user corresponding to the lead is deleted
     * @param aContactIdByLeadMap
     */
    private static void updateConvertedContactFields(Map<Id, Lead> aContactIdByLeadMap) {

        List<Contact> contactConvertedList = [SELECT Id,FirstNameWebsite__c,LastNameWebsite__c,WebsiteCompany__c, Business_Card_Title__c,
                WebsiteSalutation__c,WebsiteJobTitle__c,WebsiteLogin__c,PostalCode__c,
                PhoneNumber__c, MobileNumber__c,Address1__c,City__c, Country__c, Title, TECH_WebSiteID__c
        FROM Contact WHERE Id IN :aContactIdByLeadMap.keySet()];

        List<Contact> updatedContactList = new List<Contact>();
        List<Lead> leadToBeDeleted = new List<Lead>();

        for (Contact con : contactConvertedList) {
            Lead convertedLead = aContactIdByLeadMap.get(con.Id);

            if(con.TECH_WebSiteID__c == convertedLead.TECH_WebSiteID__c){
                updatedContactList.add(updateNewContactWithLeadInfo(con, convertedLead));
            }else {
                leadToBeDeleted.add(convertedLead);
                updatedContactList.add(updateExistingContactToValidated(con, convertedLead));
            }
        }

        if(updatedContactList.size() > 0) Database.update(updatedContactList, true);

        if(leadToBeDeleted.size() > 0 ) System.enqueueJob(new SM026_DeleteWebsiteLeadsAsync(leadToBeDeleted, 0, 1));

    }

    /*
   * When lead is converted transfer prospace alert and update  custom field on contact
   */
    public static void transferProspaceAlert( Map<Id, Id> leadIdByContactIdMap) {

        List<Web_Communication__c> webCommToUpdateList = new List<Web_Communication__c>();

        //retrieve all webcommunication attached to lead
        for (Web_Communication__c webComm : [SELECT Id, Contact__c, Lead__c, Lead__r.Id
        FROM Web_Communication__c
        WHERE Lead__r.Id IN :leadIdByContactIdMap.keySet()]) {
            webComm.Contact__c = leadIdByContactIdMap.get(webComm.Lead__r.Id);
            webComm.Lead__c = null;
            webCommToUpdateList.add(webComm);
        }

        if (webCommToUpdateList.size() > 0) Database.update(webCommToUpdateList, true);

    }
    
    public static void deleteLeadAlerts(List<Lead> leadList, Map<Id, Lead> oldLeadMap) {
        
        Set<Lead> leadAlertToDeleteSet = new Set<Lead>();
        
        for(Lead l : leadList){
            Lead oldLead = oldLeadMap.get(l.ID);
            if ((l.Status != oldLead.Status) && (l.Status == 'Disqualified')) {
                leadAlertToDeleteSet.add(l);
            }
            if ((l.Prospace_Status__c != oldLead.Prospace_Status__c) && (l.Prospace_Status__c == 'Disabled')) {
                leadAlertToDeleteSet.add(l);
            }
        }
        
        SM029_WebCommunication.delAllLeadAlerts(leadAlertToDeleteSet);
        
        Pad.SKIP_STRIGGER_MAP.put('deleteLeadAlerts', 'prevent double execution');
        
    }


    private static Contact updateExistingContactToValidated(Contact con, Lead convertedLead) {
        con.Prospace_Status__c = 'Validated';
        con.Synchrostatus__c = 'To be synced';
        con.Source__c = convertedLead.LeadSource;

        return con;
    }

    private static Contact updateNewContactWithLeadInfo(Contact con, Lead convertedLead) {
        con.FirstNameWebsite__c = convertedLead.FirstName;
        con.LastNameWebsite__c = convertedLead.LastName;
        con.WebsiteCompany__c = convertedLead.Company;
        con.WebsiteSalutation__c = convertedLead.Salutation;
        con.WebsiteJobTitle__c = convertedLead.Business_Card_Title__c;
        con.WebsiteLogin__c = convertedLead.Email;
        con.PostalCode__c = convertedLead.PostalCode;
        con.PhoneNumber__c = convertedLead.Phone;
        con.MobileNumber__c = convertedLead.MobilePhone;
        con.Address1__c = convertedLead.Street;
        con.City__c = convertedLead.City;
        con.Country__c = convertedLead.CountryCode;
        con.Source__c = convertedLead.LeadSource;
        con.Synchrostatus__c = 'To be synced';

        return con;
    }

    public static void deleteAsyncWebsiteLead(Map<Id, Lead> oldItems){

        List<Lead> leadToDeleteList = new List<Lead>();

        for (Lead ld : oldItems.values()) {
            if (!String.isEmpty(ld.TECH_WebSiteID__c)) {
                leadToDeleteList.add(ld);
            }
        }

        if (leadToDeleteList.size() > 0) System.enqueueJob(new SM026_DeleteWebsiteLeadsAsync(leadToDeleteList, 0, 1));
    }
    
    public Static List<Lead> retrieveLeads(Set<Id> aLeadIdSet){
        
        List<Lead> leadList = [SELECT Id, FirstName, LastName, Email, Street, City, Country, MobilePhone, Phone, PostalCode,
                               Company, Business_Card_Title__c, Salutation, Prospace_Status__c, CountryCode, Job_Title__c,
                               WebsiteCountry__c, WebsiteLanguage__c, TECH_WebSiteID__c, Title, Language__c
                               FROM Lead 
                               WHERE Id IN :aLeadIdSet
                               LIMIT 50000];
        
        return leadList;
        
    }
    
    public static Set<Id> processIdLeads(List<Lead> aLeadToProcessList){
        
        Set<Id> leadIdSet = new Set<Id>();
        
        for(Lead ld : aLeadToProcessList){
            leadIdSet.add(ld.Id);            
        }
        
        return leadIdSet;
    }
    
    
    public void processResetLeadPassword(List<Lead> aLeadList){
        
        //build JSON to reset password
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        JSONGeneratorChecker.writeStringField(gen, 'contactId', String.valueOf(aLeadList[0].id));
        gen.writeEndObject();   
        
        String jsonS = gen.getAsString();
        
        //Reset password endpoints
        String resetPasswordEndpoint = '/webservice/v2/contacts/'+aLeadList[0].TECH_WebSiteID__c+'/reset-password';
        String resetPasswordMethod = 'POST';
        
        //call method to connect to website
        connectAndSendLeads(jsonS, aLeadList[0], resetPasswordEndpoint, resetPasswordMethod);
        
    }
    
    public void processSelectedLeads(List<Lead> aLeadToSendList){
        
        //Check if lead external Id is present, update lead in website
        String websiteEndpoint = '', websiteMethod = '';
        
        //update Lead in website
        websiteEndpoint = '/webservice/v2/contacts/'+aLeadToSendList[0].TECH_WebSiteID__c;
        websiteMethod = 'PUT';
        
        
        //Build JSON Lead body to send to website 
        String leadJson = generateLeadJson(aLeadToSendList);
        
        //Perform HTTP request and add JSON body; Update leads fields with website response
        connectAndSendLeads(leadJson, aLeadToSendList[0], websiteEndpoint, websiteMethod);

        
    }
    
    public void connectAndSendLeads(String aLeadJson, Lead aLeadToSent, String aWebsiteEndpoint, String aWebsiteMethod){
        
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        Http http = new Http();
        req.setEndpoint('callout:CarmignacWebsite'+aWebsiteEndpoint);
        req.setMethod(aWebsiteMethod);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(aLeadJson);
        
        try {
            if(!Test.isRunningTest()){
                res = http.send(req);
            }else{
                MCK012_WebsiteMockWS mockContactWS = new MCK012_WebsiteMockWS();
                res = mockContactWS.syncContact(req, aWebsiteMethod, 'success'); 
            }
            if (res.getStatusCode() == 200) {
                System.debug('Success!');
                if(aWebsiteMethod == 'DELETE'){
                    return;
                }
                if(res.getBody() == '' || res.getBody() == null){
                    aLeadToSent.WebsiteResponse__c = String.valueOf(res.getStatusCode());
                }else{
                    aLeadToSent.WebsiteResponse__c = String.valueOf(res.getBody());
                }
                aLeadToSent.Synchrostatus__c = 'Success';
                
            } else {
                try{
                    if(aWebsiteMethod == 'DELETE'){
                        return;
                    }
                    Map<String, Object> o = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    if(o.get('message') != null){
                        String errMessage = EncodingUtil.urlDecode(String.valueof(o.get('message')), 'utf-8');
                        aLeadToSent.WebsiteResponse__c = 'ERROR: ' + errMessage;
                        
                    }else{
                        aLeadToSent.WebsiteResponse__c = 'ERROR: ' + res.getBody();
                        
                    }
                }catch(Exception e){
                    System.debug('Error retrieving content');
                    aLeadToSent.WebsiteResponse__c = 'ERROR: Website connection error';
                }
                aLeadToSent.Synchrostatus__c = 'Failed';
            }

            PAD.SKIP_STRIGGER_MAP.put('sendAsyncWebsiteLead', 'prevent double execution');
            PAD.SKIP_STRIGGER_MAP.put('processConvertedLead', 'prevent double execution');
            PAD.SKIP_STRIGGER_MAP.put('updateCampaignMembersForLead', 'prevent double execution');
            PAD.SKIP_STRIGGER_MAP.put('initializeNewLeadFromWebSite', 'prevent double execution');
            PAD.SKIP_STRIGGER_MAP.put('initializeExistingLeadFromWebSite', 'prevent double execution');

            Database.update(aLeadToSent, true);

            
            
        } catch(System.CalloutException e) {
            System.debug('Callout error: '+ e);
            EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(res, req, aLeadToSent.Id, 'SM026_Lead_Website', 'connectAndSendLeads');
            listLogError.add(newErro);   
        }
        
        if(listLogError.size() > 0){        
            EM023_Log.insertLogError(listLogError);
        }
        
    }
    
    private String generateLeadJson(List<Lead> aLeadToSendList){
        
        JSONGenerator gen = JSON.createGenerator(true);   
        
        for (integer i = 0; i < aLeadToSendList.size(); i++){
            
            gen.writeStartObject();
            JSONGeneratorChecker.writeStringField(gen, 'SalesForceId', String.valueOf(aLeadToSendList[i].id));
            JSONGeneratorChecker.writeStringField(gen, 'FirstName', aLeadToSendList[i].FirstName);
            JSONGeneratorChecker.writeStringField(gen, 'LastName', aLeadToSendList[i].LastName);
            JSONGeneratorChecker.writeStringField(gen, 'Email', aLeadToSendList[i].Email);
            JSONGeneratorChecker.writeStringField(gen, 'WebsiteCompany', aLeadToSendList[i].Company);
            JSONGeneratorChecker.writeStringField(gen, 'WebsiteCountry', aLeadToSendList[i].WebsiteCountry__c);
            JSONGeneratorChecker.writeStringField(gen, 'WebsiteLanguage', aLeadToSendList[i].WebsiteLanguage__c);
            JSONGeneratorChecker.writeStringField(gen, 'CivilityTitle', aLeadToSendList[i].Salutation);
            JSONGeneratorChecker.writeStringField(gen, 'JobTitle', aLeadToSendList[i].Business_Card_Title__c);
            JSONGeneratorChecker.writeStringField(gen, 'Address', aLeadToSendList[i].Street);
            JSONGeneratorChecker.writeStringField(gen, 'AddressZip', aLeadToSendList[i].PostalCode);
            JSONGeneratorChecker.writeStringField(gen, 'AddressCity', aLeadToSendList[i].City);
            JSONGeneratorChecker.writeStringField(gen, 'AddressCountry', aLeadToSendList[i].CountryCode);
            JSONGeneratorChecker.writeStringField(gen, 'PhoneNumber', aLeadToSendList[i].Phone);
            JSONGeneratorChecker.writeStringField(gen, 'Language', aLeadToSendList[i].Language__c);
            //JSONGeneratorChecker.writeStringField(gen, 'PlainPassword', 'Test01*01SaX');
            //JSONGeneratorChecker.writeStringField(gen, 'Active', '1');
            JSONGeneratorChecker.writeStringField(gen, 'ObjectType', 'Lead');
            JSONGeneratorChecker.writeStringField(gen, 'ProSpaceStatus', aLeadToSendList[i].Prospace_Status__c);
            gen.writeEndObject();
            
        }
        
        String jsonS = gen.getAsString();
        
        return jsonS;
        
    }
    
    
    public void deleteWebsiteLead(List<Lead> aLeadList){
        
        //build JSON to reset password
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        JSONGeneratorChecker.writeStringField(gen, 'contactId', '003');
        gen.writeEndObject();   
        
        String jsonS = gen.getAsString();
        
        //Delete password endpoints
        String deletePasswordEndpoint = '/webservice/v2/contacts/'+aLeadList[0].TECH_WebSiteID__c;
        String deletePasswordMethod = 'DELETE';
        
        //call method to connect to website
        connectAndSendLeads(jsonS, aLeadList[0], deletePasswordEndpoint, deletePasswordMethod);
        
    }

    public static void updateLeadOwner(Map<Id, Lead> newItems, Map<Id, Lead> oldItems){

        for (Lead aLead : (List<Lead>) newItems.values()) {
            if (!aLead.Status.equalsIgnoreCase(oldItems.get(aLead.Id).Status) &&
                    !aLead.Status.equalsIgnoreCase('Pending Qualification')){
                alead.OwnerId = UserInfo.getUserId();
                Pad.SKIP_STRIGGER_MAP.put('updateLeadOwner', 'prevent double execution');
            }
        }
    }

    public static void initializeExistingLeadFromWebSite(Map<Id, Lead> newItems, Map<Id, Lead> oldItems){

        List<Lead> leadToUpdate = new List<Lead>();

        for (Lead ld : (List<Lead>) newItems.values()) {
            //When lead is updated to Website
            if (oldItems.get(ld.Id).TECH_WebSiteID__c == null && ld.TECH_WebSiteID__c != null)  leadToUpdate.add(ld);
        }
        if(leadToUpdate.size() > 0){
            initializeLeadFromWebSite(leadToUpdate, false);
            Pad.SKIP_STRIGGER_MAP.put('initializeExistingLeadFromWebSite', 'prevent double execution');
        }

    }
    public static void initializeNewLeadFromWebSite(List<Lead> leads){

        initializeLeadFromWebSite(leads, true);
        Pad.SKIP_STRIGGER_MAP.put('initializeNewLeadFromWebSite', 'prevent double execution');

    }

    public static void initializeLeadFromWebSite(List<Lead> leads, boolean isInsert){

        //Set recordtype for lead created by website
        //TODO Replace with get describe
        List<RecordType> websiteRecordTypeId = [SELECT Id FROM RecordType WHERE Name = :Label.Website_Recordtype_Name LIMIT 1];

        /* Call Website webservice 2.0*/
        //activate assignment rules
        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.assignmentRuleHeader.useDefaultRule = true;

        for (Lead ld : leads) {

            if (ld.TECH_WebSiteID__c != null) {
                //set recordtype for website lead
                ld.RecordTypeId = websiteRecordTypeId[0].Id;
                //set default field values
                ld.Status = 'Pending Qualification';
                ld.Prospace_Status__c = 'Pending';
                ld.Business_Card_Title__c = ld.Title;
                if(isInsert){
                    ld.LeadSource = 'Website';
                    ld.Lead_Sub_Source__c = 'Web self-registration';
                }
                //activate assignment rules for the new leads
                ld.setOptions(dmo);
            }
        }
    }
}