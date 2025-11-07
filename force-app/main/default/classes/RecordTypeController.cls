/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 07-15-2024
 * @last modified by  : SILA Nicolas
**/
public with sharing class RecordTypeController {
    @AuraEnabled(cacheable=true)
    public static List<RecordTypeWrapper> getRecordTypes() {
        List<RecordTypeWrapper> recordTypes = new List<RecordTypeWrapper>();
        
        for(RecordType rt : [SELECT Id, Name, Description, DeveloperName 
                             FROM RecordType 
                             WHERE SObjectType = 'Case' 
                             AND IsActive = true AND Name != 'Master' AND DeveloperName !='Sub_Publication_Request' AND DeveloperName !='Sub_Translation_Request']) {
            if(rt.DeveloperName == 'TranslationRequest'){
                recordTypes.add(new RecordTypeWrapper(rt.Id, rt.Name, rt.Description, '/lightning/n/TranslationRequests'));
            }else if(rt.DeveloperName == 'Content_Feedback'){
                recordTypes.add(new RecordTypeWrapper(rt.Id, rt.Name, rt.Description, '/lightning/n/Content_Feedback'));
            } else {
                recordTypes.add(new RecordTypeWrapper(rt.Id, rt.Name, rt.Description, '/lightning/o/Case/new?backgroundContext=lightning/o/Case/list?filterName=__Recent&recordTypeId='+rt.Id));
            }   
        }
        
        return recordTypes;
    }
    
    public class RecordTypeWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public String url;
        
        public RecordTypeWrapper(String id, String name, String description, String url) {
            this.id = id;
            this.name = name;
            this.description = description;
            this.url = url;
        }
    }
}