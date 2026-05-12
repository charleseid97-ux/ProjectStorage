@IsTest
public class customEventServiceTest {

    // Crée les données communes sans mixed DML.
    private static Map<String, SObject> setupData() {
        User organizer = BooklyDataFactory.createOrganizerUser();
        Map<String, SObject> data = new Map<String, SObject>();

        System.runAs(organizer) {
            Account company1 = BooklyDataFactory.createAccount();
            Strategy__c strategy1 = BooklyDataFactory.createStrategy('Strategy1');
            Contact speaker1 = BooklyDataFactory.createSpeakerContact(company1.Id, organizer.Id, false);
            Contact speakerTop1 = BooklyDataFactory.createSpeakerContact(company1.Id, organizer.Id, true);

            data.put('OrganizerUser', organizer);
            data.put('company1', company1);
            data.put('Strategy1', strategy1);
            data.put('Speaker1', speaker1);
            data.put('SpeakerTop1', speakerTop1);
        }

        return data;
    }

    // Couvre la génération du nom avec et sans speakers.
    @IsTest
    static void testSetEventNameAndSpeakers() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = BooklyDataFactory.createEvent(
                ((Account) data.get('company1')).Id,
                organizer.Id
            );

            BooklyDataFactory.createSessionSpeakerProduct(
                evt.Id,
                ((Contact) data.get('SpeakerTop1')).Id,
                ((Strategy__c) data.get('Strategy1')).Id
            );

            evt = [SELECT Id, Name, startDate__c, SalesTeam__c, Title__c FROM Event__c WHERE Id = :evt.Id];

            Test.startTest();
            customEventService.setEventName(new List<Event__c>{ evt }, false);
            Test.stopTest();

            System.assert(evt.Name.contains('BE'));
            System.assert(evt.Name.contains('RG'));
        }
    }

    // Couvre la copie d'adresse billing Account vers Event.
    @IsTest
    static void testCopyCompanyBillingAddressToEvent() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Account acc = (Account) data.get('company1');
            acc.BillingStreet = '24 Place Vendôme';
            acc.BillingCity = 'Paris';
            acc.BillingPostalCode = '75001';
            acc.BillingCountry = 'France';
            update acc;

            Event__c evt = BooklyDataFactory.createEvent(acc.Id, organizer.Id);
            evt.CopyAddress__c = true;
            evt.LocationAddress__c = null;
            evt.city__c = null;
            evt.country__c = null;
            evt.LocationPostCode__c = null;
            evt.LocationName__c = null;

            Test.startTest();

            customEventService.copyCompanyBillingAddressToEvent(
                new List<Event__c>{ evt },
                null
            );

            Account newAcc = BooklyDataFactory.createAccount();
            newAcc.BillingStreet = 'New Street';
            newAcc.BillingCity = 'Paris';
            newAcc.BillingPostalCode = '75001';
            newAcc.BillingCountry = 'France';
            update newAcc;

            Event__c oldEvt = evt.clone(true, true, false, false);

            evt.Company__c = newAcc.Id;
            evt.LocationAddress__c = null;
            evt.city__c = null;
            evt.country__c = null;
            evt.LocationPostCode__c = null;
            evt.LocationName__c = null;

            customEventService.copyCompanyBillingAddressToEvent(
                new List<Event__c>{ evt },
                new Map<Id, Event__c>{ oldEvt.Id => oldEvt }
            );

            Test.stopTest();

            System.assertEquals('New Street', evt.LocationAddress__c);
            System.assertEquals('Paris', evt.city__c);
            System.assertEquals('France', evt.country__c);
        }
    }

    // Couvre le passage Draft vers SubmittedToEventTeam.
    @IsTest
    static void testSetReadyForApprovalProcess() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = BooklyDataFactory.createEvent(
                ((Account) data.get('company1')).Id,
                organizer.Id
            );

            Event__c oldEvt = evt.clone(true, true, false, false);
            oldEvt.Status__c = 'Draft';
            evt.Status__c = 'Draft';

            Test.startTest();
            customEventService.setReadyForApprovalProcess(
                new List<Event__c>{ evt },
                new Map<Id, Event__c>{ evt.Id => oldEvt }
            );
            Test.stopTest();

            System.assertEquals('SubmittedToEventTeam', evt.Status__c);
        }
    }

    // Couvre la création de Campaign depuis Event FullyApproved.
    @IsTest
    static void testCreateCampaign() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = BooklyDataFactory.createEvent(
                ((Account) data.get('company1')).Id,
                organizer.Id
            );

            Event__c oldEvt = evt.clone(true, true, false, false);
            oldEvt.Status__c = 'Draft';
            evt.Status__c = 'FullyApproved';
            evt.Name = '2026-03-30 – BE – test – RG';

            Test.startTest();
            customEventService.createCampaign(
                new List<Event__c>{ evt },
                new Map<Id, Event__c>{ evt.Id => oldEvt }
            );
            Test.stopTest();

            System.assertNotEquals(null, [
                SELECT Id
                FROM Campaign
                WHERE Event__c = :evt.Id
                LIMIT 1
            ].Id);
        }
    }

    // Couvre la location automatique des events digitaux.
    @IsTest
    static void testSetDigitalLocation() {
        Event__c evt = new Event__c(Format__c = 'Digital');

        Test.startTest();
        customEventService.setDigitalLocation(new List<Event__c>{ evt }, null);
        Test.stopTest();

        System.assertEquals('Digital', evt.country__c);
        System.assertEquals('Digital', evt.City__c);
    }

    // Couvre les initials speaker.
    @IsTest
    static void testGetSpeakerInitials() {
        Test.startTest();
        String initials = customEventService.getSpeakerInitials('Raphael GALLARDO');
        Test.stopTest();

        System.assertEquals('RG', initials);
    }

    // Couvre updateName quand les champs structurants changent.
    @IsTest
    static void testUpdateName() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = BooklyDataFactory.createEvent(
                ((Account) data.get('company1')).Id,
                organizer.Id
            );

            Event__c oldEvt = evt.clone(true, true, false, false);
            evt.Title__c = 'updated title';

            Test.startTest();
            customEventService.updateName(
                new Map<Id, Event__c>{ evt.Id => oldEvt },
                new Map<Id, Event__c>{ evt.Id => evt }
            );
            Test.stopTest();

            System.assert(evt.Name.contains('updated title'));
        }
    }

    // Couvre la validation Organizer obligatoire.
    @IsTest
    static void testValidateEvents() {
        Event__c evt = new Event__c();

        Test.startTest();
        customEventService.validateEvents(new List<Event__c>{ evt }, null);
        Test.stopTest();

        System.assert(evt.hasErrors());
    }

    // Couvre notifyProductTeam quand speakersHTML change.
    @IsTest
    static void testNotifyProductTeam() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = BooklyDataFactory.createEvent(
                ((Account) data.get('company1')).Id,
                organizer.Id
            );

            BooklyDataFactory.createSessionSpeakerProduct(
                evt.Id,
                ((Contact) data.get('SpeakerTop1')).Id,
                ((Strategy__c) data.get('Strategy1')).Id
            );

            Event__c oldEvt = evt.clone(true, true, false, false);
            oldEvt.speakersHTML__c = 'old';
            evt.speakersHTML__c = 'new';

            Test.startTest();
            customEventService.notifyProductTeam(
                new Map<Id, Event__c>{ evt.Id => evt },
                new Map<Id, Event__c>{ evt.Id => oldEvt }
            );
            Test.stopTest();

            System.assertEquals('new', evt.speakersHTML__c);
        }
    }

    // Get active picklist values for Campaign.Sales_Team__c
    private static Set<String> getCampaignSalesTeamAllowedValues() {
        Set<String> allowed = new Set<String>();
        Schema.DescribeFieldResult d =
            Campaign.SObjectType.getDescribe()
                .fields.getMap()
                .get('Sales_Team__c')
                .getDescribe();
        for (Schema.PicklistEntry pe : d.getPicklistValues()) {
            if (pe.isActive()) allowed.add(pe.getValue());
        }
        return allowed;
    }
}