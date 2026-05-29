@IsTest
public class VFC17_PrintEventsTest {

    // Crée deux events avec le même speaker au même créneau pour couvrir les conflits.
    private static Map<String, SObject> setupData() {
        User organizer = BooklyDataFactory.createOrganizerUser();
        Map<String, SObject> data = new Map<String, SObject>();

        System.runAs(organizer) {
            Account company1 = BooklyDataFactory.createAccount();
            Strategy__c strategy1 = BooklyDataFactory.createStrategy('Strategy1');
            Contact speakerTop1 = BooklyDataFactory.createSpeakerContact(company1.Id, organizer.Id, true);

            Event__c event1 = BooklyDataFactory.createEvent(company1.Id, organizer.Id);
            event1.Title__c = 'Printable Event 1';
            event1.StartDate__c = Date.today();
            event1.EndDate__c = Date.today();
            event1.StartTime__c = '09:00';
            event1.EndTime__c = '10:00';
            event1.SalesTeam__c = 'Belgium';
            update event1;

            Event__c event2 = BooklyDataFactory.createEvent(company1.Id, organizer.Id);
            event2.Title__c = 'Printable Event 2';
            event2.StartDate__c = Date.today();
            event2.EndDate__c = Date.today();
            event2.StartTime__c = '09:00';
            event2.EndTime__c = '10:00';
            event2.SalesTeam__c = 'Belgium';
            update event2;

            BooklyDataFactory.createSessionSpeakerProduct(event1.Id, speakerTop1.Id, strategy1.Id);
            BooklyDataFactory.createSessionSpeakerProduct(event2.Id, speakerTop1.Id, strategy1.Id);

            data.put('OrganizerUser', organizer);
            data.put('company1', company1);
            data.put('Strategy1', strategy1);
            data.put('SpeakerTop1', speakerTop1);
            data.put('Event1', event1);
            data.put('Event2', event2);
        }

        return data;
    }

    // Couvre le constructeur avec paramètres URL et données imprimables.
    @IsTest
    static void testConstructorWithEvents() {
        setupData();

        Test.setCurrentPage(new PageReference('/apex/VFC17_PrintEvents'));
        ApexPages.currentPage().getParameters().put('start', String.valueOf(Date.today().addDays(-1)));
        ApexPages.currentPage().getParameters().put('end', String.valueOf(Date.today().addDays(1)));
        ApexPages.currentPage().getParameters().put('salesTeam', 'Belgium');

        Test.startTest();
        VFC17_PrintEvents ctrl = new VFC17_PrintEvents();
        Test.stopTest();

        System.assertEquals(false, ctrl.pages.isEmpty());
        System.assertEquals('Belgium', ctrl.selectedSalesTeam);
        System.assertEquals(false, ctrl.salesTeamOptions.isEmpty());
    }

    // Couvre applyDates avec inversion start/end.
    @IsTest
    static void testApplyDatesNormalizesRange() {
        setupData();

        Test.setCurrentPage(new PageReference('/apex/VFC17_PrintEvents'));

        VFC17_PrintEvents ctrl = new VFC17_PrintEvents();
        ctrl.startDate = Date.today().addDays(10);
        ctrl.endDate = Date.today();

        Test.startTest();
        PageReference result = ctrl.applyDates();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assert(ctrl.startDate <= ctrl.endDate);
        System.assertEquals(false, ctrl.pages.isEmpty());
    }

    // Couvre openPdf et les paramètres générés.
    @IsTest
    static void testOpenPdf() {
        setupData();

        Test.setCurrentPage(new PageReference('/apex/VFC17_PrintEvents'));

        VFC17_PrintEvents ctrl = new VFC17_PrintEvents();
        ctrl.startDate = Date.today();
        ctrl.endDate = Date.today().addDays(1);
        ctrl.selectedSalesTeam = 'Belgium';

        Test.startTest();
        PageReference pr = ctrl.openPdf();
        Test.stopTest();

        System.assertEquals('1', pr.getParameters().get('pdf'));
        System.assertEquals('Belgium', pr.getParameters().get('salesTeam'));
    }

    // Couvre le getter isPdf.
    @IsTest
    static void testIsPdfGetter() {
        Test.setCurrentPage(new PageReference('/apex/VFC17_PrintEvents'));
        ApexPages.currentPage().getParameters().put('pdf', '1');

        Test.startTest();
        VFC17_PrintEvents ctrl = new VFC17_PrintEvents();
        Test.stopTest();

        System.assertEquals(true, ctrl.isPdf);
    }
}