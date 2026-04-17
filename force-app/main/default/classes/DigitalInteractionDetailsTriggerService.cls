/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 08-08-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
public  class DigitalInteractionDetailsTriggerService {
 
    public static final List<String> PREFIXES = new List<String>{
        '/fonds/', '/funds/', '/fondsangebot/', '/fondos/', '/fondi/', '/fondsen/',
        '/nos-fonds-notre-gestion/', '/our-funds/', '/nuestros-fondos/', '/unsere-fonds/', '/i-nostri-fondi/'
    };

    public static void extractFundName(List<Digital_Interaction_Details__c> newRecords, Map<Id, Digital_Interaction_Details__c> oldRecordsMap) {
        Set<String> isinCodes = new Set<String>();
        Set<String> productCodes = new Set<String>();
        Map<String, List<Digital_Interaction_Details__c>> isinToRecordsMap = new Map<String, List<Digital_Interaction_Details__c>>();
        Map<String, List<Digital_Interaction_Details__c>> codeToRecordsMap = new Map<String, List<Digital_Interaction_Details__c>>();
    
        if (oldRecordsMap == null) {
            processRecords(newRecords, null, isinCodes, productCodes, isinToRecordsMap, codeToRecordsMap);
        } else {
            processRecords(newRecords, oldRecordsMap, isinCodes, productCodes, isinToRecordsMap, codeToRecordsMap);
        }
    
        Map<String, Share_Class__c> scMap = new Map<String, Share_Class__c>();
        for (Share_Class__c sc : [SELECT Id, ISIN_Code__c, Fund__r.Product_Name__c FROM Share_Class__c WHERE ISIN_Code__c IN :isinCodes]) {
            scMap.put(sc.ISIN_Code__c, sc);
        }
    
        Map<String, Product__c> productMap = new Map<String, Product__c>();
        for (Product__c prod : [SELECT Id, Name,Product_Name__c FROM Product__c WHERE Name IN :productCodes AND RecordType.DeveloperName = 'Fund']) {
            productMap.put(prod.Name, prod);
        }
    
        for (String isin : isinToRecordsMap.keySet()) {
            if (scMap.containsKey(isin)) {
                for (Digital_Interaction_Details__c record : isinToRecordsMap.get(isin)) {
                    record.FundName__c = scMap.get(isin).Fund__r.Product_Name__c;
                }
            }
        }
    
        for (String code : codeToRecordsMap.keySet()) {
            if (productMap.containsKey(code)) {
                for (Digital_Interaction_Details__c record : codeToRecordsMap.get(code)) {
                    record.FundName__c = productMap.get(code).Product_Name__c;
                }
            }
        }
    }
    
    private static void processRecords(List<Digital_Interaction_Details__c> records, Map<Id, Digital_Interaction_Details__c> oldRecordsMap, 
                                       Set<String> isinCodes, Set<String> productCodes, 
                                       Map<String, List<Digital_Interaction_Details__c>> isinToRecordsMap, 
                                       Map<String, List<Digital_Interaction_Details__c>> codeToRecordsMap) {
        for (Digital_Interaction_Details__c newRec : records) {
            if (String.isNotBlank(newRec.URL__c) && (oldRecordsMap == null || newRec.URL__c != oldRecordsMap.get(newRec.Id).URL__c)) {
                if (newRec.URL__c.contains('WR_') || newRec.URL__c.contains('FLF_') || newRec.URL__c.contains('FLFPRO_')) {
                    String productCode = extractProductCode(newRec.URL__c);
                    if (String.isNotBlank(productCode)) {
                        Mandrill_Url_Mapping__mdt md = Mandrill_Url_Mapping__mdt.getInstance(productCode);
                        if(md!=null){
                            newRec.FundName__c = md.ProductName__c;
                        }else{
                            productCodes.add(productCode);
                            if (!codeToRecordsMap.containsKey(productCode)) {
                                codeToRecordsMap.put(productCode, new List<Digital_Interaction_Details__c>());
                            }
                            codeToRecordsMap.get(productCode).add(newRec);
                        }
                    }
                } else {
                    String extractedName = extractNameFromUrl(newRec.URL__c);
                    if (String.isNotBlank(extractedName)) {
                        String isinCode = extractISINCode(extractedName);
                        if (String.isNotBlank(isinCode)) {
                            isinCodes.add(isinCode);
                            if (!isinToRecordsMap.containsKey(isinCode)) {
                                isinToRecordsMap.put(isinCode, new List<Digital_Interaction_Details__c>());
                            }
                            isinToRecordsMap.get(isinCode).add(newRec);
                        } else {
                            if(extractedName.contains('?')){
                                String[] splitedString = extractedName.split('\\?');
                                newRec.FundName__c = String.join(splitedString[0].split('-'),' ');
                            } else {
                                newRec.FundName__c = String.join(extractedName.split('-'),' ');
                            }
                        }
                    }
                }
            } else if (oldRecordsMap != null && String.isBlank(newRec.URL__c) && newRec.URL__c != oldRecordsMap.get(newRec.Id).URL__c) {
                newRec.FundName__c = '';
            }
        }
    }

    public static String extractNameFromUrl(String url) {
        String lowercaseUrl = url.toLowerCase();
        for (String prefix : PREFIXES) {
            Integer startIndex = lowercaseUrl.indexOf(prefix);
            if (startIndex != -1) {
                startIndex += prefix.length();
                String remainingPath = lowercaseUrl.substring(startIndex);
                List<String> pathParts = remainingPath.split('/');
                if (pathParts.size() > 0) {
                    String possibleName = pathParts[0];
                    return url.substring(startIndex, startIndex + possibleName.length());
                }
            }
        }
        return null;
    }
    
    public static String extractISINCode(String fundName) {
        Pattern p = Pattern.compile('(LU|FR)[A-Z0-9]{10}');
        Matcher m = p.matcher(fundName);
        if (m.find()) {
            return m.group();
        }
        return null;
    }

    public static String extractProductCode(String url) {
        Pattern p = Pattern.compile('(WR|FLF|FLFPRO)_([A-Z0-9]+)_');
        Matcher m = p.matcher(url);
        if (m.find()) {
            return m.group(2);
        }
        return null;
    }
    
}