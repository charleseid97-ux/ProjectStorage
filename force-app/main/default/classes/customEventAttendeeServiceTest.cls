@IsTest
private class customEventAttendeeServiceTest {

    private static Id fakeEventId() {
        return (Id)(Event__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001');
    }

    @IsTest
    static void testCopyAddressEntryPoints() {
        customEventAttendeeService.isRunning = true;
        customEventAttendeeService.copyAddressToEventsFromAttendees(new List<EventAttendee__c>());
        customEventAttendeeService.isRunning = false;

        customEventAttendeeService.copyAddressToEventsFromAttendees(null);
        customEventAttendeeService.copyAddressToEventsFromAttendees(new List<EventAttendee__c>());
        customEventAttendeeService.copyAddressToEventsFromAttendees(new List<EventAttendee__c>{ new EventAttendee__c() });

        System.assert(true);
    }

    @IsTest
    static void testQueryMethods() {
        User u = BooklyDataFactory.createOrganizerUser();
        Account acc = BooklyDataFactory.createAccount();
        Contact c = BooklyDataFactory.createSpeakerContact(acc.Id, u.Id, false);
        Event__c ev = BooklyDataFactory.createEvent(acc.Id, u.Id);

        System.assertEquals(0, customEventAttendeeService.queryEvents(null).size());
        System.assertEquals(0, customEventAttendeeService.queryContacts(null).size());

        System.assertEquals(1, customEventAttendeeService.queryEvents(new Set<Id>{ ev.Id }).size());
        System.assertEquals(1, customEventAttendeeService.queryContacts(new Set<Id>{ c.Id }).size());
    }

    @IsTest
    static void testFilterEligibleEventIds() {
        Id evId = fakeEventId();

        Event__c ev = new Event__c(
            Id = evId,
            CopyAddress__c = true,
            LocationAddress__c = null,
            city__c = null,
            country__c = null,
            LocationPostCode__c = null,
            LocationName__c = null
        );

        Set<Id> ids = customEventAttendeeService.filterEligibleEventIds(
            new Map<Id, Event__c>{ evId => ev }
        );

        System.assertEquals(true, ids.contains(evId));

        ev.CopyAddress__c = false;
        ids = customEventAttendeeService.filterEligibleEventIds(
            new Map<Id, Event__c>{ evId => ev }
        );

        System.assertEquals(0, ids.size());

        System.assertEquals(0, customEventAttendeeService.filterEligibleEventIds(null).size());
        System.assertEquals(0, customEventAttendeeService.filterEligibleEventIds(new Map<Id, Event__c>()).size());
    }

    @IsTest
    static void testChooseFirstValidAccountPerEvent() {
        User u = BooklyDataFactory.createOrganizerUser();

        Account acc = BooklyDataFactory.createAccount();
        acc.BillingStreet = 'Street';
        update acc;

        Contact c1 = BooklyDataFactory.createSpeakerContact(acc.Id, u.Id, false);
        Contact c2 = BooklyDataFactory.createSpeakerContact(acc.Id, u.Id, false);

        Id evId = fakeEventId();

        Map<Id, Contact> contactsById =
            customEventAttendeeService.queryContacts(new Set<Id>{ c1.Id, c2.Id });

        List<EventAttendee__c> attendees = new List<EventAttendee__c>{
            null,
            new EventAttendee__c(),
            new EventAttendee__c(Event__c = evId, Contact__c = c1.Id),
            new EventAttendee__c(Event__c = evId, Contact__c = c2.Id)
        };

        Map<Id, Account> result =
            customEventAttendeeService.chooseFirstValidAccountPerEvent(
                attendees,
                new Set<Id>{ evId },
                contactsById
            );

        System.assertEquals(1, result.size());

        System.assertEquals(0, customEventAttendeeService.chooseFirstValidAccountPerEvent(null, new Set<Id>{ evId }, contactsById).size());
        System.assertEquals(0, customEventAttendeeService.chooseFirstValidAccountPerEvent(new List<EventAttendee__c>(), new Set<Id>{ evId }, contactsById).size());
        System.assertEquals(0, customEventAttendeeService.chooseFirstValidAccountPerEvent(attendees, null, contactsById).size());
        System.assertEquals(0, customEventAttendeeService.chooseFirstValidAccountPerEvent(attendees, new Set<Id>(), contactsById).size());
        System.assertEquals(0, customEventAttendeeService.chooseFirstValidAccountPerEvent(attendees, new Set<Id>{ evId }, null).size());
    }

    @IsTest
    static void testIsAttendeeEligibleForAccountChoice() {
        Id evId = fakeEventId();

        System.assertEquals(false,
            customEventAttendeeService.isAttendeeEligibleForAccountChoice(
                new EventAttendee__c(),
                new Set<Id>{ evId },
                new Map<Id, Account>()
            )
        );

        System.assertEquals(false,
            customEventAttendeeService.isAttendeeEligibleForAccountChoice(
                new EventAttendee__c(Event__c = evId, Contact__c = '003000000000001AAA'),
                new Set<Id>(),
                new Map<Id, Account>()
            )
        );

        System.assertEquals(false,
            customEventAttendeeService.isAttendeeEligibleForAccountChoice(
                new EventAttendee__c(Event__c = evId, Contact__c = '003000000000001AAA'),
                new Set<Id>{ evId },
                new Map<Id, Account>{ evId => new Account(Id = '001000000000001AAA') }
            )
        );

        System.assertEquals(true,
            customEventAttendeeService.isAttendeeEligibleForAccountChoice(
                new EventAttendee__c(Event__c = evId, Contact__c = '003000000000001AAA'),
                new Set<Id>{ evId },
                new Map<Id, Account>()
            )
        );
    }

    @IsTest
    static void testFindValidAccountForAttendee() {
        User u = BooklyDataFactory.createOrganizerUser();

        Account acc = BooklyDataFactory.createAccount();
        acc.BillingStreet = 'Street';
        update acc;

        Contact validContact = BooklyDataFactory.createSpeakerContact(acc.Id, u.Id, false);

        Contact noAccount = new Contact(FirstName = 'No', LastName = 'Account');
        insert noAccount;

        Map<Id, Contact> contactsById =
            customEventAttendeeService.queryContacts(new Set<Id>{ validContact.Id, noAccount.Id });

        System.assertEquals(null,
            customEventAttendeeService.findValidAccountForAttendee(
                new EventAttendee__c(Contact__c = '003000000000001AAA'),
                contactsById
            )
        );

        System.assertEquals(null,
            customEventAttendeeService.findValidAccountForAttendee(
                new EventAttendee__c(Contact__c = noAccount.Id),
                contactsById
            )
        );

        System.assertNotEquals(null,
            customEventAttendeeService.findValidAccountForAttendee(
                new EventAttendee__c(Contact__c = validContact.Id),
                contactsById
            )
        );
    }

    @IsTest
    static void testBuildEventUpdates() {
        Id evId = fakeEventId();

        Account acc = new Account(
            Id = '001000000000001AAA',
            Name = 'Account Test',
            BillingStreet = 'Street',
            BillingCity = 'Paris',
            BillingPostalCode = '75001',
            BillingCountry = 'France'
        );

        Event__c emptyEvent = new Event__c(
            Id = evId,
            LocationAddress__c = null,
            city__c = null,
            country__c = null,
            LocationPostCode__c = null,
            LocationName__c = null
        );

        List<Event__c> updates =
            customEventAttendeeService.buildEventUpdates(
                new Map<Id, Event__c>{ evId => emptyEvent },
                new Map<Id, Account>{ evId => acc }
            );

        System.assertEquals(1, updates.size());

        emptyEvent.LocationAddress__c = 'Already filled';

        updates = customEventAttendeeService.buildEventUpdates(
            new Map<Id, Event__c>{ evId => emptyEvent },
            new Map<Id, Account>{ evId => acc }
        );

        System.assertEquals(0, updates.size());

        updates = customEventAttendeeService.buildEventUpdates(
            new Map<Id, Event__c>(),
            new Map<Id, Account>{ evId => acc }
        );
        System.assertEquals(0, updates.size());

        updates = customEventAttendeeService.buildEventUpdates(
            new Map<Id, Event__c>{ evId => emptyEvent },
            new Map<Id, Account>()
        );
        System.assertEquals(0, updates.size());
    }

    @IsTest
    static void testUpdateIfNeededAndHelpers() {
        customEventAttendeeService.updateIfNeeded(null);
        customEventAttendeeService.updateIfNeeded(new List<Event__c>());

        System.assertEquals(true, customEventAttendeeService.isAccountBillingEmpty(new Account()));
        System.assertEquals(false, customEventAttendeeService.isAccountBillingEmpty(new Account(BillingStreet = 'Street')));

        System.assertEquals(true, customEventAttendeeService.isEventLocationEmpty(new Event__c()));
        System.assertEquals(false, customEventAttendeeService.isEventLocationEmpty(new Event__c(city__c = 'Paris')));
    }
}