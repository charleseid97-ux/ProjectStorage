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
        updateWebCommunicationWebsiteResponse(successRecords, errorRecords);
        
    }
    
    public void updateWebCommunicationWebsiteResponse(List<SuccessRecords> aSuccessList, List<ErrorRecords> aErrorList){
        
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
        
    }
    
    public class ErrorRecords {

        public String SalesForceId {get;set;} 
        public String message {get;set;} 
        
        public ErrorRecords(JSONParser parser) {
            String methodName = 'ErrorRecords';    
            ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [parser] : ' + parser);
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'SalesForceId') {
                            SalesForceId = parser.getText();
                        } else if (text == 'message') {
                            message = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'ErrorRecords consuming unrecognized property: '+text);
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
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
            res.add(new SuccessRecords(p));
        }
        return res;
    }
    
    
}