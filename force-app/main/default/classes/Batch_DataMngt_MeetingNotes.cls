/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 15-09-2023
 * @last modified by  : Thanina YAYA
**/

public without sharing class Batch_DataMngt_MeetingNotes implements Database.Batchable<SObject> {
    
    public static String query='select (select Id,Product__c,Interest_Level__c,Product_Sentiment__c,Product__r.Strategy__c,Product__r.Fund__c,Product__r.Record_Type_Name__c ' 
    + 'from Meeting_Links__r where Product__c!=null),Id,Meeting_Type__c,Purpose__c,Investment_Solution__c , Macro__c,Brand__c,Company__c,SalesPresentation__c,RelationshipManagement__c,Topic__c from Meeting_Note__c where Company__c = null and Meeting_Type__c!=\'Call\' and Meeting_Type__c!=\'Meeting\' and Meeting_Type__c!=\'Event\'';
    
    public Database.QueryLocator start(Database.BatchableContext bc)
    {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Meeting_Note__c> meetingList)
    {
        //Map<Id,List<Meeting_Link__c>> mapMeeting = new Map<Id,List<Meeting_Link__c>>();
        Set<Id> mapMeeting = new Set<Id>();
        List<ClientInterest__c> interests = new List<ClientInterest__c>();
        
        //meeting Note without event related to account
        for(Meeting_Note__c oneMeet:meetingList){
          
                mapMeeting.add(oneMeet.Id);
                oneMeet.SalesPresentation__c = (oneMeet.Meeting_Links__r.size() > 0)? true:false;
                oneMeet.RelationshipManagement__c = !oneMeet.SalesPresentation__c;
                oneMeet.Meeting_Type__c =(oneMeet.Meeting_Type__c =='Client phone call / conference call')?'Call':(oneMeet.Meeting_Type__c == 'Event (Schedule)')?'Event':'Meeting';
                if(oneMeet.RelationshipManagement__c){
                    if(oneMeet.Purpose__c!=null && !String.isEmpty(oneMeet.Purpose__c) && 'Training with Partners,Invitation / Meeting Scheduling,Partnership,Quarterly Meeting'.contains(oneMeet.Purpose__c)){
                        oneMeet.Topic__c = 'Training with Partners';
                    }else if(oneMeet.Purpose__c!=null && !String.isEmpty(oneMeet.Purpose__c)) oneMeet.Topic__c = 'Corporate Brand';
                        else {
                            if( oneMeet.Macro__c) oneMeet.Topic__c = 'Training with Partners';
                            else if(oneMeet.Brand__c || oneMeet.Investment_Solution__c) oneMeet.Topic__c = 'Corporate Brand';
                                else oneMeet.Topic__c = 'Training with Partners';
                        }     
                }
                //interest part 
                for(Meeting_Link__c prod:oneMeet.Meeting_Links__r){
                    Id prodId = (prod.Product__r?.Record_Type_Name__c=='Fund' && prod.Product__r?.Strategy__c != null)? prod.Product__r?.Strategy__c : prod.Product__c;
                    if(prodId != null)
                    interests.add(new ClientInterest__c(Interest__c = (prod.Interest_Level__c =='High')?5:(prod.Interest_Level__c == 'Low')?1:3,MeetingNote__c = oneMeet.Id ,Product__c= prodId, Sentiment__c= prod.Product_Sentiment__c));
                }
            
        }
        //get related Contact and Activities 
        Map<Id,Meeting_Note__c> meetParticip = new Map<Id,Meeting_Note__c>([select Id, (select Id,Employee__c,Contact__c ,Employee__r.AccountId from Meeting_Links__r where Employee__c!=null or Contact__c!=null ),
        (select Id, what.Type, whatId,whoId from Activities__r  where What.Type = 'Account' limit 1) from Meeting_Note__c where Id In :mapMeeting]);
        List<EventRelation> allattended = new List<EventRelation>();
        //manage participant part : to create event relation.
        for(Meeting_Note__c oneMeet:meetingList){
            Map<Id,EventRelation> attendee = new Map<Id,EventRelation>();
            Id evtId= null; Id evtWho = null;
            if(meetParticip.containsKey(oneMeet.Id))
            {
                if(meetParticip.get(oneMeet.Id).Activities__r.size()> 0){
                    oneMeet.Company__c = (meetParticip.get(oneMeet.Id)).Activities__r[0].whatId;
                    evtId = (meetParticip.get(oneMeet.Id)).Activities__r[0].Id;
                    evtWho = (meetParticip.get(oneMeet.Id)).Activities__r[0].whoId;
                }
            
                for(Meeting_Link__c cont:meetParticip.get(oneMeet.Id).Meeting_Links__r){
                    if(evtId != null){
                        if(cont.Employee__c != null && cont.Employee__c != evtWho){
                            attendee.put(cont.Employee__c ,new EventRelation(   EventId = evtId,
                                                                                IsInvitee = false,
                                                                                IsWhat = false,
                                                                                IsParent=true,
                                                                                RelationId = cont.Employee__c));
                        }
                        if(cont.Contact__c != null && cont.Contact__c != evtWho) {
                            attendee.put(cont.Contact__c,new EventRelation( EventId = evtId,
                                                                            IsInvitee = false,
                                                                            IsWhat = false,
                                                                            IsParent=true,
                                                                            RelationId = cont.Contact__c));
                        }
                    }
                }
            }
            if(attendee.size() > 0) allattended.addAll(attendee.values());
        }

        //insert Client Interest 
        if(interests.size()> 0 ) insert interests;
        //insert Participant
        if(allattended.size() > 0 ) Database.insert(allattended, false);
        //update meetingNote 
        update meetingList;

    }

    public void finish(Database.BatchableContext bc){
        // execute any post-processing operations
        System.debug('@@@End Batch Reprise données Meeting Note------');
    }
}