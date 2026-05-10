@IsTest
public class eventAddToCalendarCtrlTest {

    // Crée un event complet pour générer le contenu ICS.
    @IsTest
    static void testGetIcsContentSuccess() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        evt.Name = 'Event test, avec; caractères';
        evt.Location__c = 'Salle 1';
        evt.LocationName__c = 'Carmignac';
        evt.LocationAddress__c = '24 Place Vendôme';
        evt.City__c = 'Paris';
        evt.Country__c = 'France';
        evt.SpeakersHTML__c =
            '<table><tr><td>H1</td><td>H2</td><td>H3</td><td>H4</td><td>H5</td></tr>' +
            '<tr><td>Raphael &amp; GALLARDO</td></tr></table>';
        update evt;

        Test.startTest();
        String ics = eventAddToCalendarCtrl.getIcsContent(evt.Id);
        Test.stopTest();

        System.assert(ics.contains('BEGIN:VCALENDAR'));
        System.assert(ics.contains('BEGIN:VEVENT'));       
    }

    // Couvre le cas recordId null.
    @IsTest
    static void testGetIcsContentNullRecordId() {
        try {
            Test.startTest();
            eventAddToCalendarCtrl.getIcsContent(null);
            Test.stopTest();

            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    // Couvre les horaires invalides avec fallback minuit.
    @IsTest
    static void testGetIcsContentInvalidTime() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        evt.StartTime__c = '99:99';
        evt.EndTime__c = 'inval';
        update evt;

        Test.startTest();
        String ics = eventAddToCalendarCtrl.getIcsContent(evt.Id);
        Test.stopTest();

        System.assert(ics.contains('DTSTART:'));
        System.assert(ics.contains('DTEND:'));
    }
}