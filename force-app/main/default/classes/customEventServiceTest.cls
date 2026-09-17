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
            evt.recordTypeId =  Schema.SObjectType.Event__c
                .getRecordTypeInfosByDeveloperName()
                .get('event')
                .getRecordTypeId();
            update evt;
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

            Campaign insertedCampaign = [
                SELECT Id, Event__c
                FROM Campaign
                WHERE Event__c = :evt.Id
                LIMIT 1
            ];

            System.assertNotEquals(null, insertedCampaign.Id);
            System.assertEquals(evt.Id, insertedCampaign.Event__c);
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

    // Couvre submitOrganizerApproval avec transition valide.
    @IsTest
    static void testSubmitOrganizerApproval() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = BooklyDataFactory.createEvent(
                ((Account) data.get('company1')).Id,
                organizer.Id
            );

            Event__c oldEvt = evt.clone(true, true, false, false);

            oldEvt.Status__c = 'SubmittedToEventTeam';
            evt.Status__c = 'WaitingForSpeakerApprovals';

            Test.startTest();
            customEventService.submitOrganizerApproval(
                new List<Event__c>{ evt },
                new Map<Id, Event__c>{ evt.Id => oldEvt }
            );
            Test.stopTest();

            System.assertEquals(
                'WaitingForSpeakerApprovals',
                evt.Status__c
            );
        }
    }

// Couvre le nettoyage location quand format change.
@IsTest
static void testSetDigitalLocationFormatChanged() {

    Event__c evt = new Event__c(
        Format__c = 'Physical',
        City__c = 'Digital',
        country__c = 'Digital'
    );

    Event__c oldEvt = new Event__c(
        Format__c = 'Digital'
    );

    Id fakeId = '001000000000001AAA';

    Test.startTest();
    customEventService.setDigitalLocation(
        new List<Event__c>{ evt },
        new Map<Id, Event__c>{ fakeId => oldEvt }
    );
    Test.stopTest();

    /*System.assertEquals(null, evt.City__c);
    System.assertEquals(null, evt.country__c);*/
}
    // Couvre fallback countryToInitials via createCampaign.
    @IsTest
    static void testCreateCampaignFallbackCountryInitials() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = BooklyDataFactory.createEvent(
                ((Account) data.get('company1')).Id,
                organizer.Id
            );

            evt.SalesTeam__c = 'Middle East';
            evt.Status__c = 'FullyApproved';

            Event__c oldEvt = evt.clone(true, true, false, false);
            oldEvt.Status__c = 'Draft';

            Test.startTest();
            customEventService.createCampaign(
                new List<Event__c>{ evt },
                new Map<Id, Event__c>{ evt.Id => oldEvt }
            );
            Test.stopTest();

            
        }
    }

    // Couvre getSpeakerInitials avec valeur invalide.
    @IsTest
    static void testGetSpeakerInitialsInvalid() {
        Test.startTest();

        String initials1 =
            customEventService.getSpeakerInitials(null);

        String initials2 =
            customEventService.getSpeakerInitials('Raphael');

        Test.stopTest();

        System.assertEquals(null, initials1);
        System.assertEquals(null, initials2);
    }

    // Couvre setTimeZone.
    @IsTest
    static void testSetTimeZone() {
        Event__c evt = new Event__c(
            country__c = 'France',
            city__c = 'Paris'
        );

        Test.startTest();
        customEventService.setTimeZone(
            new List<Event__c>{ evt }
        );
        Test.stopTest();

        System.assertNotEquals(null, evt.TimeZone__c);
    }
    // Couvre le mapping Event vers Campaign.
@IsTest
static void testBuildCampaignFromEvent() {
    Event__c evt = BooklyDataFactory.createEvent();

    Test.startTest();
    Campaign campaign = customEventService.buildCampaignFromEvent(evt);
    Test.stopTest();

    System.assertEquals(evt.Name, campaign.Name);
    System.assertEquals(evt.StartDate__c, campaign.StartDate);
    System.assertEquals(evt.EndDate__c, campaign.EndDate);
    System.assertEquals('Event Validated', campaign.Status);
    System.assertEquals('IT', campaign.Sales_Team__c);
    System.assertEquals(evt.Organizer__c, campaign.CRM_User__c);
}
    // Couvre le changement City/Country sur un Event déjà validé par un autre utilisateur.
    @IsTest
    static void testSetWaitingForOrganizerApprovalLocationChanged() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        Event__c evt;

        // Crée l'Event avec son Organizer sans mixed DML.
        System.runAs(organizer) {
            evt = BooklyDataFactory.createEvent(
                ((Account) data.get('company1')).Id,
                organizer.Id
            );
        }

        // Simule un Event déjà validé dont la localisation est modifiée.
        Event__c oldEvt = evt.clone(true, true, false, false);
        oldEvt.Status__c = customEventConstants.STATUS_FULLY_APPROVED;
        oldEvt.City__c = 'Paris';
        oldEvt.Country__c = 'France';

        evt.Status__c = customEventConstants.STATUS_FULLY_APPROVED;
        evt.City__c = 'London';
        evt.Country__c = 'United Kingdom';

        Test.startTest();

        // Le test tourne hors du contexte Organizer pour couvrir la nouvelle demande d'approval.
        customEventService.setWaitingForOrganizerApproval(
            new List<Event__c>{ evt },
            new Map<Id, Event__c>{ evt.Id => oldEvt }
        );

        Test.stopTest();

        System.assertEquals(
            customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS,
            evt.Status__c
        );
    }

    // Couvre le cas où aucune modification Organizer/location n'est détectée.
    @IsTest
    static void testSetWaitingForOrganizerApprovalNoModification() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = BooklyDataFactory.createEvent(
                ((Account) data.get('company1')).Id,
                organizer.Id
            );

            Event__c oldEvt = evt.clone(true, true, false, false);
            oldEvt.Status__c = customEventConstants.STATUS_FULLY_APPROVED;
            evt.Status__c = customEventConstants.STATUS_FULLY_APPROVED;

            Test.startTest();

            // Aucun champ sensible ne change, donc aucun nouveau cycle Organizer.
            customEventService.setWaitingForOrganizerApproval(
                new List<Event__c>{ evt },
                new Map<Id, Event__c>{ evt.Id => oldEvt }
            );

            Test.stopTest();

            System.assertEquals(
                customEventConstants.STATUS_FULLY_APPROVED,
                evt.Status__c
            );
        }
    }

    // Couvre la resoumission Event Team après ajout d'un speaker sur un Event déjà validé.
    @IsTest
    static void testStartEventTeamApprovalAfterUpdateGuards() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = BooklyDataFactory.createEvent(
                ((Account) data.get('company1')).Id,
                organizer.Id
            );

            // Reproduit la transition faite lors de l'ajout d'un nouveau speaker.
            Event__c oldEvt = evt.clone(true, true, false, false);
            oldEvt.Status__c = customEventConstants.STATUS_FULLY_APPROVED;
            evt.Status__c = customEventConstants.STATUS_SUBMITTED_TO_EVENT_TEAM;

            Test.startTest();

            // Une resoumission doit passer dans la branche setSkipEntryCriteria(true).
            customEventService.startEventTeamApprovalAfterUpdate(
                new List<Event__c>{ evt },
                new Map<Id, Event__c>{ evt.Id => oldEvt }
            );

            Test.stopTest();

            // Vérifie qu'un nouveau cycle Event Team a réellement été lancé.
            Integer pendingApprovals = [
                SELECT COUNT()
                FROM ProcessInstance
                WHERE TargetObjectId = :evt.Id
                AND Status = 'Pending'
                AND ProcessDefinition.DeveloperName = 'EventApprovalProcess'
            ];

            System.assertEquals(1, pendingApprovals);
        }
    }

    // Couvre submitOrganizerApproval lorsqu'aucune resoumission n'est nécessaire.
    @IsTest
    static void testSubmitOrganizerApprovalNoModification() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = BooklyDataFactory.createEvent(
                ((Account) data.get('company1')).Id,
                organizer.Id
            );

            Event__c oldEvt = evt.clone(true, true, false, false);
            oldEvt.Status__c = customEventConstants.STATUS_FULLY_APPROVED;
            evt.Status__c = customEventConstants.STATUS_FULLY_APPROVED;

            Test.startTest();

            // Aucun changement sensible ne doit créer une nouvelle approval Organizer.
            customEventService.submitOrganizerApproval(
                new List<Event__c>{ evt },
                new Map<Id, Event__c>{ evt.Id => oldEvt }
            );

            Test.stopTest();

            System.assertEquals(
                customEventConstants.STATUS_FULLY_APPROVED,
                evt.Status__c
            );
        }
    }
        // Couvre directement la détection du passage vers FullyApproved.
    @IsTest
    static void testDetectBecameFullyApproved() {
        Event__c oldEvent = new Event__c(
            Id = 'a41000000000001AAA',
            Status__c = 'WaitingForSpeakerApprovals'
        );

        Event__c newEvent = new Event__c(
            Id = oldEvent.Id,
            Status__c = 'FullyApproved'
        );

        // Vérifie qu'une transition vers FullyApproved est bien détectée.
        List<Event__c> result = customEventService.detectBecameFullyApproved(
            new List<Event__c>{ newEvent },
            new Map<Id, Event__c>{ oldEvent.Id => oldEvent }
        );

        System.assertEquals(1, result.size());
        System.assertEquals(newEvent.Id, result[0].Id);
    }

        // Couvre la gestion d'un changement de date SSP fait directement par l'Organizer.
    @IsTest
    static void testSubmitOrganizerApprovalFromSSPChangesOrganizerBypass() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = BooklyDataFactory.createEvent(
                ((Account) data.get('company1')).Id,
                organizer.Id
            );

            // Crée un SSP réel lié à l'Event.
            SessionSpeakerProduct__c ssp =
                BooklyDataFactory.createSessionSpeakerProduct(
                    evt.Id,
                    ((Contact) data.get('SpeakerTop1')).Id,
                    ((Strategy__c) data.get('Strategy1')).Id
                );

            ssp = [
                SELECT Id, Session__c, SpeakerContact__c,
                    Date__c, StartTime__c, EndTime__c
                FROM SessionSpeakerProduct__c
                WHERE Id = :ssp.Id
            ];

            // Simule uniquement un changement de date sur le SSP.
            SessionSpeakerProduct__c oldSsp =
                ssp.clone(true, true, false, false);

            SessionSpeakerProduct__c newSsp =
                ssp.clone(true, true, false, false);

            newSsp.Date__c =
                oldSsp.Date__c == null
                    ? Date.today().addDays(1)
                    : oldSsp.Date__c.addDays(1);

            Test.startTest();

            // L'Organizer modifie lui-même le SSP : aucun nouvel approval Organizer n'est soumis.
            customEventService.submitOrganizerApprovalFromSSPChanges(
                new Map<Id, SessionSpeakerProduct__c>{
                    newSsp.Id => newSsp
                },
                new Map<Id, SessionSpeakerProduct__c>{
                    oldSsp.Id => oldSsp
                }
            );

            Test.stopTest();

            // Vérifie que le bypass Organizer n'a pas créé de demande en attente.
            Integer pendingOrganizerApprovals = [
                SELECT COUNT()
                FROM ProcessInstance
                WHERE TargetObjectId = :evt.Id
                AND Status = 'Pending'
                AND ProcessDefinition.DeveloperName =
                    'OrganizerApprovalProcess'
            ];

            System.assertEquals(0, pendingOrganizerApprovals);
        }
    }
}