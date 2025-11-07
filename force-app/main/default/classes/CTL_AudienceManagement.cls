/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 08-02-2024
 * @last modified by  : Thanina YAYA
**/
public with sharing class CTL_AudienceManagement {
    
    @AuraEnabled(cacheable=true)
    public static String getCurrentProfile(String userId) {
        return [Select Id,Profile.Name from User where Id=:userId].Profile.Name ;
    }
    
    //Retrieves every contact based on the query passed in parameters
    @AuraEnabled
    public static List<Contact> getContacts(String request) {
        if (String.isBlank(request)) {
            request = 'SELECT id, FirstName, LastName, Account.Name, Email FROM Contact';
        }
        return Database.query(request);
    }
    
    //Retrieves every Active Strategy Product
    @AuraEnabled (cacheable=true)
    public static List<Strategy__c> getProducts(){
        return ([SELECT Id, Code__c, Name FROM Strategy__c  ORDER BY Code__c asc]);
    }

    /*public static List<Product__c> getProducts(){
        return ([SELECT Id, Name, Product_Name__c, RecordType.Name FROM Product__c WHERE RecordType.Name = 'Strategy' and Validity__c = true ORDER BY Name asc]);
    }*/

    //Retrieves every active campaign
    @AuraEnabled (cacheable=true)
    public static List<Campaign> getCampaigns(){
        return ([SELECT Id, Name, RecordType.Name FROM Campaign WHERE IsActive = true]);
    }

    //Retrieves every active users with the Profile 'Carmignac - Business Developer'
    @AuraEnabled (cacheable=true)
    public static List<User> getUsers(){
        return ([SELECT Id, Name FROM User WHERE Profile.Name = 'Carmignac - Business Developer' AND IsActive = true]);
    }

    //Retrieves every filters used in the audience management selection component
    @AuraEnabled (cacheable=true)
    public static List<Filter> getAllFilters(){
        try {
            List<Filter> filterList = getFilterList();
            filterList.addAll(getPrefCenterFilters());
            return filterList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    //Retrieves the preference center filters
    public static List<Filter> getPrefCenterFilters(){
        try {
            List<Preference_Center_Category__mdt> pccList = [SELECT Id, Label, DeveloperName, Category__c, Order__c, Childs__c FROM Preference_Center_Category__mdt ORDER BY category__c, order__c];
            List<Filter> filterList = new List<Filter>();
            for(Preference_Center_Category__mdt pcc : pccList) {
                Filter filter = new Filter();
                filter.fieldName = pcc.DeveloperName + '__c';
                filter.name = pcc.DeveloperName;
                filter.objectName = 'Contact';
                filter.section = pcc.Category__c;
                filter.label = pcc.Label;
                filter.isCheckbox = true;
                if(pcc.Childs__c != null && pcc.Childs__c != '') {
                    for (String child : pcc.Childs__c.split(';')) {
                        Filter cf = new Filter();
                        List<String> childInfos = child.split(':');
                        cf.fieldName = childInfos[0];
                        cf.label = childInfos[1];
                        cf.name = childInfos[0];
                        cf.objectName = 'Contact';
                        cf.section = pcc.Category__c;
                        cf.hasParent = true;
                        cf.parentName = pcc.DeveloperName;
                        cf.isCheckbox = true;
                        filterList.add(cf);
                    }
                    filter.hasChildren = true;
                }
                filterList.add(filter);
            }
            return filterList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    //Retrieves the audience management specific filters
    public static List<Filter> getFilterList(){
        try {
            List<AudienceManagementField__mdt> amfList = [SELECT Id, DeveloperName, Label, Object__c, FieldType__c, FieldName__c, Section__c, MaxNumber__c,IsMultiSelectLookup__c,IconName__c, Order__c FROM AudienceManagementField__mdt WHERE IsActive__c = true ORDER BY Order__c ASC];
            List<Filter> filterList = new List<Filter>();
            for(AudienceManagementField__mdt amf : amfList) {
                Filter filter = new Filter();
                filter.name = amf.DeveloperName;
                filter.objectName = amf.Object__c;
                filter.label = amf.Label;
                filter.type = amf.FieldType__c;
                filter.fieldName = amf.FieldName__c;
                filter.section = amf.Section__c;
                filter.isMultiLookup = amf.IsMultiSelectLookup__c;
                filter.pillsIcon = amf.IconName__c;
                filter.selectionSet = new List<String>();
                switch on amf.FieldType__c {
                    when 'Picklist' {
                        filter.picklistValues = getPicklistValues(amf.Object__c, amf.FieldName__c);
                        filter.isPicklist = true;
                    }
                    when 'Multipicklist' {
                        filter.picklistValues = getPicklistValues(amf.Object__c, amf.FieldName__c);
                        filter.isMultipicklist = true;
                    }
                    when 'Text' {
                        filter.isText = true;
                    }
                    when 'Checkbox' {
                        filter.isCheckbox = true;
                    }
                    when else {
                        
                    }
                }
                filterList.add(filter);
            }
            return filterList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    //Retrieves the label and value of a picklist stateCode : global standard picklist
    @AuraEnabled(cacheable=true)
    public static List<PicklistValue> getPicklistStateCode(){
        try {
            Map<String,PicklistValue> mapVals = new  Map<String,PicklistValue>();
            Schema.DescribeFieldResult fieldResult = Contact.MailingStateCode.getDescribe();
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
            for( Schema.PicklistEntry f : ple){
                if(f.isActive()) {
                    PicklistValue value = new PicklistValue();
                    value.value = f.getValue();
                    value.label = f.getLabel();
                    mapVals.put(f.getValue(),value);
                }
            }
            return mapVals.values();
        }catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    //Retrieves the label and value of a picklist field
    @AuraEnabled(cacheable=true)
    public static List<PicklistValue> getPicklistValues(String sObjectName, String fieldName){
        try {
            //List<PicklistValue> values = new List<PicklistValue>();
            Map<String,PicklistValue> mapVals = new  Map<String,PicklistValue>();
            List<Schema.DescribeSObjectResult> results = Schema.describeSObjects(new List<String>{sObjectName});
            for(Schema.DescribeSObjectResult res : results) {
                for(Schema.PicklistEntry entry : res.fields.getMap().get(fieldName).getDescribe().getPicklistValues()) {
                    if(entry.isActive()) {
                        PicklistValue value = new PicklistValue();
                        value.value = entry.getValue();
                        value.label = entry.getLabel();
                        mapVals.put(value.value,value);
                    }
                }
            }
            return mapVals.values();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    //Retrieves the Ids of the contacts linked to a meeting note linked to a product. The query passed in parameters must retrieve the Id of the meeting note from the Client Interest
    @AuraEnabled
    public static List<Id> getContactFromProductInterest(String request){
        List<Id> meetingNotesIds = new List<Id>();
        Set<Id> contactIds = new Set<Id>();       
        for(ClientInterest__c  ci : Database.query(request)) {
            meetingNotesIds.add(ci.MeetingNote__c);
        }
        for(EventRelation er : [SELECT Id, RelationId FROM EventRelation 
                            WHERE Event.Meeting_Note__c IN: meetingNotesIds AND IsInvitee = false AND IsParent = true AND IsWhat= false]) {
            contactIds.add(er.RelationId);
        }
        if(contactIds.isEmpty()) {
            throw new AuraHandledException('No contacts were found for these product interest filters.');
        }
        return new List<Id>(contactIds);
    }

    //Retrieves a list of company Ids that invested in a product
    @AuraEnabled
    public static List<Id> getCompanyFromProductInterest(String productId){
        Set<Id> companyIds = new Set<Id>();
        for(AUM__c aum : [SELECT Id, Company__c FROM AUM__c WHERE ShareClass__r.Fund__r.FundStrategy__c =: productId]) {
            companyIds.add(aum.Company__c);
        }
        if(companyIds.isEmpty()) {
            throw new AuraHandledException('No company were found investing for this product');
        }
        return new List<Id>(companyIds);
    }

    //Creates new campaign members based on a list of contact Ids for a campaign
    @AuraEnabled
    public static String addToCampaign(Id campaignId, List<Id> contactIds){
        //If there is less than 200 contact, we do it synchronously
        //If there is more, we do it asynchronously via a queueable job
        Savepoint sp = Database.setSavepoint();
        if(contactIds.size() <= 200) {
            try {
                List<CampaignMember> members = new List<CampaignMember>();
                for(Id id : contactIds) {
                    members.add(new CampaignMember(CampaignId=campaignId, ContactId=id));
                }
                Database.SaveResult[] saveResults = Database.insert(members, false);
                // Check for failed inserts
                for (Integer i = 0; i < saveResults.size(); i++) {
                    if (!saveResults[i].isSuccess()) {
                         if ( saveResults[i].getErrors()[0].getStatusCode() != StatusCode.DUPLICATE_VALUE ) {
                            System.debug('Error inserting CampaignMember for ContactId rollback ' + saveResults[i].getErrors()[0].getMessage());
                            Database.rollback(sp);
                            AuraHandledException e = new AuraHandledException(saveResults[i].getErrors()[0].getMessage());
                            e.setMessage(saveResults[i].getErrors()[0].getMessage());
                            throw e;

                        }
                    }
                }
                return [SELECT Name FROM Campaign WHERE Id =: campaignId].Name;

            } catch (Exception e) {
                System.debug('Error: '+e.getMessage());
                Database.rollback(sp);
                throw new AuraHandledException(e.getMessage());
            }
        } else {
            
            BATCH_AudienceManagement batchJob = new BATCH_AudienceManagement(campaignId, contactIds,DateTime.now());
            Id jobId = Database.executeBatch(batchJob, 200); // 200 is the size of each batch, adjust as needed
            System.debug(jobId);
            return ('ENQUEUED');
        }
    }

    public class PicklistValue {
        @auraEnabled public String value;
        @auraEnabled public String label;
    }

    public class Filter {
        @auraEnabled public String name;
        @auraEnabled public String label;
        @auraEnabled public String section;
        @auraEnabled public String type;
        @auraEnabled public String objectName;
        @auraEnabled public String fieldName;
        @auraEnabled public Integer maxNumber;
        @auraEnabled public List<PicklistValue> picklistValues;
        @auraEnabled public Boolean isPicklist = false;
        @auraEnabled public Boolean isMultipicklist = false;
        @auraEnabled public Boolean isText = false;
        @auraEnabled public Boolean isCheckbox = false;
        @auraEnabled public Boolean isDate = false;
        @auraEnabled public Boolean isNumber = false;
        @auraEnabled public Boolean hasChildren = false;
        @auraEnabled public Boolean hasParent = false;
        @auraEnabled public String parentName;
        @auraEnabled public Boolean isMultiLookup = false; //used to flag picklist fields that we need to display as lookupFilter
        @auraEnabled public List<String> selectionSet;
        @auraEnabled public String pillsIcon='';
        
    }
}