/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 14-11-2023
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
        return ([select Id,Name,Account.Name, Email, User__c from Contact where  ContactStatus__c = 'true' and Account.Name = 'CARMIGNAC' order by Name asc]);    
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
    //New Method for Strategy Relationship
    @AuraEnabled(cacheable=true)
    public static List<Strategy__c> getProducts(String statFilter){
        return ([select Id,Code__c, Name from Strategy__c ORDER BY Code__c asc]);
    }
    /*
    public static List<Product__c> getProducts(String statFilter){
        return ([select Id,Name, Product_Name__c, RecordType.Name from Product__c where RecordType.Name = 'Strategy' and Validity__c = true order by Name asc]);
    }*/
    
    /**
     * Get all opportunities.
     */
    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunities(){
        return ([select Id , Name, Account.Name from Opportunity ]);
    }
    /**
     * Get all open opportunities.
     */
    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpenOpportunities(){
        return ([select Id , Name, Account.Name from Opportunity WHERE IsClosed=false]);
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

     // Apex Method
     @AuraEnabled(cacheable=true)
     public static VideoCallDataWrapper getVideoCallData(Id videoCallId) {
         VideoCall vc = [
             SELECT 
                 Name, 
                 EndDateTime, 
                 Description, 
                 IntelligenceScore, 
                 (SELECT Summary FROM Summaries LIMIT 1),
                 (SELECT RelatedPersonId,RelatedPerson.Name, RelatedPerson.Email FROM VideoCalls) 
             FROM VideoCall 
             WHERE Id = :videoCallId
         ];
         system.debug('vc=>'+vc);
         VideoCallDataWrapper wrapper = new VideoCallDataWrapper();
         wrapper.Name = vc.Name;
         wrapper.EndDateTime = vc.EndDateTime != null ? vc.EndDateTime.format() : null;
         wrapper.Description = vc.Description;
         wrapper.Summary = vc.Summaries.size() > 0 ? vc.Summaries[0].Summary : null;
         List<ProductFeedback> productsAndRatings = parseFeedback(getProductsAndRatings(wrapper.Summary));
         List<Contact> contactIds = new List<Contact>();
         for (VideoCallParticipant participant : vc.VideoCalls) {
             if (participant.RelatedPersonId?.getSObjectType() == Contact.SObjectType) {
                 Contact part = [Select Id,Name, Email, Account.Name from Contact where Id =: participant.RelatedPersonId];
                 contactIds.add(part);
             }
         }
         wrapper.ClientInterest = new List<ClientInterest__c>();
         for (ProductFeedback prodRating : productsAndRatings) {
             system.debug('prodRating=>'+prodRating);
 
             ClientInterest__c cli = new ClientInterest__c(Product__c =prodRating.productId , Interest__c = prodRating.rating );
             wrapper.ClientInterest.add(cli);
         }
         wrapper.ContactIds = contactIds;
         system.debug('wrapper=>'+wrapper);
 
         return wrapper;
     }
     
    // Apex Method
    @AuraEnabled(cacheable=true)
    public static void createMeetingNoteFromVideoCall(Id videoCallId) {
        VideoCall vc = [
            SELECT 
                Name, 
                EndDateTime, 
                StartDateTime,
                Description, 
                IntelligenceScore, 
                (SELECT Summary FROM Summaries LIMIT 1),
                (SELECT RelatedPersonId,RelatedPerson.Name, RelatedPerson.Email FROM VideoCalls WHERE RelatedPersonId IN (SELECT id FROM Contact)) 
            FROM VideoCall 
            WHERE Id = :videoCallId
        ];
        system.debug('vc=>'+vc);
        Meeting_Note__c meetingNote = new Meeting_Note__c();

        meetingNote.Name = vc.Name;
        meetingNote.Date__c = vc.EndDateTime != null ? vc.EndDateTime.date() : null;
        meetingNote.Note__c  = vc.Summaries.size() > 0 ? vc.Summaries[0].Summary : null;

        insert meetingNote;
        system.debug('meetingNote=>'+meetingNote);

        List<ProductFeedback> productsAndRatings = parseFeedback(getProductsAndRatings(meetingNote.Note__c));
        
        List<Contact> contactIds = new List<Contact>();
        List<EventRelation> evtRelation = new List<EventRelation>();

        Event evt = new Event(
            StartDateTime=  vc.StartDateTime != null ? vc.StartDateTime : null,
            EndDateTime=  vc.EndDateTime != null ? vc.EndDateTime : null,
            Subject= vc.Name,
            Meeting_Note__c= meetingNote.id,
            WhoId= vc.VideoCalls[0].RelatedPersonId
        );
        system.debug('evt=>'+evt);

        insert evt;
        system.debug('evt=>'+evt);

        //add Client contact and Internal as Who Ids on the event.

        for(SObject cont : vc.VideoCalls){
            system.debug('cont=>'+cont);

            evtRelation.add(new EventRelation(EventId = evt.Id,
                                             IsInvitee = false,
                                             IsWhat = false,
                                             IsParent=true,
                                             RelationId = (String)cont.get('RelatedPersonId')));
        }

        // insert evtRelation;
        system.debug('evtRelation=>'+evtRelation);

        List<ClientInterest__c> clis = new List<ClientInterest__c>();

        for (ProductFeedback prodRating : productsAndRatings) {
            ClientInterest__c cli = new ClientInterest__c(Product__c = prodRating.productId , Interest__c = prodRating.rating, MeetingNote__c = meetingNote.id );
            clis.add(cli);
        }

        insert clis;
        system.debug('clis=>'+clis);

        // wrapper.ContactIds = contactIds;

    }
    @InvocableMethod(label='Create Meeting Notes From VideoCalls' description='Create Meeting Notes From VideoCalls.' category='Meeting Notes')
    public static void createMeetingNotesFromVideoCalls(List<Id> videoCallIds) {
        // Query all VideoCall records in bulk
        List<VideoCall> videoCalls = [
            SELECT 
                Name, 
                EndDateTime, 
                StartDateTime, 
                Description, 
                IntelligenceScore, 
                (SELECT Summary FROM Summaries Order by CreatedDate DESC LIMIT 1),
                (SELECT RelatedPersonId, RelatedPerson.Name, RelatedPerson.Email FROM VideoCalls WHERE RelatedPersonId IN (SELECT Id FROM Contact))
            FROM VideoCall 
            WHERE Id IN :videoCallIds
        ];

        // Initialize lists for bulk DML
        List<Meeting_Note__c> meetingNotes = new List<Meeting_Note__c>();
        Map<Id,Meeting_Note__c> meetingNotesMap = new Map<Id,Meeting_Note__c>();
        List<Event> events = new List<Event>();
        Map<Id,Event> eventsMap = new Map<Id,Event>();
        List<EventRelation> eventRelations = new List<EventRelation>();
        Map<Id,List<EventRelation>> eventRelationsMap = new Map<Id,List<EventRelation>>();
        List<ClientInterest__c> clientInterests = new List<ClientInterest__c>();
        Map<Id,List<ClientInterest__c>> clientInterestsMap = new Map<Id,List<ClientInterest__c>>();

        // Iterate through each VideoCall
        for (VideoCall vc : videoCalls) {
            // Create Meeting Note
            Meeting_Note__c meetingNote = new Meeting_Note__c();
            meetingNote.Name = vc.Name; 
            meetingNote.SalesPresentation__c = true; 
            meetingNote.Date__c = vc.EndDateTime != null ? vc.EndDateTime.date() : null;
            meetingNote.Note__c = vc.Summaries.size() > 0 ? vc.Summaries[0].Summary : null;
            meetingNotes.add(meetingNote);
            meetingNotesMap.put(vc.Id, meetingNote);
            // Create Event
            Event evt = new Event(
                StartDateTime = vc.StartDateTime != null ? vc.StartDateTime : null,
                EndDateTime = vc.EndDateTime != null ? vc.EndDateTime : null,
                Subject = vc.Name
            );
            events.add(evt);
            eventsMap.put(vc.Id, evt);

            // Create EventRelations
            for (SObject cont : vc.VideoCalls) {
                EventRelation evntRelation = new EventRelation(
                    IsInvitee = false,
                    IsWhat = false,
                    IsParent = true,
                    RelationId = (String)cont.get('RelatedPersonId')
                );
                eventRelations.add(evntRelation);
                if(eventRelationsMap.get(vc.Id) != null){
                     eventRelationsMap.get(vc.Id).add(evntRelation);
    
                }else{
                    eventRelationsMap.put(vc.Id, new List<EventRelation>{evntRelation});
                }
            }

            // Parse Feedback and create ClientInterests
            List<ProductFeedback> productsAndRatings = parseFeedback(getProductsAndRatings(meetingNote.Note__c));
            for (ProductFeedback prodRating : productsAndRatings) {
                ClientInterest__c cli = new ClientInterest__c(
                    Product__c = prodRating.productId,
                    Interest__c = prodRating.rating,
                    MeetingNote__c = meetingNote.Id
                );
                clientInterests.add(cli);
                
                if(clientInterestsMap.get(vc.Id) != null){
                    clientInterestsMap.get(vc.Id).add(cli);
   
               }else{
                clientInterestsMap.put(vc.Id, new List<ClientInterest__c>{cli});
               }
            }
        }


        // Perform bulk DML operations
        if (!meetingNotesMap.values().isEmpty()) {
            insert meetingNotesMap.values();
        }
        if (!eventsMap.values().isEmpty()) {
            for (Id vcId : eventsMap.keyset()) {
                eventsMap.get(vcId).Meeting_Note__c = meetingNotesMap.get(vcId).Id;
            }
            insert eventsMap.values();
        }
        if (!eventRelationsMap.values().isEmpty()) {
            List<EventRelation> eventRelationsList = new List<EventRelation>();

            for (Id vcId : eventRelationsMap.keyset()) {
                for (EventRelation evtRel : eventRelationsMap.get(vcId)) {
                    evtRel.EventId = eventsMap.get(vcId).Id;
                    eventRelationsList.add(evtRel);
                }
            }
            insert eventRelationsList;
        }
        if (!clientInterestsMap.values().isEmpty()) {
            List<ClientInterest__c> clientInterestsList = new List<ClientInterest__c>();

            for (Id vcId : clientInterestsMap.keyset()) {
                for (ClientInterest__c cli : clientInterestsMap.get(vcId)) {
                    cli.MeetingNote__c = meetingNotesMap.get(vcId).Id;
                    clientInterestsList.add(cli);

                }
            }
            insert clientInterestsList;
        }
        
    }
    
    @AuraEnabled
    public static String getProductsAndRatings(String summary){
        Map<String, Object> Params = new Map<String, Object>();
        Params.put('summary',summary);
    
        // Instantiate and start the Flow
        Flow.Interview.Get_Client_Intersts_from_video_call_summary yourFlow = new Flow.Interview.Get_Client_Intersts_from_video_call_summary(params);
        yourFlow.start();
        string ouput=(string)yourFlow.getvariableValue('output');
        System.debug('testt => '+ouput);
        return ouput;
    }
    
    public static List<Meeting_Note_Insight__c> getJSONMeetingNote(List<Meeting_Note__c> recordIds) {
        List<Meeting_Note_Insight__c> mndllList = new List<Meeting_Note_Insight__c>();
        List<Meeting_Note__c> failedRecords = new List<Meeting_Note__c>();
        Map<Id, String> failedReasons = new Map<Id, String>();
    
        for (Meeting_Note__c mn : recordIds) {
            try {
                Id recordId = mn.Id;
                Map<String, Object> params = new Map<String, Object>();
                params.put('MeetingNoteObj', mn);
    
                // Instantiate and start the Flow
                Flow.Interview.Get_JSON_insights_from_MeetingNotes jsonFlow = new Flow.Interview.Get_JSON_insights_from_MeetingNotes(params);
                jsonFlow.start();
                // Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

                // // Add 'InputText' parameter with your desired value
                // ConnectApi.WrappedValue inputTextValue = new ConnectApi.WrappedValue();
                // inputTextValue.value = 'This is the input textes for testing'; // Replace with actual input text
                // inputParams.put('Input:InputText', inputTextValue);
                // String output = EinsteinGenerativeGatewayService.generateResponseFromPromptTemplate('JSON_Insights_from_MeetingNote', inputParams);

                // Parse JSON insights
                List<ProductInsights> productsInsight = parseInsights((String)jsonFlow.getvariableValue('output'));
                System.debug('Insights: ' + productsInsight);
    
                // Create Meeting Note Insight records
                for (ProductInsights prod : productsInsight) {
                    if (prod.product_Id != 'unknown' && prod.product_Id != null && prod.product_Id != '') {
                        Meeting_Note_Insight__c dmo = new Meeting_Note_Insight__c();
                        dmo.Product__c = prod.product_Id;
                        dmo.Sentiment__c = prod.sentiment;
                        dmo.Meeting_Note__c = prod.meetingNote_Id;
                        dmo.Inisghts__c = prod.key_highlights;
                        mndllList.add(dmo);
                    }
                }
            } catch (Exception e) {
                // Log failed record and reason
                failedRecords.add(mn);
                failedReasons.put(mn.Id, e.getMessage());
                System.debug('Failed to process record: ' + mn.Id + ', Error: ' + e.getMessage());
            }
        }
    
        // Perform partial insert
        if (!mndllList.isEmpty()) {
            Database.SaveResult[] results = Database.insert(mndllList, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    System.debug('Failed to insert record: ' + mndllList[i] + ', Error: ' + results[i].getErrors()[0].getMessage());
                }
            }
        }
    
        // Log failed records for debugging or retrying
        if (!failedRecords.isEmpty()) {
            System.debug('Failed records: ' + failedRecords);
            System.debug('Failed reasons: ' + failedReasons);
        }
    
        return mndllList;
    }

    public class ProductFeedback {
        public String productId { get; set; }
        public String productName { get; set; }
        public Integer rating { get; set; }
        public String why { get; set; }
    }

    public class ProductInsights {
        public String product_Id { get; set; }
        public String product_name { get; set; }
        public String meetingNote_Id { get; set; }
        public String sentiment { get; set; }
        public String key_highlights { get; set; }
        
    }

    // Method to parse JSON into a list of wrapper objects
    public static List<ProductFeedback> parseFeedback(String jsonString) {
        try {
            // Parse the JSON string into a list of wrapper objects
            List<ProductFeedback> feedbackList = (List<ProductFeedback>) JSON.deserialize(jsonString, List<ProductFeedback>.class);
            System.debug('feedbackListc=>'+feedbackList);
            return feedbackList;
        } catch (Exception e) {
            System.debug('Error parsing JSON: ' + e.getMessage());
            return new List<ProductFeedback>();
        }
    }
    // Method to parse JSON into a list of wrapper objects
    public static List<ProductInsights> parseInsights(String jsonString) {
        try {
            // Parse the JSON string into a list of wrapper objects
            List<ProductInsights> feedbackList = (List<ProductInsights>) JSON.deserialize(jsonString, List<ProductInsights>.class);
            System.debug('feedbackList=>'+feedbackList);
            return feedbackList;
        } catch (Exception e) {
            System.debug('Error parsing JSON: ' + e.getMessage());
            return new List<ProductInsights>();
        }
    }

    // Wrapper Class
    public class VideoCallDataWrapper {
        @AuraEnabled public String Name;
        @AuraEnabled public String EndDateTime;
        @AuraEnabled public String Description;
        @AuraEnabled public Decimal IntelligenceScore;
        @AuraEnabled public String Summary;
        @AuraEnabled public List<Contact> ContactIds;
        @AuraEnabled public List<ClientInterest__c> ClientInterest;
    }

    public class CreationWrapper {
        @AuraEnabled public List<sObject> objectList;
        @AuraEnabled public Boolean success;
        public CreationWrapper(List<sObject> objectList , Boolean success){
            this.objectList = objectList;
            this.success = success;
        }
    }

}