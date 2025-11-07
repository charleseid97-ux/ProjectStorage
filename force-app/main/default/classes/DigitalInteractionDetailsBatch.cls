/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 12-08-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
public class DigitalInteractionDetailsBatch implements Database.Batchable<sObject>{
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator('SELECT Id, Name, URL__c, FundName__c FROM Digital_Interaction_Details__c');
    }
    
    public void execute(Database.BatchableContext BC, List<Digital_Interaction_Details__c> scope) {
        Set<String> productCodes = new Set<String>();
        Set<String> isinCodes = new Set<String>();
    	Map<String, Digital_Interaction_Details__c> isinToRecordMap = new Map<String, Digital_Interaction_Details__c>();
        Map<String, List<Digital_Interaction_Details__c>> codeToRecordsMap = new Map<String, List<Digital_Interaction_Details__c>>();
        List<Digital_Interaction_Details__c> recordsToUpdate = new List<Digital_Interaction_Details__c>();
        
        for (Digital_Interaction_Details__c record : scope) {
            if (String.isNotBlank(record.URL__c)) {
                if (record.URL__c.contains('WR_') || record.URL__c.contains('FLF_') || record.URL__c.contains('FLFPRO_')) {
                    String productCode = DigitalInteractionDetailsTriggerService.extractProductCode(record.URL__c);
                    if (String.isNotBlank(productCode)) {
                        Mandrill_Url_Mapping__mdt md = Mandrill_Url_Mapping__mdt.getInstance(productCode);
                        if(md!=null){
                            record.FundName__c = md.ProductName__c;
                            recordsToUpdate.add(record);
                        }else{
                            productCodes.add(productCode);
                            if (!codeToRecordsMap.containsKey(productCode)) {
                                codeToRecordsMap.put(productCode, new List<Digital_Interaction_Details__c>());
                            }
                            codeToRecordsMap.get(productCode).add(record);
                        }
                        
                    }
                }else {
                    String extractedName = DigitalInteractionDetailsTriggerService.extractNameFromUrl(record.URL__c);
                    if (String.isNotBlank(extractedName)) {
                        String isinCode = DigitalInteractionDetailsTriggerService.extractISINCode(extractedName);
                        if (String.isNotBlank(isinCode)) {
                            isinCodes.add(isinCode);
                            isinToRecordMap.put(isinCode, record);
                        } else {
                            if(extractedName.contains('?')){
                                String[] splitedString = extractedName.split('\\?');
                                record.FundName__c = String.join(splitedString[0].split('-'),' ');
                            } else {
                                record.FundName__c = String.join(extractedName.split('-'),' ');
                            }
                            recordsToUpdate.add(record);
                        }
                    }
                } 
            }
        }
        
        if (!isinCodes.isEmpty()) {
            Map<String, Share_Class__c> scMap = new Map<String, Share_Class__c>();
            for (Share_Class__c sc : [SELECT Id, ISIN_Code__c, Fund__r.Product_Name__c FROM Share_Class__c WHERE ISIN_Code__c IN :isinCodes]) {
                scMap.put(sc.ISIN_Code__c, sc);
            }

            for (String isin : isinToRecordMap.keySet()) {
                if (scMap.containsKey(isin)) {
                    Digital_Interaction_Details__c record = isinToRecordMap.get(isin);
                    record.FundName__c = scMap.get(isin).Fund__r.Product_Name__c;
                    recordsToUpdate.add(record);
                }
            }
        }
        
        if (!productCodes.isEmpty()) {
            Map<String, Product__c> productMap = new Map<String, Product__c>();
            System.debug('productCodes : ' + productCodes);
            for (Product__c prod : [SELECT Id, Name, Product_Name__c FROM Product__c WHERE Name IN :productCodes AND RecordType.DeveloperName = 'Fund']) {
                productMap.put(prod.Name, prod);
                System.debug('prod.Name : ' + prod.Name);
            }
            
            for (String code : codeToRecordsMap.keySet()) {
                if (productMap.containsKey(code)) {
                    for (Digital_Interaction_Details__c record : codeToRecordsMap.get(code)) {
                        record.FundName__c = productMap.get(code).Product_Name__c;
                        recordsToUpdate.add(record);
                    }
                }
            }
        }
        
        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
        }
    }
    
    public void finish(Database.BatchableContext BC) {
    }
}