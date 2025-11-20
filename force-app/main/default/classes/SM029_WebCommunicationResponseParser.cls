public class SM029_WebCommunicationResponseParser {
    
    private static String  CLASS_NAME = SM029_WebCommunicationResponseParser.class.getName();

    
    public class SuccessRecords {
        public String SalesForceId {get;set;} 
        public String ReferenceId {get;set;} 
        
        public SuccessRecords(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'SalesForceId') {
                            SalesForceId = parser.getText();
                        } else if (text == 'ReferenceId') {
                            ReferenceId = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'SuccessRecords consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public Integer error {get;set;} 
    public String message {get;set;} 
    public List<ErrorRecords> errorRecords {get;set;} 
    public List<SuccessRecords> successRecords {get;set;} 
    
    public SM029_WebCommunicationResponseParser(JSONParser parser) {
        
        String methodName = 'SM029_WebCommunicationResponseParser';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [parser] : ' + parser);
        
        while (parser.nextToken() != System.JSONToken.END_OBJECT) {
            if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                String text = parser.getText();
                if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                    if (text == 'error') {
                        error = parser.getIntegerValue();
                    } else if (text == 'message') {
                        message = parser.getText();
                    } else if (text == 'errorRecords') {
                        errorRecords = arrayOfErrorRecords(parser);
                    } else if (text == 'successRecords') {
                        successRecords = arrayOfSuccessRecords(parser);
                        
                    } else {
                        System.debug(LoggingLevel.WARN, 'SM029_WebCommunicationResponseParser consuming unrecognized property: '+text);
                        consumeObject(parser);
                    }
                }
            }
            
        }
        
        methodName = 'SM029_WebCommunicationResponseParser';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [successRecords] : ' + successRecords);
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [errorRecords] : ' + errorRecords);
        //updateWebCommunicationWebsiteResponse(successRecords, errorRecords);
        updateFromResponse(successRecords, errorRecords);
    }

    public static void updateFromResponse(List<SuccessRecords> successRecords, List<ErrorRecords> errorRecords) {
        // 1) Parse & normalise
        List<RefParts> sParts = parseSuccess(successRecords);
        List<ErrParts> eParts = parseErrors(errorRecords);

        // 2) Résolution CMDT en 1 requête
        Map<String,String> websiteIdByDevName = resolveWebsiteIds(sParts);

        // 3) Clés composites
        KeySets keys = buildKeys(sParts, eParts, websiteIdByDevName);

        // 4) Récupération candidats (2 SOQL max)
        WebComSets cands = fetchCandidates(keys);

        // 6) Construction des updates
        List<Web_Communication__c> updates = new List<Web_Communication__c>();
        updates.addAll(buildSuccessUpdates(sParts, websiteIdByDevName, cands));
        updates.addAll(buildErrorUpdates(eParts, cands));

        // 7) Persist 
        if (!updates.isEmpty()) update updates;
        
    }
    // ---- (1) Parse
    private static List<RefParts> parseSuccess(List<SuccessRecords> listSuccess) {
        List<RefParts> out = new List<RefParts>();
        for (SuccessRecords s : listSuccess) if (s != null && !String.isBlank(s.ReferenceId)) out.add(parseRefParts(s.ReferenceId));
        return out;
    }
    private static List<ErrParts> parseErrors(List<ErrorRecords> listErrors) {
        List<ErrParts> out = new List<ErrParts>();
        for (ErrorRecords e : listErrors) if (e != null) out.add(new ErrParts(e));
        return out;
    }

    // ----- (2) CMDT -----
    private static Map<String,String> resolveWebsiteIds(List<RefParts> sParts) {
        Set<String> devNames = new Set<String>();
        for (RefParts r : sParts) if (!r.isKeyNumeric && !String.isBlank(r.alertKey)) devNames.add(r.alertKey);
        Map<String,String> out = new Map<String,String>();
        if (devNames.isEmpty()) return out;
        for (ProspaceAlertType__mdt m :
            [SELECT DeveloperName, WebsiteId__c FROM ProspaceAlertType__mdt WHERE DeveloperName IN :devNames]) {
            out.put(m.DeveloperName, String.valueOf(m.WebsiteId__c));
        }
        return out;
    }

     // ----- (3) Clés -----
    private class KeySets { Set<String> withIsin = new Set<String>(); Set<String> noIsin = new Set<String>(); }
    private static KeySets buildKeys(List<RefParts> sParts, List<ErrParts> eParts, Map<String,String> mapDev) {
        KeySets keys = new KeySets();

        // ----- 1. Success records -----
        for (RefParts rp : sParts) {
            if (rp == null || String.isBlank(rp.contactId)) continue;

            // Résolution du WebsiteId : numérique → direct, sinon via CMDT
            String websiteId = rp.isKeyNumeric ? rp.alertKey : mapDev.get(rp.alertKey);
            if (String.isBlank(websiteId)) continue; // cas de devName inconnu

            // Clé composite selon présence d’un ISIN
            if (String.isNotBlank(rp.isin)) {
                keys.withIsin.add(key3(rp.contactId, websiteId, rp.isin));
            } else {
                keys.noIsin.add(key2(rp.contactId, websiteId));
            }
        }

        // ----- 2. Error records -----
        for (ErrParts ep : eParts) {
            if (ep == null || String.isBlank(ep.contactId) || String.isBlank(ep.alertType)) continue;

            // Pour les erreurs, AlertType est déjà un WebsiteId numérique
            if (String.isNotBlank(ep.isin)) {
                keys.withIsin.add(key3(ep.contactId, ep.alertType, ep.isin));
            } else {
                keys.noIsin.add(key2(ep.contactId, ep.alertType));
            }
        }

        return keys;
    }

    // ----- (4) Fetch candidats -----
    private class WebComSets {
        Map<String, Web_Communication__c> withIsin = new Map<String, Web_Communication__c>();
        Map<String, Web_Communication__c> noIsin   = new Map<String, Web_Communication__c>();
    }

    private static WebComSets fetchCandidates(KeySets keys) {
        WebComSets wcSets  = new WebComSets();
        if (!keys.withIsin.isEmpty()) {
            Set<String> kC = new Set<String>(), kW = new Set<String>(), kI = new Set<String>();
            for (String k : keys.withIsin) {
                List<String> p = k.split('\\|', 0);
                kC.add(p[0]); kW.add(p[1]); kI.add(p[2]);
            }
            for (Web_Communication__c wc : [SELECT Id, CreatedDate, TECH_WebsiteLeadContactTechId__c, AlertType__c, TECH_WebISINCode__c,
                                                    Synchro_Status__c, Website_Response__c, TECH_CommunicationWebsiteId__c, IsActive__c
                                            FROM Web_Communication__c
                                            WHERE TECH_WebsiteLeadContactTechId__c IN :kC
                                            AND AlertType__c IN :kW
                                            AND TECH_WebISINCode__c IN :kI]){
                                                String k = key3(wc.TECH_WebsiteLeadContactTechId__c, wc.AlertType__c, wc.TECH_WebISINCode__c);
                                                if (!keys.withIsin.contains(k)) continue;
                                                Web_Communication__c cur = wcSets.withIsin.get(k);
                                                if (cur == null || wc.CreatedDate > cur.CreatedDate) wcSets.withIsin.put(k, wc);
                                            }
            
        }
        if (!keys.noIsin.isEmpty()) {
            Set<String> kC = new Set<String>(), kW = new Set<String>();
            for (String k : keys.noIsin) {
                List<String> p = k.split('\\|', 0);
                kC.add(p[0]); kW.add(p[1]);
            }
            for (Web_Communication__c wc : [SELECT Id, CreatedDate, TECH_WebsiteLeadContactTechId__c, AlertType__c,
                                                    Synchro_Status__c, Website_Response__c, TECH_CommunicationWebsiteId__c, IsActive__c
                                            FROM Web_Communication__c
                                            WHERE TECH_WebsiteLeadContactTechId__c IN :kC
                                            AND AlertType__c IN :kW
            ]) {
                String k = key2(wc.TECH_WebsiteLeadContactTechId__c, wc.AlertType__c);
                if (!keys.noIsin.contains(k)) continue;
                Web_Communication__c cur = wcSets.noIsin.get(k);
                if (cur == null || wc.CreatedDate > cur.CreatedDate) wcSets.noIsin.put(k, wc);
            }
        }
        return wcSets;
    }

    

    // ----- (6) Updates -----
    private static List<Web_Communication__c> buildSuccessUpdates(List<RefParts> sParts, Map<String,String> mapDev, WebComSets latest) {
        List<Web_Communication__c> out = new List<Web_Communication__c>();
        for (RefParts r : sParts) {
            String websiteId = r.isKeyNumeric ? r.alertKey : mapDev.get(r.alertKey);
            if (String.isBlank(websiteId)) continue;
            Web_Communication__c rec = String.isNotBlank(r.isin)
                ? latest.withIsin.get(key3(r.contactId, websiteId, r.isin))
                : latest.noIsin.get(key2(r.contactId, websiteId));
            if (rec == null) continue;
            rec.Synchro_Status__c = 'Success';
            rec.TECH_CommunicationWebsiteId__c = r.referenceId; // tu stockes le ReferenceId
            rec.Website_Response__c = JSON.serialize(new Map<String,Object>{
                'successRecords' => new List<Object>{ new Map<String,Object>{
                    'SalesForceId' => null, 'ReferenceId' => r.referenceId
                }}
            });
            out.add(rec);
        }
        return out;
    }
    private static List<Web_Communication__c> buildErrorUpdates(List<ErrParts> eParts, WebComSets latest) {
        List<Web_Communication__c> out = new List<Web_Communication__c>();
        for (ErrParts e : eParts) {
            Web_Communication__c rec = String.isNotBlank(e.isin)
                ? latest.withIsin.get(key3(e.contactId, e.alertType, e.isin))
                : latest.noIsin.get(key2(e.contactId, e.alertType));
            if (rec == null) continue;
            rec.Synchro_Status__c   = 'Failed';
            rec.Website_Response__c = e.message;
            //rec.IsActive__c         = e.isActive; 
            out.add(rec);
        }
        return out;
    }

    
    /*public void updateWebCommunicationWebsiteResponse(List<SuccessRecords> aSuccessList, List<ErrorRecords> aErrorList){
        
                    String methodName = 'updateWebCommunicationWebsiteResponse';    
            ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [aSuccessList] : ' + aSuccessList);
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [aErrorList] : ' + aErrorList);
        List<Web_Communication__c> webCommToUpdateList = new List<Web_Communication__c>();
        Set<Id> webComToUpdateIdSet = new Set<Id>();
        
        Map<Id, SuccessRecords> successResponseByWebComIdMap = new Map<Id, SuccessRecords>();
        if(aSuccessList != null){
            for(SuccessRecords s : aSuccessList){
                successResponseByWebComIdMap.put(s.SalesForceId, s);
                webComToUpdateIdSet.add(s.SalesForceId);
            }  
        }
        
        
        Map<Id, ErrorRecords> errorResponseByWebComIdMap = new Map<Id, ErrorRecords>();
        if(aErrorList != null){
            
            for(ErrorRecords e : aErrorList){
                errorResponseByWebComIdMap.put(e.SalesForceId, e);
                webComToUpdateIdSet.add(e.SalesForceId);
            }
            
        }
        
        
        List<Web_Communication__c> webCommList = [SELECT Id, Synchro_Status__c, Website_Response__c, TECH_CommunicationWebsiteId__c, Contact__c, Contact__r.Id
                                                  FROM Web_Communication__c 
                                                  WHERE Id IN :webComToUpdateIdSet];
        
        for(Web_Communication__c webCom : webCommList){
            
            if(successResponseByWebComIdMap.containsKey(String.ValueOf(webCom.Id))){
                webCom.Synchro_Status__c = 'Success';
                webCom.Website_Response__c = '"successRecords":[{"SalesForce":"'+successResponseByWebComIdMap.get((String.ValueOf(webCom.Id))).SalesforceId+'","ReferenceId":"'+successResponseByWebComIdMap.get((String.ValueOf(webCom.Id))).ReferenceId+'"';
                webCom.TECH_CommunicationWebsiteId__c = successResponseByWebComIdMap.get((String.ValueOf(webCom.Id))).ReferenceId;
            }else{
                webCom.Synchro_Status__c = 'Failed';
                webCom.Website_Response__c = errorResponseByWebComIdMap.get((String.ValueOf(webCom.Id))).message;
            }
            
            webCommToUpdateList.add(webCom);
            
        }
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [webCommToUpdateList] : ' + webCommToUpdateList);
        //System.debug('DEV - -- - - WebCom before update ' + webCommToUpdateList[0].TECH_CommunicationWebsiteId__c + 'xx' + webCommToUpdateList[1].TECH_CommunicationWebsiteId__c+ 'xx'+ webCommToUpdateList[2].TECH_CommunicationWebsiteId__c+ 'xx' + webCommToUpdateList[3].TECH_CommunicationWebsiteId__c);
        Database.update(webCommToUpdateList, true);
        
    }*/
    
     public class ErrorData {
            public String ContactId   {get;set;}
            public String ShareIsin   {get;set;}
            public String AlertType   {get;set;}
            public Boolean IsActive   {get;set;}
        }

    public class ErrorRecords {

        public String message {get;set;}
        public ErrorData data {get;set;}

       
        
        public ErrorRecords(JSONParser parser) {
            String methodName = 'ErrorRecords';    
            ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [parser] : ' + parser);
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'message') {
                            message = parser.getText();
                        } else if (text == 'data' && parser.getCurrentToken() == System.JSONToken.START_OBJECT) {
                            data = new ErrorData();
                            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                                    String dn = parser.getText();
                                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                                        if (dn == 'ContactId') data.ContactId = parser.getText();
                                        else if (dn == 'ShareIsin') data.ShareIsin = parser.getText();
                                        else if (dn == 'AlertType') data.AlertType = parser.getText();
                                        else if (dn == 'IsActive') data.IsActive = parser.getBooleanValue();
                                        else consumeObject(parser);
                                    }
                                }
                            }
                        } else {
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    
    public static SM029_WebCommunicationResponseParser parse(String json) {
        String methodName = 'SM029_WebCommunicationResponseParser';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [json] : ' + json);
        
        System.JSONParser parser = System.JSON.createParser(json);
        return new SM029_WebCommunicationResponseParser(parser);
    }
    
    public static void consumeObject(System.JSONParser parser) {
        String methodName = 'consumeObject';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [arrayOfSuccessRecords] : ' + parser);
        Integer depth = 0;
        do {
            System.JSONToken curr = parser.getCurrentToken();
            if (curr == System.JSONToken.START_OBJECT || 
                curr == System.JSONToken.START_ARRAY) {
                    depth++;
                } else if (curr == System.JSONToken.END_OBJECT ||
                           curr == System.JSONToken.END_ARRAY) {
                               depth--;
                           }
        } while (depth > 0 && parser.nextToken() != null);
    }
    
    private static List<ErrorRecords> arrayOfErrorRecords(System.JSONParser p) {
        List<ErrorRecords> res = new List<ErrorRecords>();
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
            res.add(new ErrorRecords(p));
        }
        return res;
    }
    
    
    private static List<SuccessRecords> arrayOfSuccessRecords(System.JSONParser p) {
        
        String methodName = 'arrayOfSuccessRecords';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [arrayOfSuccessRecords] : ' + p);

        List<SuccessRecords> res = new List<SuccessRecords>();
        system.debug('p.getCurrentToken() : ' + p.getCurrentToken());
        
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
           
            res.add(new SuccessRecords(p));
            
        }
        return res;
    }

    // DANS LA CLASSE PRINCIPALE (pas dans RefParts)
    private static RefParts parseRefParts(String referenceId) {
        RefParts r = new RefParts();
        r.referenceId = referenceId;
        List<String> parts = referenceId.split('_');
        Integer size = parts.size();

        if (size == 3) {
            r.contactId = parts[0];
            r.alertKey  = parts[1];
            r.isin      = parts[2];
        } else if (size == 4) {
            r.contactId = parts[0];
            r.alertKey  = parts[1] + '_' + parts[2];
            r.isin      = parts[3];
        } else {
            r.contactId = parts[0];
            if (size > 1) r.alertKey = parts[1];
        }
        r.isKeyNumeric = (r.alertKey != null && Pattern.matches('^\\d+$', r.alertKey));
        return r;
    }

    
    private static String key3(String c, String w, String i) { return (c + '|' + w + '|' + i); }
    private static String key2(String c, String w)          { return (c + '|' + w); }

    private class RefParts {
        String referenceId, contactId, alertKey, isin;
        Boolean isKeyNumeric;
        
    }
    private class ErrParts {
        String message, contactId, alertType, isin;
        Boolean isActive;
        ErrParts(ErrorRecords e) {
            message   = e.message;
            contactId = e.data != null ? e.data.ContactId : null;
            alertType = e.data != null ? e.data.AlertType : null; // déjà l'ID
            isin      = e.data != null ? e.data.ShareIsin : null;
            isActive  = e.data != null ? e.data.IsActive : null;
        }
    }

    
}