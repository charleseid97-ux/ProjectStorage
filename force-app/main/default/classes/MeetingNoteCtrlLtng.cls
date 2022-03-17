/*************************************************************************************************************************
Class Name      :   MeetingNoteCtrlLtng
Class Desc.     :   Controller class for lightning Meeting Note component
Author          :   Alpha FMC

Change History
Date             Author         version             Description                                 Requested By           Tag
--------------------------------------------------------------------------------------------------------------------------
Dec-2017         Alpha FMC       0.01            Initial build of lightning version of class       Internal            None
Jan-2018         Alpha FMC       0.02            Added Meeting Note Prefix variable to fix nav     Internal            None
***************************************************************************************************************************/
global with sharing class MeetingNoteCtrlLtng{
    
  public class MeetingNote{
    
    @AuraEnabled
    public Meeting_Note__c MeetingNote;
    @AuraEnabled
    public Meeting_Link__c [] MeetingLinks;
    @AuraEnabled
    public String MeetingNotePrefix = Meeting_Note__c.sobjecttype.getDescribe().getKeyPrefix();
    
    MeetingNote(){
        this.MeetingLinks = new List<Meeting_Link__c>();
    }
  }

    @AuraEnabled
    public static MeetingNote getMeetingNote(id recordId, id fromId)
    { 
        MeetingNote result = new MeetingNote();
        
        if (recordId == null && fromId != null)
        {   
        	recordId = MeetingNoteUtil.IdFromActivity(string.valueOf(fromId));
        } 

        if (recordId != null){
            
            result.MeetingNote = [SELECT Id,
                                 Name,
                                 OwnerId,
                                 Owner.Id,
                                 Owner.Name,
                                 Note__c,
                                 Meeting_Type__c,
                                 Purpose__c,
                                 Date__c,
                                 (SELECT Name,
                                  Employee__c,
                                  Employee__r.Name,
                                  Contact__c,
                                  Contact__r.Name,
                                  Meeting_Note__c,
                                  Opportunity__c,
                                  Opportunity__r.Name,
                                  Account__c,
                                  Account__r.Name,
                                  Product__c,
                                  Product__r.Name,
                                  Interest_Level__c,
                                  Product_Sentiment__c,
                                  Link_Type__c
                                  FROM Meeting_Links__r)
                                 FROM Meeting_Note__c
                                 WHERE Id = :recordId];
                                 
            result.MeetingLinks = result.MeetingNote.Meeting_Links__r;
                                 
        }else{
            result.MeetingNote = new Meeting_Note__c();
        }

        if (recordId == null && fromId != null )
        {
            MeetingNoteUtil mnUtil = new MeetingNoteUtil(fromId);

            result.MeetingNote = mnUtil.MeetingNote;
            result.MeetingLinks = mnUtil.AllMeetingLinks;
        }
        
        if(result.MeetingNote.Date__c == null)
        {
            result.MeetingNote.Date__c = date.today();
        }
        
        if(result.MeetingNote.OwnerId == null)
        {
            result.MeetingNote.OwnerId = UserInfo.getUserId();
        }

        return result;
    }

    @AuraEnabled
    public static MeetingNote saveMeetingNote(Meeting_Note__c meetingNote, Meeting_Link__c[] meetingLinks, id fromId) {
        
        Meeting_Link__c[] meetingLinksToInsert = new List<Meeting_Link__c>();
        Meeting_Link__c[] meetingLinksToUpdate = new List<Meeting_Link__c>();
        Meeting_Link__c[] meetingLinksToDelete = new List<Meeting_Link__c>();

        upsert meetingNote;
        
        if (meetingNote.Id != null){
            
            MeetingNote mnStructure =  getMeetingNote(meetingNote.Id, null);
            Meeting_Note__c oldMeetingNote =  mnStructure.MeetingNote;
            Meeting_Link__c[] oldMeetingLinks = mnStructure.MeetingLinks;
            
            for (Meeting_Link__c meetingLink : meetingLinks){
                boolean found = false;
                
                for (Meeting_Link__c oldMeetingLink : oldMeetingLinks){
                    
                    if ((meetingLink.Account__c == oldMeetingLink.Account__c && meetingLink.Account__c != null && oldMeetingLink.Account__c != null)
                        || (meetingLink.Contact__c == oldMeetingLink.Contact__c && meetingLink.Contact__c != null && oldMeetingLink.Contact__c != null)
                        || (meetingLink.Employee__c == oldMeetingLink.Employee__c && meetingLink.Employee__c != null && oldMeetingLink.Employee__c != null)
                        || (meetingLink.Product__c == oldMeetingLink.Product__c && meetingLink.Product__c != null && oldMeetingLink.Product__c != null)
                        || (meetingLink.Opportunity__c == oldMeetingLink.Opportunity__c && meetingLink.Opportunity__c != null && oldMeetingLink.Opportunity__c != null))
                    {
                        meetingLink.Id = oldMeetingLink.Id;
                        meetingLinksToUpdate.add(meetingLink);
                        found = true;
                        break;
                    }                        
                }
                
                if (!found){
                    meetingLink.Meeting_Note__c = meetingNote.Id;
                    meetingLink.Name = meetingNote.Name;
                    meetingLink.Date__c = meetingNote.Date__c;
                    meetingLinksToInsert.add(meetingLink);
                }
            }   
            
            for (Meeting_Link__c oldMeetingLink : oldMeetingLinks){
                boolean found = false;
                
                for (Meeting_Link__c meetingLink : meetingLinks){
                    
                    if ((meetingLink.Account__c == oldMeetingLink.Account__c && meetingLink.Account__c != null && oldMeetingLink.Account__c != null)
                        || (meetingLink.Contact__c == oldMeetingLink.Contact__c && meetingLink.Contact__c != null && oldMeetingLink.Contact__c != null)
                        || (meetingLink.Employee__c == oldMeetingLink.Employee__c && meetingLink.Employee__c != null && oldMeetingLink.Employee__c != null)
                        || (meetingLink.Product__c == oldMeetingLink.Product__c && meetingLink.Product__c != null && oldMeetingLink.Product__c != null)
                        || (meetingLink.Opportunity__c == oldMeetingLink.Opportunity__c && meetingLink.Opportunity__c != null && oldMeetingLink.Opportunity__c != null))
                    {
                        found = true;
                        
                        system.debug('saveMeetingNote meetingLinksToDelete found' +  oldMeetingLink);
                        break;
                    }                        
                }
                
                if (!found){
                    meetingLinksToDelete.add(oldMeetingLink);
                }
            }

        }else{
            meetingLinksToInsert = meetingLinks;
        }
        
        if (meetingLinksToInsert.size() >0){
            insert meetingLinksToInsert;
        }

        if (meetingLinksToUpdate.size() >0){
            update meetingLinksToUpdate;
        }
        
        if (meetingLinksToDelete.size() >0){
            delete meetingLinksToDelete;
        }
        
        List<Meeting_Link__c> accountLinks = [SELECT Account__c FROM Meeting_Link__c Where Account__c <> '' AND Meeting_Note__c =: meetingNote.Id];
        List<Meeting_Link__c> contactLinks = [SELECT Contact__c FROM Meeting_Link__c Where Contact__c <> '' AND Meeting_Note__c =: meetingNote.Id];
        List<Meeting_Link__c> oppLinks = [SELECT Opportunity__c FROM Meeting_Link__c Where Opportunity__c <> '' AND Meeting_Note__c =: meetingNote.Id];
        meetingNote.Number_of_Companies__c = accountLinks.size();
        //Substring of the note field to sync with Tableau due too field size constraints
        if(meetingNote.Note__c != null && meetingNote.Note__c.length() > 0) {
            Integer endInt = meetingNote.Note__c.length() < 4090 ? meetingNote.Note__c.length()-1 : 4090;
    
            meetingNote.Note_SubString__c = meetingNote.Note__c.subString(0, endInt).stripHtmlTags().unescapeHtml4();
        }

        update meetingNote;

        if(fromId!= null)
        {
            MeetingNoteUtil.UpdateMeetingNoteActivity(string.valueOf(fromId), meetingNote.Id, meetingNote, contactLinks, oppLinks);
        }

        return  getMeetingNote(meetingNote.Id, null);
    }
}