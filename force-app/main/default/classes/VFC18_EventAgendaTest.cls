@IsTest
public class VFC18_EventAgendaTest {

    // Crée les données parent, child, attendee et speaker pour l'agenda.
    private static Map<String, SObject> setupData() {
        User organizer = BooklyDataFactory.createOrganizerUser();
        Map<String, SObject> data = new Map<String, SObject>();

        System.runAs(organizer) {
            Account company1 = BooklyDataFactory.createAccount();
            Strategy__c strategy1 = BooklyDataFactory.createStrategy('Strategy1');
            Contact speaker1 = BooklyDataFactory.createSpeakerContact(company1.Id, organizer.Id, false);
            Contact speakerTop1 = BooklyDataFactory.createSpeakerContact(company1.Id, organizer.Id, true);

            Event__c parentEvt = BooklyDataFactory.createEvent(company1.Id, organizer.Id);
            parentEvt.Title__c = 'Parent Event';
            parentEvt.MeetingBackground__c = 'Parent background';
            parentEvt.MeetingGoal__c = 'Parent goal';
            update parentEvt;

            Event__c childEvt = BooklyDataFactory.createEvent(company1.Id, organizer.Id);
            childEvt.Title__c = 'Child Meeting';
            childEvt.ParentEvent__c = parentEvt.Id;
            childEvt.StartDate__c = Date.today().addDays(1);
            childEvt.EndDate__c = Date.today().addDays(1);
            childEvt.StartTime__c = '09:00';
            childEvt.EndTime__c = '10:00';
            childEvt.Timezone__c = 'UTC+00';
            childEvt.MeetingBackground__c = 'Child background';
            childEvt.MeetingGoal__c = 'Child goal';
            update childEvt;

            BooklyDataFactory.createEventAttendee(childEvt.Id, speaker1.Id);
            BooklyDataFactory.createSessionSpeakerProduct(childEvt.Id, speakerTop1.Id, strategy1.Id);

            data.put('OrganizerUser', organizer);
            data.put('company1', company1);
            data.put('Strategy1', strategy1);
            data.put('Speaker1', speaker1);
            data.put('SpeakerTop1', speakerTop1);
            data.put('ParentEvent', parentEvt);
            data.put('ChildEvent', childEvt);
        }

        return data;
    }

    // Couvre le constructeur sans paramètre EventId.
    @IsTest
    static void testMissingEventId() {
        Test.setCurrentPage(new PageReference('/apex/VFC18_EventAgenda'));

        Test.startTest();
        VFC18_EventAgenda ctrl = new VFC18_EventAgenda();
        Test.stopTest();

        System.assertEquals('Missing required URL parameter: EventId', ctrl.errorMessage);
        System.assertEquals(true, ctrl.days.isEmpty());
    }

    // Couvre le chargement complet de l'agenda avec parent, enfant, attendee et speaker.
    @IsTest
    static void testLoadAgendaWithData() {
        Map<String, SObject> data = setupData();
        Event__c parentEvt = (Event__c) data.get('ParentEvent');

        Test.setCurrentPage(new PageReference('/apex/VFC18_EventAgenda'));
        ApexPages.currentPage().getParameters().put('EventId', String.valueOf(parentEvt.Id));
        ApexPages.currentPage().getParameters().put('SMN', 'true');

        Test.startTest();
        VFC18_EventAgenda ctrl = new VFC18_EventAgenda();
        Test.stopTest();

        System.assertEquals(parentEvt.Id, ctrl.parentEventId);
        System.assertEquals(true, ctrl.showMeetingNote);
        System.assertEquals(true, ctrl.isAgendaAvailable);
        System.assertNotEquals(null, ctrl.parent);
        System.assertEquals(false, ctrl.days.isEmpty());
        System.assertEquals(false, ctrl.days[0].rows.isEmpty());
        System.assertEquals('Child Meeting', ctrl.days[0].rows[0].title);
    }

    // Couvre le cas agenda expiré.
    @IsTest
    static void testAgendaExpired() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');
        Event__c parentEvt = (Event__c) data.get('ParentEvent');

        System.runAs(organizer) {
            parentEvt.EndDate__c = Date.today().addDays(-100);
            update parentEvt;
        }

        Test.setCurrentPage(new PageReference('/apex/VFC18_EventAgenda'));
        ApexPages.currentPage().getParameters().put('EventId', String.valueOf(parentEvt.Id));

        Test.startTest();
        VFC18_EventAgenda ctrl = new VFC18_EventAgenda();
        Test.stopTest();

        System.assertEquals(false, ctrl.isAgendaAvailable);
        System.assertNotEquals('', ctrl.agendaAvailableUntilLabel);
    }
}