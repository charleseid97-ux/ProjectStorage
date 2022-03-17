/*************************************************************************************************************************
Class Name      :   MoveContactCtrlTest
Class Desc.     :   Test class for Extension controller Class for page MoveContact to handle contact move process            
Author          :   Alpha FMC

Change History
Date             Author         version             Description                                 Requested By           Tag
--------------------------------------------------------------------------------------------------------------------------
Mar-2018         Alpha FMC       0.01            Initial build of class                           Client               None         
***************************************************************************************************************************/
@isTest
private class MoveContactCtrlTest {

    //Test all positive cases
    static testMethod void testPositive() {
        PAD.byPassUserTriggerHandler = true;
        PAD.byPassContactTriggerHandler = true;
        test.startTest();
        User usr = [Select id from User where Id = :UserInfo.getUserId()];
        usr.Bypass_Duplicate_Rules__c = true;
        update usr;
        System.runAs(usr) {
      	CommonTestData.getData();
        //Create the inactive contacts holding account
        Account holdingAct = new Account();
        
        holdingAct.Name = 'testHolAcc';
        holdingAct.RecordTypeId = UtilitiesSobject.getRecordTypeIdsByDeveloperName('Account').get('Company_for_Inactive_External_Contacts');
        holdingAct.BusinessDevelopmentRegion__c = 'BP_FR';
        insert holdingAct;
        
        //Contact we are moving and the new values for the contact
        Contact newContact = new Contact (Email = 'fred@bloggs.com');
        Contact oldContact = CommonTestData.AccContact;
        
        
        
        //Test the method to check if two accounts are in the same 
        boolean sameHierarchy = MoveContactCtrlLtng.checkSameHierarchy(CommonTestData.ChildAct.Id, CommonTestData.OtherAct.Id);
        
        System.assertEquals(false, sameHierarchy);
            
        //Test saving to an account that is in the same hierarchy
        MoveContactCtrlLtng.doSave(oldContact.Id,
    					newContact, 
    					CommonTestData.ChildAct.Id,
    					true, 
    					false, 
    					Date.today(),oldContact); 
        
        Former_Employment_Relationship__c [] fmrEmpls = [select id from Former_Employment_Relationship__c];
        
        //No former employment records should be created
        System.assertEquals(0, fmrEmpls.size());
        
        //Test saving to an account that is in a different hierarchy
        MoveContactCtrlLtng.doSave(oldContact.Id,
                                   newContact, 
                                   CommonTestData.OtherAct.Id,
                                   false, 
                                   false, 
                                   Date.today(),oldContact);
        
        fmrEmpls = [select id from Former_Employment_Relationship__c];
        
        //One employment records should be created
        System.assertEquals(1, fmrEmpls.size());
        
        //Test moving to the inactive contacts account
        MoveContactCtrlLtng.doSave(oldContact.Id,
                                   newContact, 
                                   null,
                                   false, 
                                   true, 
                                   Date.today(),oldContact);
        
        fmrEmpls = [select id from Former_Employment_Relationship__c];
        
        //One moreb employment records should be created
        System.assertEquals(2, fmrEmpls.size());
        
        //Test retrieving the Job_Title__c picklist values
		List<String> titles = MoveContactCtrlLtng.getJobTitleOptions();
            
        List<String> corpOptions = MoveContactCtrlLtng.getCorporateTitleOptions();
            
        List<String> jobOptions = MoveContactCtrlLtng.getJobFunctionOptions();
        
        System.assertNotEquals(0, titles.size());
        }
        test.stopTest();
    }
}