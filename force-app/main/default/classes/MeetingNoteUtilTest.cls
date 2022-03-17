/*************************************************************************************************************************
Class Name      :   MeetingNoteUtilTest
Class Desc.     :   Test class for Utility Class for Meeting_Note__c object to handle prepopulation of
                    Meeting Notes from an Activity          
Author          :   Alpha FMC

Change History
Date             Author         version             Description                                 Requested By           Tag
--------------------------------------------------------------------------------------------------------------------------
Dec-2014         Alpha FMC       0.01            Initial build of class                           Client               None
Feb-2017		 Alpha FMC       0.02            Updated test to new Utility format               Client               None         
***************************************************************************************************************************/
@isTest
private class MeetingNoteUtilTest 
{
    
    @isTest static void unitTestEvent()
    {
        CoreDataTest.getData();
        
        
        //Set up the event
        User u = [SELECT Id FROM User WHERE isActive = True LIMIT 1];

        //make sure the employee contact is linked to the user
        //CoreDataTest.contacts[0].User__c = u.id;
        //update CoreDataTest.contacts[0];

        Event e = new Event(Subject = 'TestEvent', StartDateTime = System.Now(), EndDateTime = System.Now().addMinutes(60) 
                            , WhoId = CoreDataTest.contacts[3].Id
                            , WhatId = CoreDataTest.opportunities[0].Id 
                            , Description = 'My test event description'
                            , ActivityDate = System.Today());
        insert e;


		//please note CoreDataTest.contacts[3] & CoreDataTest.contacts[5] are external contacts linked to two different accounts

        //set up the event relations
        EventRelation er1 = new EventRelation(EventId = e.Id, RelationId = CoreDataTest.contacts[5].Id, isInvitee = true);

        

        insert er1;

        test.startTest(); 
        MeetingNoteUtil MNUtil = new MeetingNoteUtil(e.id);
        //System.assertEquals('My test event description', MNUtil.MeetingNote.Note__c, 'The call report note does not match');
        System.assertEquals(1,MNUtil.Accounts.size(),'There should only be 2 Accounts linked to this meeting, external contact\' accounts should show');
        System.assertEquals(1,MNUtil.ExternalContacts.size(),'There should only be 2 External Contact linked to this meeting');
        System.assertEquals(1,MNUtil.InternalContacts.size(),'There should only be 1 Internal Contact linked to this meeting (Event Owner)');
        System.assertEquals(1,MNUtil.Opportunities.size(),'There should only be 1 Opportunity linked to this meeting');
        test.stopTest();
    }

    @isTest static void testIdFromActivity() {
        CoreDataTest.getData();

        User u = [SELECT Id FROM User WHERE isActive = True LIMIT 1];

        Meeting_Note__c mn = new Meeting_Note__c(Name = 'test', Date__c = Date.today());

        Event e = new Event(Subject = 'TestEvent', StartDateTime = System.Now(), EndDateTime = System.Now().addMinutes(60) 
                            , WhoId = CoreDataTest.contacts[3].Id
                            , WhatId = CoreDataTest.opportunities[0].Id 
                            , Description = 'My test event description'
                            , ActivityDate = System.Today()
                            , Meeting_Note__c = mn.Id);
        insert e;

        EventRelation er1 = new EventRelation(EventId = e.Id, RelationId = CoreDataTest.contacts[5].Id, isInvitee = true);

        Task t = new Task(Subject = 'test', 
                            ActivityDate = Date.today(), 
                            WhoId = CoreDataTest.contacts[3].Id, 
                            WhatId = CoreDataTest.opportunities[0].Id, 
                            OwnerId = u.Id, 
                            Meeting_Note__c = mn.Id);
        insert t;

        test.startTest();
            System.assertEquals(mn.Id, MeetingNoteUtil.IdFromActivity(e.Id));
            System.assertEquals(mn.Id, MeetingNoteUtil.IdFromActivity(t.Id));
        test.stopTest();
    }


    

    

}