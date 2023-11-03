/**
* @author: Noor Goolamnabee
* @date : 12/07/2019
* @description : SM029_WebCommunication
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 12-JUL-2019  JLC         1.0    Init
*
*/
public class SM029_WebCommunication {

    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();

    /**
    * Update the field Share class and fund from TECH_ISINCode__c
    *
    * @param mapWebComm TECH_ISINCode__c  Web_Communication__c
    */
    public static void updateShareClass(Map<Web_Communication__c, String> mapWebComm) {

        Set<String> IsinSet = new Set<String>(mapWebComm.values());

        List<Share_Class__c> lstQueryShareClass = [
                SELECT Id, Fund__c, ISIN_Code__c
                FROM Share_Class__c
                WHERE ISIN_Code__c IN :IsinSet
        ];

        Map<String, Share_Class__c> shareClassISINMap = new Map<String, Share_Class__c>();
        for(Share_Class__c sc : lstQueryShareClass){
            shareClassISINMap.put(sc.ISIN_Code__c, sc);
        }

        //Map<Web_Communication__c, Share_Class__c> webComByShareClassMap = new Map<Web_Communication__c, Share_Class__c>();

        for (Web_Communication__c wc :mapWebComm.keySet()) {

            String isin = mapWebComm.get(wc);
            //webComByShareClassMap.put(wc, shareClassISINMap.get(isin));

            wc.ShareClass__c = shareClassISINMap.get(isin).Id;
            wc.Fund__c = shareClassISINMap.get(isin).Fund__c;

            //mapWebComm.get(sC.ISIN_Code__c).ShareClass__c = sC.Id;
            //mapWebComm.get(sC.ISIN_Code__c).Fund__c = sC.Fund__c;
        }
    }

    /**
    * update AlertType Lookup
    *
    * @param webCommToSendList
    */
    public static void updateLookupAlertType(List<Web_Communication__c> aWebCommToSendList) {

        Map<String, Id> alertTypeNameByIdMap = queryAlertTypeObj();

        //System.debug('Alert Type lookup ' + alertTypeNameByIdMap);

        if(!alertTypeNameByIdMap.isEmpty()){
            for(Web_Communication__c webCom : aWebCommToSendList){
                if( alertTypeNameByIdMap.containsKey(webCom.AlertType__c) ){
                    webCom.AlertTypeRecord__c = alertTypeNameByIdMap.get(webCom.AlertType__c);
                }
            }
        }


    }

    /**
    * update AlertType Lookup
    *
    * @param webCommToSendList
    */
    public static Map<String, Id> queryAlertTypeObj() {

        Map<String, Id> alertTypeNameByIdMap = new Map<String, Id>();

        for(AlertType__c theme : [SELECT Id, TECH_WebSiteID__c
        FROM AlertType__c
        WHERE TECH_WebSiteID__c != NULL LIMIT 50000]){

            alertTypeNameByIdMap.put(theme.TECH_WebSiteID__c, theme.Id);

        }


        return alertTypeNameByIdMap;

    }

    /**
     * Send list of web communication to Website
     * Either for :
     * - creation (when field isActive__c is true)
     * - deletion (when field isActive__c is false)
     * As Salesforce keep records of inactive subscriptions unlike the website
     */
    public static void sendWebCommuniction(List<Web_Communication__c> webCommToSendList) {
        List<Web_Communication__c> activeList = new List<Web_Communication__c>();
        List<Web_Communication__c> inactiveList = new List<Web_Communication__c>();
        
        for (Web_Communication__c webCom : webCommToSendList) {
            if (webCom.isActive__c) {
                activeList.add(webCom);
            }
            //the field TECH_CommunicationWebsiteId__c is checked because if it is empty, this means the alert does not exist on the website
            //so it does not need to be deleted on the website
            else if (!String.isEmpty(webCom.TECH_CommunicationWebsiteId__c)) {
                inactiveList.add(webCom);
            }
        }

        if (activeList.size() > 0) {
            processWebCommunication(activeList);
        }
        if (inactiveList.size() > 0) {
            deleteWebsiteWebComm(inactiveList);
        }
    }



    /**
    * Send list of web communication to Website
    *
    * @param webCommToSendList
    */
    public static void processWebCommunication(List<Web_Communication__c> webCommToSendList) {

        String websiteEndpoint = '', websiteMethod = '';

        //create WebCommunication in website
        websiteEndpoint = '/webservice/v2/subscriptions';
        websiteMethod = 'POST';

        //Build JSON WebCommunication body to send to website
        String webCommJson = generateWebCommJson(webCommToSendList);

        //Perform HTTP request and add JSON body; Update WebCommunication fields with website response
        connectAndSendWebComm(webCommJson, webCommToSendList, websiteEndpoint, websiteMethod);
    }

    /**
    *
    * Generate Web Communication in JSON format
    * @param webCommToSendList
    *
    * @return
    */
    private static String generateWebCommJson(List<Web_Communication__c> webCommunications) {

        //Query all related fields needed
        List<Web_Communication__c> webCommToSendList = [select Id,ShareClass__r.ISIN_Code__c, AlertTypeRecord__c,
                AlertTypeRecord__r.Name,  AlertTypeRecord__r.TECH_WebSiteID__c, TECHAlertTypeWebsiteId__c,
                TECH_WebsiteLeadContactTechId__c
        from Web_Communication__c where Id in :webCommunications];

        JSONGenerator gen = JSON.createGenerator(true);

        gen.writeStartObject();
        gen.writeFieldName('records');
        gen.writeStartArray();

        for (integer i = 0; i < webCommToSendList.size(); i++) {

            gen.writeStartObject();
            JSONGeneratorChecker.writeStringField(gen, 'ShareIsin', String.valueOf(webCommToSendList[i].ShareClass__r.ISIN_Code__c));
            JSONGeneratorChecker.writeStringField(gen, 'AlertType', webCommToSendList[i].TECHAlertTypeWebsiteId__c);
            if(String.isNotBlank(webCommToSendList[i].TECH_WebsiteLeadContactTechId__c)) JSONGeneratorChecker.writeStringField(gen, 'ContactId', webCommToSendList[i].TECH_WebsiteLeadContactTechId__c);
            JSONGeneratorChecker.writeStringField(gen, 'SalesForceId', webCommToSendList[i].Id);
            gen.writeEndObject();
        }

        gen.writeEndArray();
        gen.writeEndObject();

        String jsonS = gen.getAsString();

        System.debug('WebCommunication Dev -- - - - - -  ' + jsonS);
        return jsonS;

    }

    /**
    * Perform HTTP request and add JSON body; Update WebCommunication fields with website response
    *
    * @param webCommJson
    * @param webComToSent
    * @param aWebsiteEndpoint
    * @param aWebsiteMethod
    */
    public static void connectAndSendWebComm(String webCommJson, List<Web_Communication__c> aWebComToSentList, String aWebsiteEndpoint, String aWebsiteMethod) {

        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        Http http = new Http();
        req.setEndpoint('callout:CarmignacWebsite' + aWebsiteEndpoint);
        req.setMethod(aWebsiteMethod);
        req.setHeader('Content-Type', 'application/json');
        //req.setHeader('Content-Type', 'text/plain');
        req.setBody(webCommJson);

        try {
            if(!Test.isRunningTest()){
                res = http.send(req);
            }else{
                MCK012_WebsiteMockWS mockContactWS = new MCK012_WebsiteMockWS();
                res = mockContactWS.syncWebCommunication(req, aWebsiteMethod, 'success', aWebComToSentList[0]);

            }
            System.debug('res.getBody()!' +res.getBody());
            if (res.getStatusCode() == 200 || res.getStatusCode() == 400 ) {

                System.debug('Success!');
                if (aWebsiteMethod == 'DELETE') {
                    return;
                }

                if (res.getBody() != '' && res.getBody() != null) {

                    SM029_WebCommunicationResponseParser.parse(res.getBody());

                }
            }else{
                System.debug('Error!');
            }

        } catch (System.CalloutException e) {
            //Log interface
            System.debug('Callout error: ' + e);
            EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(res, req, '', 'SM029_WebCommunication', 'connectAndSendWebComm');
            listLogError.add(newErro);

        }

        if(listLogError.size() > 0){
            EM023_Log.insertLogError(listLogError);
        }


    }

    /**
    *
    *
    * @param webCommToSendList
    */
    public static void deleteWebsiteWebComm(List<Web_Communication__c> webCommToSendList) {

        JSONGenerator gen = JSON.createGenerator(true);

        gen.writeStartObject();
        gen.writeFieldName('records');
        gen.writeStartArray();

        for (integer i = 0; i < webCommToSendList.size(); i++) {

            gen.writeStartObject();
            JSONGeneratorChecker.writeStringField(gen, 'ShareIsin', String.valueOf(webCommToSendList[i].TECH_WebISINCode__c));
            JSONGeneratorChecker.writeStringField(gen, 'AlertType', webCommToSendList[i].TECHAlertTypeWebsiteId__c);
            JSONGeneratorChecker.writeStringField(gen, 'ContactId', webCommToSendList[i].TECH_WebsiteLeadContactTechId__c);
            JSONGeneratorChecker.writeStringField(gen, 'SalesForceId', webCommToSendList[i].Id);
            gen.writeEndObject();
        }

        gen.writeEndArray();
        gen.writeEndObject();

        String jsonS = gen.getAsString();

        //String jsonS = generateWebCommJson(webCommToSendList);
        //Delete WebCommunication endpoints
        String deleteWebCommEndpoint = '/webservice/v2/subscriptions/delete';
        String deleteWebCommMethod = 'DELETE';

        //call method to connect to website
        System.debug('JSON DELETE -- - - -' + jsonS);
        connectAndSendWebComm(jsonS, webCommToSendList, deleteWebCommEndpoint, deleteWebCommMethod);

    }

    public static void handleCountryError(List<Web_Communication__c> aWebComList, Map<Web_Communication__c, Id> aContactIdByWebComIdMap, Map<Web_Communication__c, Id> aLeadIdByWebComIdMap, Map<Web_Communication__c, Id> aShareClassIdByWebComIdMap){

        List<Share_Class__c> shareClassList = [SELECT Id, Country__c
        FROM Share_Class__c
        WHERE Id IN :aShareClassIdByWebComIdMap.values()];

        List<Contact>  contactList = [SELECT Id, WebsiteCountry__c
        FROM Contact
        WHERE Id IN :aContactIdByWebComIdMap.values()
        LIMIT 5000];

        List<Lead>  leadList = [SELECT Id, WebsiteCountry__c
        FROM Lead
        WHERE Id IN :aLeadIdByWebComIdMap.values()
        LIMIT 5000];

        Map<Id, String> shareClassIdByShareClassCountryMap = new Map<Id, String>();
        Map<Id, String> contactIdByContactWebCountryMap = new Map<Id, String>();
        Map<Id, String> LeadIdByLeadWebCountryMap = new Map<Id, String>();

        for(Share_Class__c sc : shareClassList){
            shareClassIdByShareClassCountryMap.put(sc.Id, sc.Country__c);
        }

        for(Contact c : contactList){
            contactIdByContactWebCountryMap.put(c.Id, c.WebsiteCountry__c);
        }

        for(Lead l : leadList){
            LeadIdByLeadWebCountryMap.put(l.Id, l.WebsiteCountry__c);
        }

        for(Web_Communication__c webCom : aWebComList){

            String shareClassCountries = shareClassIdByShareClassCountryMap.get(aShareClassIdByWebComIdMap.get(webCom));
            String websiteCountry;
            if(webCom.Contact__c != null){
                websiteCountry = contactIdByContactWebCountryMap.get(aContactIdByWebComIdMap.get(webCom));
            }else{
                websiteCountry = LeadIdByLeadWebCountryMap.get(aLeadIdByWebComIdMap.get(webCom));
            }

            if(shareClassCountries != null && !shareClassCountries.contains(websiteCountry)){
                webCom.addError(Label.Error_Country_Webcommunication);
            }
        }
    }


    /**
        * Retrieve all shares per country
        *
        * @param country
        *
        * @return
        */
    public static List<Share_Class__c> getAllSharesPerCountry(String country) {

        return [SELECT Id, Fund__c, Fund__r.Id, ISIN_Code__c FROM Share_Class__c WHERE Validity__c = true AND Country__c INCLUDES (:country)];
    }

    /**
     * Create All subscription per Alert Type
     *
     * @param aContactRecord
     */
    public static void addAllContactAlerts(Contact aContactRecord, List<String> selectedAlertTypes) {

        System.debug('//NGO selectedAlertTypes'+selectedAlertTypes);
        Map<Id, AlertType__c> themeNameByIdMap = getThemeDetails(selectedAlertTypes);
        List<Share_Class__c> shareClassList = getAllSharesPerCountry(aContactRecord.WebsiteCountry__c);

        //Create Web Communication for daily_nav
        List<Web_Communication__c> webComToCreateList = new List<Web_Communication__c>();

        for (String theme : selectedAlertTypes) {
            //if publications
            if (themeNameByIdMap.get(theme).isPublication__c) {
                Web_Communication__c webComm = new Web_Communication__c();
                webComm.Synchro_Status__c = 'Success';
                webComm.AlertTypeRecord__c = themeNameByIdMap.get(theme).Id;
                webComm.Contact__c = aContactRecord.Id;
                webComm.TECH_CommunicationWebsiteId__c = aContactRecord.TECH_WebSiteID__c + '_' + themeNameByIdMap.get(theme).TECH_WebSiteID__c;
                webComToCreateList.add(webComm);
            } else {
                for (Share_Class__c sc : shareClassList) {
                    Web_Communication__c webComm = new Web_Communication__c();
                    webComm.Synchro_Status__c = 'Success';
                    webComm.AlertTypeRecord__c = themeNameByIdMap.get(theme).Id;
                    webComm.Contact__c = aContactRecord.Id;
                    webComm.ShareClass__c = sc.Id;
                    webComm.Fund__c = sc.Fund__r.Id;
                    webComm.TECH_CommunicationWebsiteId__c = aContactRecord.TECH_WebSiteID__c + '_' + themeNameByIdMap.get(theme).TECH_WebSiteID__c + '_' + sc.ISIN_Code__c;
                    webComToCreateList.add(webComm);
                }
            }
        }
        System.debug('//NGO webComToCreateList'+webComToCreateList);
        if (webComToCreateList.size() > 0) insertAndSyncAlerts(webComToCreateList);

    }

    private static Map<Id, AlertType__c> getThemeDetails(List<String>themeList){

        Map<Id, AlertType__c> myMap = new Map<Id, AlertType__c>();
        for(AlertType__c theme : [SELECT Id, Name, isPublication__c, TECH_WebSiteID__c FROM AlertType__c WHERE Id IN :themeList]){
            myMap.put(theme.Id, theme);
        }
        return myMap;

    }

    /**
     * Add alerts on lead
     *
     * @param aLeadRecord
     * @param selectedAlertTypes
     */
    public static void addAllLeadAlerts(Lead aLeadRecord,  List<String> selectedAlertTypes) {

        System.debug('//NGO selectedAlertTypes'+selectedAlertTypes);

        List<Share_Class__c> shareClassList = getAllSharesPerCountry(aLeadRecord.WebsiteCountry__c);
        Map<Id, AlertType__c> themeNameByIdMap = getThemeDetails(selectedAlertTypes);

        //Create Web Communication for daily_nav
        List<Web_Communication__c> webComToCreateList = new List<Web_Communication__c>();

        for (String theme : selectedAlertTypes) {
            //if publications
            if (themeNameByIdMap.get(theme).isPublication__c) {
                Web_Communication__c webComm = new Web_Communication__c();
                webComm.Synchro_Status__c = 'Success';
                webComm.AlertTypeRecord__c = themeNameByIdMap.get(theme).Id;
                webComm.Lead__c = aLeadRecord.Id;
                webComm.TECH_CommunicationWebsiteId__c = aLeadRecord.TECH_WebSiteID__c + '_' + themeNameByIdMap.get(theme).Name;
                webComToCreateList.add(webComm);
            } else {
                for (Share_Class__c sc : shareClassList) {
                    Web_Communication__c webComm = new Web_Communication__c();
                    webComm.Synchro_Status__c = 'Success';
                    webComm.AlertTypeRecord__c = themeNameByIdMap.get(theme).Id;
                    webComm.Lead__c = aLeadRecord.Id;
                    webComm.ShareClass__c = sc.Id;
                    webComm.Fund__c = sc.Fund__r.Id;
                    webComm.TECH_CommunicationWebsiteId__c = aLeadRecord.TECH_WebSiteID__c + '_' + themeNameByIdMap.get(theme).Name + '_' + sc.ISIN_Code__c;
                    webComToCreateList.add(webComm);
                }
            }
        }
        System.debug('//NGO webComToCreateList'+webComToCreateList);
        if (webComToCreateList.size() > 0) insertAndSyncAlerts(webComToCreateList);

    }

    public static void insertAndSyncAlerts(List<Web_Communication__c> webComToCreateList){

        List<Web_Communication__c> recordsToSend = new List<Web_Communication__c>();
        Database.SaveResult[] srList = Database.insert(webComToCreateList, false);

        for (Database.SaveResult sr : srList) {
            if (sr.isSuccess()) {
                recordsToSend.add(new Web_Communication__c(Id = sr.getId()));
            }
        }
        System.enqueueJob(new SM029_SendSelectedWebCommAsync(recordsToSend, 0, 200));

    }

    public static void deleteAllProspaceAlerts(sObject aObjectRec, List<String> selectedAlertTypes){

        String sObjectType = ((SObject)aObjectRec).getSObjectType().getDescribe().getName();
        System.debug('dev---- aObjectRec' + aObjectRec);
        List<Web_Communication__c> webComToDeleteList;
        if(sObjectType == 'Contact'){
            webComToDeleteList = [SELECT Id, AlertTypeRecord__r.Id, AlertTypeRecord__r.TECH_WebSiteID__c FROM Web_Communication__c WHERE Contact__c = :aObjectRec.Id AND AlertTypeRecord__r.Id IN :selectedAlertTypes];
        }else{
            webComToDeleteList = [SELECT Id, AlertTypeRecord__r.Id, AlertTypeRecord__r.TECH_WebSiteID__c FROM Web_Communication__c WHERE Lead__c = :aObjectRec.Id AND AlertTypeRecord__r.Id IN :selectedAlertTypes];
        }

        if(webComToDeleteList.size() > 0){
            Database.delete(webComToDeleteList, false);
        }
    }

    public static void delAllContactAlerts(Set<Contact> aContactAlertsToDeleteList){
        Set<Id> techContactIdSet = new Set<Id>();
        for(Contact c : aContactAlertsToDeleteList){
            techContactIdSet.add(c.Id);
        }

        List<Web_Communication__c> webComToDeleteList = [SELECT Id, AlertTypeRecord__r.Id
        FROM Web_Communication__c
        WHERE Contact__c IN :techContactIdSet
        LIMIT 50000];

        if(webComToDeleteList.size() > 0){
            Database.delete(webComToDeleteList, false);
        }
    }


    public static void delAllLeadAlerts(Set<Lead> aLeadAlertsToDeleteSet){
        Set<Id> techLeadIdSet = new Set<Id>();
        for(Lead l : aLeadAlertsToDeleteSet){
            techLeadIdSet.add(l.Id);
        }

        List<Web_Communication__c> webComToDeleteList = [SELECT Id, AlertTypeRecord__r.Id
        FROM Web_Communication__c
        WHERE Lead__c IN :techLeadIdSet
        LIMIT 50000];

        if(webComToDeleteList.size() > 0){
            Database.delete(webComToDeleteList, false);
        }
    }

    public static void deleteEmptyWebCommunication() {
        String query = 'SELECT id FROM Web_Communication__c WHERE Contact__c = null AND Lead__c = null LIMIT 50000';
        List<Web_Communication__c> webComList = Database.query(query);
        if (webComList.size() > 0) {
            Database.delete(webComList, false);
        }
    }

    public static void deactivateAllWebCommunication(String objectName, Set<Id> records) {
        String query = 'SELECT id, isActive__c FROM Web_Communication__c WHERE isActive__c = true AND ' + objectName + '__c IN :records LIMIT 50000';
        List<Web_Communication__c> webComList = Database.query(query);
        for (Web_Communication__c webCom : webComList) {
            webCom.isActive__c = false;
        }
        if (webComList.size() > 0) {
            Database.update(webComList, false);
        }
    }

    public static void transferContactAlerts(Map<Id, Id> recordList) {
        List<Web_Communication__c> webComList = [SELECT id, Contact__c FROM Web_Communication__c WHERE Contact__c in :recordList.keySet() LIMIT 50000];
        for (Web_Communication__c webCom : webComList) {
            Id old = webCom.Contact__c;
            webCom.Contact__c = recordList.get(old);
        }
        update webComList;
    }

}