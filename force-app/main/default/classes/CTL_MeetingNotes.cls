/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 02-11-2023
 * @last modified by  : Thanina YAYA
**/
public without sharing class CTL_MeetingNotes {
    
    
    @AuraEnabled(cacheable=true)
    public static String getOrgId(){
        return (UserInfo.getOrganizationId());
    }
    /**
        Use to get Internal contact , all contacts related to "Carmignac" Company
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> getNeededContacts(){
        return ([select Id,Name,Account.Name, Email from Contact where  ContactStatus__c = 'true' and Account.Name = 'CARMIGNAC' order by Name asc]);    
    }
     /**
        Use to get Internal contact , all contacts related to "Carmignac" Company
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> getClientContacts(String searchKey,List<String> selectedIds){
        String filter = '%'+searchKey+'%';
        return ([select Id,Name,Account.Name, Email from Contact where  Name like :filter and ContactStatus__c = 'true' and RecordType.Name = 'Distribution Contact' and Account.Name != 'CARMIGNAC' and (Id NOT IN :selectedIds) order by Name asc limit 10]);    
    }
    @AuraEnabled(cacheable=true)
    public static List<User> getUsers(){
        return ([select Id,Name,Email from User where IsActive = true order by Name asc]);
    }
    @AuraEnabled(cacheable=true)
    public static List<Product__c> getProducts(String statFilter){
        return ([select Id,Name, Product_Name__c, RecordType.Name from Product__c where RecordType.Name = 'Strategy' and Validity__c = true order by Product_Name__c asc]);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunities(String statFilter){
        return ([SELECT Id,Name FROM Opportunity ORDER BY Name ASC]);
    }

    @AuraEnabled
    public static CreationWrapper createRelatedObjects(Event evt, List<String> participants, List<ClientInterest__c> prodInterest,List<Task> tasks){
        Savepoint sp = Database.setSavepoint(); // rollback in case of error
        Boolean success = false;
        try {
            List<EventRelation> evtRelation = new List<EventRelation>();
            insert evt;
            //add Client contact and Internal as Who Ids on the event.
            for(String cont:participants){
                evtRelation.add(new EventRelation(EventId = evt.Id,
                                                 IsInvitee = false,
                                                 IsWhat = false,
                                                 IsParent=true,
                                                 RelationId = cont));
            }

            //add Client Interest Object  and tasks .....
            if(tasks.size() > 0) insert tasks;
            if(evtRelation.size() > 0) insert evtRelation;
            if(prodInterest.size() > 0) insert prodInterest;

            success = true;

        } catch (Exception e) {
            Database.rollback(sp);
            delete (new Meeting_Note__c(Id = evt.Meeting_Note__c)); //we delete the created meeting note created when we got an error for related objects. 
            System.debug('####CTL_MeetingNotes:createRelatedObjects => '+e.getMessage());
        }
        CreationWrapper response = new CreationWrapper(tasks,success);
        return response;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String,String> getEmailTemplate(String name){
         EmailTemplate et = [SELECT Id,HtmlValue,Subject, EnhancedLetterheadId FROM EmailTemplate WHERE Name = :name LIMIT 1];
         return (new Map<String,String>{'Id' => et.Id,'HtmlValue' => et.HtmlValue,'Subject' => et.Subject, 'EnhancedLetterheadId' => et.EnhancedLetterheadId});
    }

    @AuraEnabled
    public static Boolean sendEmailMeeting(EmailTemplate et, List<Contact> participants,String meetingNoteId) {
        Boolean succes = false;
        try {
            Meeting_Note__c note = [SELECT Owner.Email,Owner.Name FROM Meeting_Note__c WHERE Id = : meetingNoteId];

            //Need to create a new template with the updated content, 
            //in order to have the merged fields updated correctly
            EmailTemplate tmpMeeting = new EmailTemplate(Name = ('TMPEmail'+UserInfo.getUserId()+String.valueof(DateTime.now().getTime())).left(79),DeveloperName='TMPEmailMeeting'+UserInfo.getUserId(), HtmlValue=et.HtmlValue ,Subject=et.Subject,TemplateStyle='none',
                                                        IsActive = true,EnhancedLetterheadId = et.EnhancedLetterheadId,RelatedEntityType = 'Meeting_Note__c',UiType='SFX',Encoding='ISO-8859-1',TemplateType = 'custom');
            insert tmpMeeting;

            List<Messaging.SingleEmailMessage> allmsg = new List<Messaging.SingleEmailMessage>();
            for(Contact con : participants){
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTemplateId(tmpMeeting.Id);
                mail.setTargetObjectId(con.Id);
                mail.setReplyTo(note.Owner.Email);
                mail.setSenderDisplayName(note.Owner.Name);
                mail.setWhatId(meetingNoteId);
                allmsg.add(mail);
            }
            if(allmsg.size() > 0){
                    Messaging.sendEmail(allmsg,false);
            }
            delete tmpMeeting;
            succes = true;
        } catch (Exception e) {
            System.debug('####CTL_MeetingNotes:sendEmailMeeting => '+e.getMessage());
        }
        return succes;
    }

    private class CreationWrapper {
        @AuraEnabled public List<sObject> objectList;
        @AuraEnabled public Boolean success;
        public CreationWrapper(List<sObject> objectList , Boolean success){
            this.objectList = objectList;
            this.success = success;
        }
    }
}