public class MetadataUtils implements Metadata.DeployCallback {
    
    public static Map<String, Decimal> getAgreementCounters() {
        Map<String, Decimal> counters = new Map<String, Decimal>();
        for (AgreementNameCounter__mdt counter : AgreementNameCounter__mdt.getAll().values()) {
            counters.put(counter.DeveloperName, counter.Counter__c);
            system.debug(counter.DeveloperName + ' ' + counter.counter__c);
        }
        return counters;
    }

    public static Map<String, String> getPrefCenterFundsFromProductAndCountries() {
        Map<String, String> preferenceCenterFund = new Map<String, String>();
        for (PreferenceCenterFund__mdt prefCenterCountry : [SELECT Product_Name__c,Countries__c, DeveloperName FROM PreferenceCenterFund__mdt]) {
            for (String country : prefCenterCountry.Countries__c.split(';')) {
                preferenceCenterFund.put(prefCenterCountry.Product_Name__c+'_'+country,prefCenterCountry.DeveloperName);
            }
        }
        System.debug('preferenceCenterFund => '+ preferenceCenterFund.keySet().size());

        return preferenceCenterFund;
    }
    

    public static Map<String, List<String>> getPreferenceCenterFundsCountries() {
        Map<String, List<String>> preferenceCenter = new Map<String, List<String>>();
        for (PreferenceCenterFund__mdt prefCenterCountry : [SELECT DeveloperName, Countries__c FROM PreferenceCenterFund__mdt]) {
            preferenceCenter.put(prefCenterCountry.DeveloperName, prefCenterCountry.Countries__c.split(';'));
        }
        return preferenceCenter;
    }
    
    @future
    public static void updateAgreementCounters(Map<String, Decimal> agreementCounters) {
        String metdataName = 'AgreementNameCounter__mdt';
        Map<String, Map<String, Object>> mapValues = new Map<String, Map<String, Object>>();
        Map<String, Decimal> countersMetadata = getAgreementCounters();
        
        for (String key : agreementCounters.keySet()) {
            if (agreementCounters.get(key) != countersMetadata.get(key)) {
                Map<String, Object> value = (Map<String, Object>)JSON.deserializeUntyped('{"counter__c": "' + agreementCounters.get(key) + '"}');
                mapValues.put(key, value);
            }
        }
        
        updateCustomMetadata(metdataName, mapValues);
    }
    
    public static void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
        if (result.status == Metadata.DeployStatus.Succeeded) {
            System.debug('	success : ' + result);
        }
        else {
            System.debug('	fail : ' + result);
        }
    }
    
    //Set record values
    private static Metadata.CustomMetadata setRecordMetata(String metdataName, String label, Map<String, Object> metadataFieldValueMap) {
        Metadata.CustomMetadata cMetadata = new Metadata.CustomMetadata();
        cMetadata.fullName = metdataName + '.' + label.deleteWhitespace();
        cMetadata.label = label;
         
        for(String key : metadataFieldValueMap.keySet()) {
            Metadata.CustomMetadataValue cMetadataValue = new Metadata.CustomMetadataValue();
            cMetadataValue.Field = key;
            cMetadataValue.Value = metadataFieldValueMap.get(key); 
            cMetadata.values.add(cMetadataValue);
        }
        
        return cMetadata;
    }
    
    //Update Custom Metadata record
    public static void updateCustomMetadata(String metdataName, Map<String, Map<String, Object>> metadataFieldValueMap){
        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
        
        for (String key : metadataFieldValueMap.keySet()) {
            Metadata.CustomMetadata cMetadata = setRecordMetata(metdataName, key, metadataFieldValueMap.get(key));
            mdContainer.addMetadata(cMetadata);
        }
     	        
        MetadataUtils callback = new MetadataUtils();
        Id jobId;
        if (!Test.isRunningTest()) {
        	jobId = Metadata.Operations.enqueueDeployment(mdContainer, callback);
        }
    }

    public static List<String> getPreferenceCenterCategory(String category) {
        List<String> preferenceCenterList = new List<String>();
        for (Preference_Center_Category__mdt prefCenterCategory : Preference_Center_Category__mdt.getAll().values()) {
            if (prefCenterCategory.Category__c == category || String.isBlank(category)) {
                String field = prefCenterCategory.DeveloperName + '__c';
                preferenceCenterList.add(field);
            }
        }
        return preferenceCenterList;
    }
}