/**
* @author Abderrahmane TRIA
* @date Creation 01/12/2020
* @group Service
* @description Account Plan History
*/
global with sharing class HistoryAccountPlan { 
    
    @AuraEnabled(cacheable=true)
    public static List<AphWrapper> getHistoryAccountPlan(String apId) {
        List<AphWrapper> accWrapperList = new List<AphWrapper>();
        // Account Plan
        findHistory(accWrapperList, 'Account_Plan__c', apId);
        // Account Plan Objective
        findHistory(accWrapperList, 'Account_Plan_Objective__c', apId);
        // Strengths & Weaknesses
        findHistory(accWrapperList, 'Strengths_and_Weaknesses__c', apId);
        // Threat
        findHistory(accWrapperList, 'Threat__c', apId);

        accWrapperList.sort();
        return accWrapperList;
    }
    
    public static String getUserName(String uId) {
        User usr = [Select Name From User where Id = :uId ];
        return usr.Name;
    }
    
    public static List<AphWrapper> findHistory (List<AphWrapper> accWrapperList, String objectApiName, String key) {
        
        String objHistory = objectApiName.replace('__c', '__History');
        String soqlTemplate = '';
        Map<String, String> mIdsName = new Map<String, String>();
        List<SObject> records =  new List<SObject>();

        if (objectApiName != 'Account_Plan__c')
            soqlTemplate = 'SELECT Id, Name FROM {1} WHERE Account_Plan__c = \'\'{0}\'\'';
        else 
            soqlTemplate = 'SELECT Id, Name FROM {1} WHERE Id = \'\'{0}\'\'';
        

        String soql = String.format(soqlTemplate, new List<String> {key, objectApiName});
        System.debug('soql: ' + soql);
        records = Database.query(soql);
        for (SObject apo : records) {
            mIdsName.put(apo.Id, (String)apo.get('Name'));
        }
        if(mIdsName.size() > 0){
            List<SObject> recordsHistory =  new List<SObject>();
            Set<string> lstKeySet = mIdsName.keySet();
            
            String keySet = '';
            for(String s:lstKeySet) {
                keySet += (keySet == ''?'':',')+'\''+s+'\'';
            }
            
            soqlTemplate = 'SELECT Id, ParentId, CreatedDate, CreatedById, field, OldValue, NewValue FROM {1} WHERE ParentId IN ({0})';
            soql = String.format(soqlTemplate, new List<String> {keySet, objHistory});
            System.debug('soql: ' + soql);
            recordsHistory = Database.query(soql);
            
            for (SObject aph : recordsHistory) {
                AphWrapper aphWra = new AphWrapper();
                aphWra.objName = mIdsName.get((String)aph.get('ParentId'));
                aphWra.modifyBy = getUserName((String)aph.get('CreatedById'));
                aphWra.id = aph.Id;
                aphWra.newValue = String.valueof((String)aph.get('NewValue'));
                aphWra.oldValue = String.valueof((String)aph.get('OldValue'));
                aphWra.createdDate = string.valueOfGmt((Datetime)aph.get('CreatedDate'));
                String field = (String)aph.get('field');
                if (field.contains('__c')){
                    aphWra.field = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap().get(field).getDescribe().getLabel();
                } else {
                    aphWra.field = (String)aph.get('field');
                }
                accWrapperList.add(aphWra);
            } 
        }
        return accWrapperList;
    }

    // wrapper class
    global class AphWrapper implements Comparable {
        @AuraEnabled
        public String id {get;set;}
        @AuraEnabled
        public String objName {get;set;}
        @AuraEnabled
        public String oldValue {get;set;}
        @AuraEnabled
        public String field {get;set;}
        @AuraEnabled
        public String newValue {get;set;}
        @AuraEnabled
        public String createdDate {get;set;}
        @AuraEnabled
        public String modifyBy {get;set;}
        
        public Integer compareTo(Object compareTo) {
            AphWrapper jobsWrapper = (AphWrapper) compareTo;
            if (createdDate > jobsWrapper.createdDate) return 0;
            if (createdDate < jobsWrapper.createdDate) return 1;
            return -1;   
        }
    }
}