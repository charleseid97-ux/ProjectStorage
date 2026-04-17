/*************************************************************************************************************************
Class Name      :   MeetingNoteCtrlLtngTest
Class Desc.     :   Test class for controller for lightning Meeting Note component
Author          :   Alpha FMC

Change History
Date             Author         version             Description                                 Requested By           Tag
--------------------------------------------------------------------------------------------------------------------------
Jan-2018         Alpha FMC       0.02            Initial Build								     Internal            None
***************************************************************************************************************************/
@isTest
public with sharing class MeetingNoteCtrlLtngTest {
    

@isTest static void testExistigMeetingNote(){
 	PAD.byPassUserTriggerHandler = true;
    PAD.byPassContactTriggerHandler = true;
 	CommonTestData.getData();
 	
 	Meeting_Note__c MNote = new Meeting_Note__c(Name = 'Testing Testing',
                Date__c = system.today()
                , Note__c = 'My test Note'
                );
    
    insert MNote;
    
    Meeting_Link__c mlink = new Meeting_Link__c (Meeting_Note__c = MNote.Id, Employee__c = CommonTestData.EmployeeContact.Id);
    
 	Insert mlink;
    	
    MeetingNoteCtrlLtng.MeetingNote MNoteFromEmployee =  MeetingNoteCtrlLtng.getMeetingNote(MNote.Id, null);
    
 	// creating array of meeting links from Meeting Note (MNote) we just created    
    Meeting_Link__c[] MNoteLinks = MNoteFromEmployee.MeetingLinks;
 	
  	// assert whether the no. of Meeting links created is 1
  	// this is because an organization will also be linked with a Contact 	
 	System.assertEquals(MNoteLinks.size(), 1);
 	
 	System.assertEquals(MNoteFromEmployee.MeetingNote.Date__c, system.today());
	boolean found = false;
	
	for (Meeting_Link__c ml : MNoteLinks){
		if(ml.Employee__c == CommonTestData.EmployeeContact.Id){
			found = true;
		}
		
	}
	System.assertEquals(found, true);
    	
 }
 
 @isTest static void testSaveMeetingNote(){
 	PAD.byPassUserTriggerHandler = true;
    PAD.byPassContactTriggerHandler = true;
 	CommonTestData.getData();
 	
 	Meeting_Note__c MNote = new Meeting_Note__c(Name = 'Testing Testing',
                Date__c = system.today()
                , Note__c = 'My test Note'
                );
    
    Meeting_Link__c ml = new Meeting_Link__c (Employee__c = CommonTestData.EmployeeContact.Id);
    
    MeetingNoteCtrlLtng.saveMeetingNote(MNote, new List <Meeting_Link__c>{ml}, null);
    	
 }

//Test Meeting Linked Employee 
 @isTest static void testCreateFromEmployeeMeetingNote(){
 	PAD.byPassUserTriggerHandler = true;
    PAD.byPassContactTriggerHandler = true;
 	CommonTestData.getData();   
    	
    MeetingNoteCtrlLtng.MeetingNote MNoteFromEmployee =  MeetingNoteCtrlLtng.getMeetingNote(null, CommonTestData.EmployeeContact.Id);
    
 	// creating array of meeting links from Meeting Note (MNote) we just created    
    Meeting_Link__c[] MNoteLinks = MNoteFromEmployee.MeetingLinks;
 	
  	// assert whether the no. of Meeting links created is 1
  	// this is because an organization will also be linked with a Contact 	
 	System.assertEquals(MNoteLinks.size(), 2);
 	
 	System.assertEquals(MNoteFromEmployee.MeetingNote.Date__c, system.today());
	boolean found = false;
	
	for (Meeting_Link__c ml : MNoteLinks){
		if(ml.Employee__c == CommonTestData.EmployeeContact.Id){
			found = true;
		}
		
	}
	System.assertEquals(found, true);
 }

//Test Meeting Linked Product
 @isTest static void testCreateFromProductMeetingNote(){
 	PAD.byPassUserTriggerHandler = true;
    PAD.byPassContactTriggerHandler = true;
 	CommonTestData.getData();
 	

    MeetingNoteCtrlLtng.MeetingNote MNoteFromProduct =  MeetingNoteCtrlLtng.getMeetingNote(null, CommonTestData.Product.Id);
    
 	// creating array of meeting links from Meeting Note (MNote) we just created
    Meeting_Link__c[] MNoteLinks = MNoteFromProduct.MeetingLinks;
 	
  	//assert whether the no. of Meeting links created is 1  	  	
 	System.assertEquals(MNoteLinks.size(), 1);
 	
 	System.assertEquals(MNoteFromProduct.MeetingNote.Date__c, system.today());
	boolean found = false;
	
	for (Meeting_Link__c ml : MNoteLinks){
		if(ml.Product__c == CommonTestData.Product.Id){
			found = true;
		}
	}
	System.assertEquals(found, true); 	
 }
 
 	/*******************************************************************************************************
    * @description insert a event and a meeting note then call the saveMeetingNote method and we test that the event field was populated with the new meeting note
    */
	@isTest static void testCreateFromEventMeetingNote(){
        PAD.byPassUserTriggerHandler = true;
        PAD.byPassContactTriggerHandler = true;
		CommonTestData.getData();
		Event tmpEvt = new Event();
		tmpEvt.Subject = 'TestEvent';
		tmpEvt.StartDateTime = System.Now();
		tmpEvt.EndDateTime = System.Now().addMinutes(60);
		tmpEvt.WhoId = CommonTestData.AccContact.Id;
		tmpEvt.WhatId = CommonTestData.ChildAct.Id; 
	    tmpEvt.Description = 'My test event description';
	    tmpEvt.ActivityDate = System.Today();
	    //tmpEvt.Event_Type__c = 'Face to Face Meeting';	
		insert tmpEvt;
		
		Meeting_Note__c tmpMeetingNote = new Meeting_Note__c();
		tmpMeetingNote.Name = 'Testing Testing';
		tmpMeetingNote.Date__c = system.today();
		tmpMeetingNote.Note__c = 'My test Note';    
    	insert tmpMeetingNote;
    	
		Meeting_Link__c ml = new Meeting_Link__c (Employee__c = CommonTestData.EmployeeContact.Id);
    
    	MeetingNoteCtrlLtng.saveMeetingNote(tmpMeetingNote, new List <Meeting_Link__c>{ml}, tmpEvt.Id);
    	
    	Event evtToAssert = [SELECT Id, Meeting_Note__c FROM Event WHERE Id=:tmpEvt.Id];
    	
    	//test that the event got the id of the meeting note
    	System.assertEquals(tmpMeetingNote.Id, evtToAssert.Meeting_Note__c); 
	}
 
//Test whether Meeting Link created is Contact
 @isTest static void testCreateFromContactMeetingNote(){
 	PAD.byPassUserTriggerHandler = true;
    PAD.byPassContactTriggerHandler = true;
 	CommonTestData.getData();	
	
	
    MeetingNoteCtrlLtng.MeetingNote MNoteFromContact =  MeetingNoteCtrlLtng.getMeetingNote(null, CommonTestData.AccContact.Id);
    
 	// creating array of meeting links from Meeting Note (MNote) we just created
    Meeting_Link__c[] MNoteLinks = MNoteFromContact.MeetingLinks;
 	
  	//assert whether the no. of Meeting links created is 2
  	//this is because an organization will also be linked with a Contact	
 	System.assertEquals(MNoteLinks.size(), 2);
 	boolean found = false;
 	
 	for (Meeting_Link__c ml : MNoteLinks){
		if(ml.Contact__c == CommonTestData.AccContact.Id){
			found = true;
		}
	}
	
	System.assertEquals(found, true); 	
 	
 }

 //Test whether Meeting Link created is Organization (Account__c)
 @isTest static void testCreateFromOrganizationMeetingNote(){
 	PAD.byPassUserTriggerHandler = true;
    PAD.byPassContactTriggerHandler = true;
 	CoreDataTest.getData(); 		
  
	
	// (sets MNote as the MeetingNote we've just created)
    MeetingNoteCtrlLtng.MeetingNote MNoteFromOrganization =  MeetingNoteCtrlLtng.getMeetingNote(null, CoreDataTest.Accounts[0].Id);
    
 	// creating array of meeting links from Meeting Note (MNote) we just created
    Meeting_Link__c[] MNoteLinks = MNoteFromOrganization.MeetingLinks;
 	
  	//assert whether the no. of Meeting links created is 1
   	//System.assertEquals(MNoteLinks.size(), 1);
   	
   	boolean found = false;
 	
 	for (Meeting_Link__c ml : MNoteLinks){
		if(ml.Account__c == CoreDataTest.Accounts[0].Id){
			found = true;
		}
	}
	System.assertEquals(found, true); 	
   	
  

 }

//-------------------------------------------------------------------------------------------------------------------------------------

 
  //Test whether Meeting Link created is Opportunity 
 @isTest static void testCreateFromOpportunityMeetingNote(){
 	PAD.byPassUserTriggerHandler = true;
    PAD.byPassContactTriggerHandler = true;
 	CommonTestData.getData();
	
	// (sets MNote as the MeetingNote we've just created)
    MeetingNoteCtrlLtng.MeetingNote MNoteFromOpportunity =  MeetingNoteCtrlLtng.getMeetingNote(null, CommonTestData.Opp.Id);
    
 	// creating array of meeting links from Meeting Note (MNote) we just created
    Meeting_Link__c[] MNoteLinks = MNoteFromOpportunity.MeetingLinks;
 	
  	//assert whether the no. of Meeting links created is 1
  	// 2 because an Opportunity will always be linked to an Organization
   	System.assertEquals(MNoteLinks.size(), 1);
   	
   	boolean found = false;
 	
 	for (Meeting_Link__c ml : MNoteLinks){
		if(ml.Opportunity__c == CommonTestData.Opp.Id){
			found = true;
		}
	}
	
	System.assertEquals(found, true); 
 }
 
}