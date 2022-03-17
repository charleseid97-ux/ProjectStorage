/** 
* @author Stéphane TROTTO
* @date Creation 06/09/2016
* @date Modification 06/09/2016
* @description : EM002_Contact Unit Test Class 
*/

@isTest
public class EM002_ContactTest {
    
    public static final String TECH_ContactTechSUNID = '4569872';
    public static final String TECH_WebSiteID = '5483465';
    public static final String PROFESSIONAL_EMAIL = 'ProfessionalEmailTU@carmignac.com';
    public static final String PERSONAL_EMAIL = 'PersonalEmailTU@carmignac.com';
    public static final String TEAM_EMAIL = 'TeamEmailTU@carmignac.com';
    
    public static final String TECH_ContactTechSUNID2 = '4569890';
    public static final String TECH_WebSiteID2 = '5483464';
    public static final String PROFESSIONAL_EMAIL2 = 'ProfessionalEmailTU2@carmignac.com';
    public static final String PERSONAL_EMAIL2 = 'PersonalEmailTU2@carmignac.com';
    public static final String TEAM_EMAIL2 = 'TeamEmailTU2@carmignac.com';
    
    static testMethod void getListContactTest() {
        
        // Data Preparation
        /*Account account = TestFactory.getSimpleAccount();
Insert account;*/
        //  Segmentation__c segmentation = TestFactory.getSimpleSegmentation(account.Id);
        //  Insert segmentation;
        
        Account account = TestFactory.getSimpleAccount();
        insert account;
        
        Contact contact = TestFactory.getSimpleNoProfileContact(account.Id, 'TestFName','LastNameTestCarmignac','65432345','TechwbesiteId','mail@mail1.com','mail@mail1.com','mail@mail1.com');
        
        insert contact;
        
        Contact contact2 = TestFactory.getSimpleNoProfileContact(account.Id, 'TestFName12','LastNameTestCarmignac','654334211','TechwbesiteIdId','mailmail@mail1.com','mailmail@mail1.com','mailmail@mail1.com');
        
        insert contact2; 
        
        Contact contact3 = TestFactory.getSimpleContactToSetProfile(account.Id,'FirstNameTest', 'LastNameTest', TECH_ContactTechSUNID2,TECH_WebSiteID2,PROFESSIONAL_EMAIL2,PERSONAL_EMAIL2,TEAM_EMAIL2);
        Insert contact3;
        /* 
Contact contact = TestFactory.getSimpleNoProfileContact(account.Id,'FirstNameTU', 'LastNameTU', TECH_ContactTechSUNID,TECH_WebSiteID,PROFESSIONAL_EMAIL,PERSONAL_EMAIL,TEAM_EMAIL);
Insert contact;
Contact contact2 = TestFactory.getSimpleContactToSetProfile(account.Id,'FirstNameTest', 'LastNameTest', TECH_ContactTechSUNID2,TECH_WebSiteID2,PROFESSIONAL_EMAIL2,PERSONAL_EMAIL2,TEAM_EMAIL2);
Insert contact2;*/
        
        
        // Test User creation
        // Backup Line Not to Delete
        //User u = TestFactory.getStandardCarmignacUser();
        User u = [Select id from User where Id = :UserInfo.getUserId()];
        // insert u;
        
        // Test Begin
        System.test.startTest();       
        
        System.runAs(u){
            // getListByIds
            List<Contact> found_contactList =  EM002_Contact.getListByIds(new Set<Id>{contact.Id});
            List<Contact> No_contactList =  EM002_Contact.getListByIds(new Set<Id>{'0064E000002WwK4'}); // Inexistant ID for Contact Entity
            
            // getListByTechSunIds
            //    List<Contact> found_contactListByTechSunIds =  EM002_Contact.getListByTechSunIds(new Set<String>{TECH_ContactTechSUNID});
            List<Contact> found_contactListByTechSunIds2 =  EM002_Contact.getListByTechSunIds(new Set<Integer>{Integer.valueOf('65432345')});
            List<Contact> No_contactListByTechSunIds =  EM002_Contact.getListByTechSunIds(new Set<Integer>{15}); // Inexistant TechSunIds for Contact Entity
            
            // getListByTechWebSiteIds
            List<Contact> found_contactListByTechWebSiteIds =  EM002_Contact.getListByTechWebSiteIds(new Set<String>{'TechwbesiteId'});
            List<Contact> No_contactListByTechWebSiteIds =  EM002_Contact.getListByTechWebSiteIds(new Set<String>{'0064E000002WwK4'}); // Inexistant TechWebSiteIds for Contact Entity
            
            // getListByProfessionalEmails_WithoutProSpace
            List<Contact> found_contactListByProfessionalEmails_WithoutProSpace =  EM002_Contact.getListByProfessionalEmails_WithoutProSpace(new Set<String>{'mail@mail1.com'});
            List<Contact> No_contactListByProfessionalEmails_WithoutProSpace =  EM002_Contact.getListByProfessionalEmails_WithoutProSpace(new Set<String>{'ContactTU@Carmignac.com'}); // Inexistant Professional Email for Contact Entity
            
            // getListByPersonalEmails_WithoutProSpace
            List<Contact> found_contactListByPersonalEmails_WithoutProSpace =  EM002_Contact.getListByPersonalEmails_WithoutProSpace(new Set<String>{'mail@mail1.com'});
            List<Contact> No_contactListByPersonalEmails_WithoutProSpace =  EM002_Contact.getListByPersonalEmails_WithoutProSpace(new Set<String>{'ContactTU@Carmignac.com'}); // Inexistant Personnal Email for Contact Entity
            
            // getListByTeamEmails_WithoutProSpace
            List<Contact> found_contactListByTeamEmails_WithoutProSpace =  EM002_Contact.getListByTeamEmails_WithoutProSpace(new Set<String>{'mailmail@mail1.com'});
            List<Contact> No_contactListByTeamEmails_WithoutProSpace =  EM002_Contact.getListByTeamEmails_WithoutProSpace(new Set<String>{'ContactTU@Carmignac.com'}); // Inexistant Team Email for Contact Entity
            
            
            // setProfile
            Contact contactSetProfile =  EM002_Contact.setProfile(contact2);
            Contact No_contactSetProfile =  EM002_Contact.setProfile(contact); // Inexistant Contact Entity
            
            //getTechnicalIDById
            String found_contactTechnicalID =  EM002_Contact.getTechnicalIDById(String.valueOf(contact.Id));
            //   String No_contactTechnicalID =  EM002_Contact.getTechnicalIDById('123456789'); // Inexistant Contact Entity
            
            //getListContactsFromEmails
            List<Contact> found_contactListFromEmails =  EM002_Contact.getListContactsFromEmails(new list<String>{'mailmail@mail1.com','mail@mail1.com'});
            List<Contact> No_contactListFromEmails =  EM002_Contact.getListContactsFromEmails(new list<String>{'testATM@test.com'}); // Inexistant Email for Contact Entity
            
            //setProfile(Contact con)
            //   Contact Contact_Setted_Profile = EM002_Contact.setProfile(contact3);
            
            //updateAfterReset
            EM002_Contact.updateAfterReset(contact3);
            
            // Results verification
            System.assertEquals(found_contactList.size(), 1);
            System.assertEquals(found_contactList.get(0).Id, contact.Id);
            System.assertEquals(No_contactList.size(), 0);
            
            //  System.assertEquals(found_contactListByTechSunIds.size(), 0);
            System.assertEquals(found_contactListByTechSunIds2.size(), 1);
            System.assertEquals(found_contactListByTechSunIds2.get(0).Id, contact.Id);
            System.assertEquals(No_contactListByTechSunIds.size(), 0);
            
            //System.assertEquals(found_contactListByTechWebSiteIds.size(), 1);
            //System.assertEquals(found_contactListByTechWebSiteIds.get(0).Id, contact.Id);
            System.assertEquals(No_contactListByTechWebSiteIds.size(), 0);
            
            //System.assertEquals(found_contactListByProfessionalEmails_WithoutProSpace.size(), 1);
            //System.assertEquals(found_contactListByProfessionalEmails_WithoutProSpace.get(0).Id, contact.Id);
            System.assertEquals(No_contactListByProfessionalEmails_WithoutProSpace.size(), 0);
            
            System.assertEquals(found_contactListByPersonalEmails_WithoutProSpace.size(), 1);
            System.assertEquals(found_contactListByPersonalEmails_WithoutProSpace.get(0).Id, contact.Id);
            System.assertEquals(No_contactListByPersonalEmails_WithoutProSpace.size(), 0);
            
            System.assertEquals(found_contactListByTeamEmails_WithoutProSpace.size(), 1);
            System.assertEquals(found_contactListByTeamEmails_WithoutProSpace.get(0).Id, contact2.Id);
            System.assertEquals(No_contactListByTeamEmails_WithoutProSpace.size(), 0);
            
            System.assertEquals(contactSetProfile.Id, contact2.Id);
            System.assertEquals(No_contactSetProfile.firstName, 'TestFName');
            
            System.assertEquals(found_contactTechnicalID, String.valueof(contact.Technical_ID__c));
            //    System.assertEquals(Decimal.valueOf(No_contactTechnicalID), 0.0);
            
            System.assertEquals(found_contactListFromEmails.size(), 2);
            System.assertEquals(found_contactListFromEmails.get(0).Id, contact.Id);
            System.assertEquals(No_contactListFromEmails.size(), 0);
            
            //    System.assertEquals(Contact_Setted_Profile.Id, contact3.Id);
            
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
}