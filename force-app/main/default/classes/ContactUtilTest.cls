/***
*	Test class for ContacCtrl class
*	19/02/2019 BP created
*
***/
@isTest
public with sharing class ContactUtilTest {
	//Test all positive cases
    static testMethod void testContactOwnership() {
        PAD.byPassUserTriggerHandler = true;
        CommonTestData.getData();
        
		UserRole r = new UserRole(DeveloperName = 'MyTestRole', Name = 'My Test Role');
		insert r;
        User u = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Carmignac - Standard User'].Id,
            LastName = 'lastname',
            Email = 'testuser001@amamama.com',
            Username = 'testuser001@amamama.com' + System.currentTimeMillis(),
            CompanyName = 'TEST Company',
            Title = 'titleTest',
            Alias = 'aTest',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            UserRoleId = r.Id,
            BypassApexTriggers__c = 'UserAfterInsert; UserAfterUpdate',
            BypassProcessBuilders__c = true,
            BypassValidationRules__c = true,
            BypassWorkflowRules__c = true
        );        

        System.runAs(u) {
            Test.startTest();
            
            User fUser = CommonTestData.frenchUser;
            User f2User = CommonTestData.frenchUser2;
            User sUser = CommonTestData.spanishUser;
            User h1User = CommonTestData.HOC1;
            User h2User = CommonTestData.HOC2;
            
            Contact testContact = CommonTestData.AccContact;
            testContact.Persona__c = 'B2B Buyer';
            testContact.ownerId = fUser.Id;
            testContact.Proposed_Contact_Owner__c = f2User.Id;
            testContact.Bypass_Apex__c = true;
            update testContact;
            
            system.debug('BP - RU - '+u);
            system.debug('BP - f2U - '+f2User);
            system.debug('BP - tC -'+testContact);
            String cPersona = ContactUtil.getContactPersona(testContact.Id);
            System.assertEquals(true, cPersona == 'B2B Buyer', 'Contact Persona returned');
            
            User currentOwner = ContactUtil.getCurrentUser(testContact.ownerId);
            system.debug('BP - START');
            User proposedOwnerF = ContactUtil.getCurrentUser(testContact.Proposed_Contact_Owner__c);
            system.debug('BP - cOF - '+currentOwner);
            system.debug('BP - pOF - '+proposedOwnerF);
            system.debug('BP - tC -'+testContact);
            
            
            Contact c = [SELECT Name, 
                     Id, 
                     OwnerId, 
                     Proposed_HOC_approval__c, 
                     Current_HOC_approval__c,
                     Persona__c,
                     Proposed_Contact_Owner__r.Name, 
                     Proposed_Contact_Owner__c,
                     Owner_Change_Requested_By__c
                     from Contact WHERE Id =: testContact.Id];
            system.debug('BP - CCCCC -'+c);
            Map<String, Object> globalResult = ContactUtil.buildApprovalData(testContact.Id);

            Boolean autoApprove = ContactUtil.autoApproveChange(currentOwner.BusinessDevelopmentRegions__c, proposedOwnerF.BusinessDevelopmentRegions__c);
            System.assertEquals(true, autoApprove, 'Change Auto Approved');

            ContactUtil.saveContact(testContact.Id, autoApprove, proposedOwnerF);

            testContact.Proposed_Contact_Owner__c = sUser.Id;
            
            User proposedOwnerS = ContactUtil.getCurrentUser(testContact.Proposed_Contact_Owner__c);
            autoApprove = ContactUtil.autoApproveChange(currentOwner.BusinessDevelopmentRegions__c, proposedOwnerS.BusinessDevelopmentRegions__c);
            System.assertEquals(false, autoApprove, 'Change NOT Auto Approved');
            
            ContactUtil.saveContact(testContact.Id, autoApprove, proposedOwnerS);
            
            ContactUtil.approveCurrent(testContact.Id);
            ContactUtil.approveProposed(testContact.Id);

            
            testContact.Proposed_Contact_Owner__c = fUser.Id;
            
            proposedOwnerF = ContactUtil.getCurrentUser(testContact.Proposed_Contact_Owner__c);
            autoApprove = ContactUtil.autoApproveChange(currentOwner.BusinessDevelopmentRegions__c, proposedOwnerS.BusinessDevelopmentRegions__c);
            System.assertEquals(false, autoApprove, 'Change 2 NOT Auto Approved');
            
            ContactUtil.saveContact(testContact.Id, autoApprove, proposedOwnerS);

            Contact returnContact = ContactUtil.getCurrentContact(testContact.id);
            ContactUtil.rejectOwnershipChange(returnContact);
            
            Test.stopTest();
        }
    }
}