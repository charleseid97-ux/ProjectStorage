global with sharing class StrategicNewsController {
    
    @AuraEnabled
    public static StrategicNews__c insertStrategicNews(StrategicNews__c sn){ 
        try{ 
            if ( sn.StrategicNews__c != null )
                sn.StrategicNews__c = sn.StrategicNews__c.stripHtmlTags();
            insert sn;
            return sn; 
        } catch (Exception exp) {
            throw new AuraHandledException(exp.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<snDataTableWrapper> getStrategicNewsList( String accId) {    

        List<snDataTableWrapper> response = new List<snDataTableWrapper>();
        for(StrategicNews__c sn : [SELECT Id, Name, Type__c, Subtype__c, Title__c, CreatedDate FROM StrategicNews__c WHERE Company__c =: accId]){
            snDataTableWrapper wrapper = new snDataTableWrapper();
            wrapper.snId = sn.Id;
            wrapper.name = sn.Name;
            wrapper.nameUrl = '/'+sn.Id;
            wrapper.type = sn.Type__c;
            wrapper.subType = sn.Subtype__c;
            wrapper.createdDate = sn.CreatedDate.format('yyyy-MM-dd\' \'HH:mm:ss');
            wrapper.title = sn.Title__c;
            response.add(wrapper);
        }
        response.sort();
        return response;
    }

    global class snDataTableWrapper implements Comparable {
        @AuraEnabled
        public Id snId {get;set;}
        @AuraEnabled
        public String name {get;set;}
        @AuraEnabled
        public String nameUrl {get;set;}
        @AuraEnabled
        public String type {get;set;}
        @AuraEnabled
        public String subType {get;set;}
        @AuraEnabled
        public String title {get;set;}
        @AuraEnabled
        public String createdDate {get;set;}

        public Integer compareTo(Object compareTo) {
            snDataTableWrapper jobsWrapper = (snDataTableWrapper) compareTo;
            if (createdDate > jobsWrapper.createdDate) return 0;
            if (createdDate < jobsWrapper.createdDate) return 1;
            return -1;   
        }
    }
}