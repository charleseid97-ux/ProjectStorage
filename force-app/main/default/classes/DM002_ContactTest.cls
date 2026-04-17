@isTest
public class DM002_ContactTest {
    
    
    static testMethod void testSoql(){
        
        List<Contact> listContact = new List<Contact>();
        Set<Id> setcontactId = new Set<id>();
        Set<Integer> setcontactTechSunId = new Set<Integer>();
        Set<String> setContactWebSiteIds = new Set<String>();
        Set<String> setContactProfessionalEmails = new Set<String>();
        List<String> listEmails = new List<String>();
        list<String> listContactId = new List<String>();

        
        Contact contact2 = new Contact();
        contact2.Email = 'fabien.braconnier@jlconsulting.fr';
        contact2.LastName = 'Braconnier';
        contact2.Firstname = 'Fabien';
        contact2.WebsiteRole__c = '6';
        contact2.TrialStatus__c = '5';
        contact2.WebsiteJobTitle__c = 'test';
        contact2.Technical_ID__c = 23467;
        listContact.add(contact2);
        
        Database.insert(listContact, false);
        
        for(Contact c : listContact){
            setcontactId.add(c.id);
            setcontactTechSunId.add(c.Technical_ID__c.intValue());
            setContactWebSiteIds.add(c.WebsiteJobTitle__c);
            setContactProfessionalEmails.add(c.Email);
            listEmails.add(c.Email);
            listContactId.add(c.id);
        }
        
        
        System.Test.startTest();
        
        List<Contact> listContactTest = DM002_Contact.getListByIds(setcontactId);
        List<Contact> listContactTechID = DM002_Contact.getListByTechSunIds(setcontactTechSunId);
        List<Contact> listContactwabsiteID = DM002_Contact.getListByTechWebSiteIds(setContactWebSiteIds);
        List<Contact> listContactProfessionalEmail = DM002_Contact.getListByProfessionalEmails_WithoutProSpace(setContactProfessionalEmails);
        List<Contact> listContactPersonnalEmail = DM002_Contact.getListByPersonalEmails_WithoutProSpace(setContactProfessionalEmails);
        List<Contact> listContactTeamEmailEmail = DM002_Contact.getListByTeamEmails_WithoutProSpace(setContactProfessionalEmails);
		List<Contact> listContactEmail = DM002_Contact.getListContactsFromEmails(listEmails);
        //String contactIdfromTechId = DM002_Contact.getFromgetTechnicalIdById(listContactId);

        
        System.Test.stopTest();
        
    }
}