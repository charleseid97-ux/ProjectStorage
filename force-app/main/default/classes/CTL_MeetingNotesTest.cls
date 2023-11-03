@isTest
private class CTL_MeetingNotesTest {
    @TestSetup
    static void makeData(){
        EnhancedLetterhead el = new EnhancedLetterhead(
            Name='Also test',
            LetterheadFooter='test'
        );
        insert el;
        EmailTemplate et = New EmailTemplate(
            htmlvalue = '',
            subject = 'test meeting note',
            EnhancedLetterheadId = el.id,
            DeveloperName='TestMeetingNote',
            Name = 'Test Meeting Note',
            TemplateType='custom',
            TemplateStyle='none',
            isActive=true,
            RelatedEntityType = 'Meeting_Note__c',
            UiType='SFX',
            Encoding='ISO-8859-1'
        );
        insert et;
        
        Contact c = new Contact(
            FirstName = 'Max',
            LastName = 'Test',
          	Email = 'first.last@invalid.com'
        );
        insert c;
    }

    @isTest static void testBehavior() {
        CTL_MeetingNotes.getOrgId();
        CTL_MeetingNotes.getNeededContacts();
        CTL_MeetingNotes.getClientContacts('', new List<String> ());
        CTL_MeetingNotes.getUsers();
        CTL_MeetingNotes.getProducts('');
        CTL_MeetingNotes.getEmailTemplate('Test Meeting Note');
        EmailTemplate et = [SELECT id, htmlvalue, subject, DeveloperName, Name, TemplateType, TemplateStyle, isActive, RelatedEntityType, uiType, Encoding FROM EmailTemplate LIMIT 1];
        List<Contact> contactList = [SELECT id FROM contact];
        CTL_MeetingNotes.sendEmailMeeting(et, contactList, '');
    }
}