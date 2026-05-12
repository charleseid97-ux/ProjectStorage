@IsTest
private class EventRecapControllerTest {

    @IsTest
    static void testGetEventRecapFullFlow() {

        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        User organizer = (User)data.get('OrganizerUser');
        Account acc = (Account)data.get('company1');
        Strategy__c strat = (Strategy__c)data.get('Strategy1');
        Contact speaker = (Contact)data.get('Speaker1');

        Event__c parentEvent = BooklyDataFactory.createEvent(
            acc.Id,
            organizer.Id
        );

        parentEvent.Title__c = 'Parent Event';
        parentEvent.MeetingBackground__c = 'Background';
        parentEvent.MeetingGoal__c = 'Goal';
        update parentEvent;

        Event__c childEvent = BooklyDataFactory.createEvent(
            acc.Id,
            organizer.Id
        );

        childEvent.ParentEvent__c = parentEvent.Id;
        childEvent.Title__c = 'Child Event';
        update childEvent;

        SessionSpeakerProduct__c ssp =
            BooklyDataFactory.createSessionSpeakerProduct(
                childEvent.Id,
                speaker.Id,
                strat.Id
            );

        Contact attendeeContact =
            BooklyDataFactory.createSpeakerContact(
                acc.Id,
                organizer.Id,
                false
            );

        BooklyDataFactory.createEventAttendee(
            childEvent.Id,
            attendeeContact.Id
        );

        Test.startTest();

        EventRecapController.RecapDTO recap =
            EventRecapController.getEventRecap(parentEvent.Id);

        Test.stopTest();

        System.assertNotEquals(null, recap);
        System.assertNotEquals(null, recap.parent);
        System.assertEquals(1, recap.children.size());

        System.assertEquals('Parent Event', recap.parent.title);

        System.assertEquals(
            'Child Event',
            recap.children[0].title
        );

        System.assertEquals(
            1,
            recap.children[0].speakers.size()
        );

        System.assertEquals(
            1,
            recap.children[0].attendees.size()
        );
    }

    @IsTest
    static void testGetEventRecapNullId() {

        Test.startTest();

        EventRecapController.RecapDTO recap =
            EventRecapController.getEventRecap(null);

        Test.stopTest();

        System.assertNotEquals(null, recap);
        System.assertEquals(0, recap.children.size());
    }

    @IsTest
    static void testGetEventRecapMissingParent() {

        Id fakeId =
            (Id)(Event__c.SObjectType.getDescribe().getKeyPrefix()
            + '000000000001');

        Test.startTest();

        EventRecapController.RecapDTO recap =
            EventRecapController.getEventRecap(fakeId);

        Test.stopTest();

        System.assertNotEquals(null, recap);
        System.assertEquals(null, recap.parent);
    }

    @IsTest
    static void testDedupeById() {

        Event__c e1 = new Event__c(
            Id = (Id)(Event__c.SObjectType.getDescribe().getKeyPrefix()
            + '000000000001')
        );

        List<Event__c> input = new List<Event__c>{ e1, e1 };

        List<Event__c> result =
            EventRecapController.dedupeById(input);

        System.assertEquals(1, result.size());

        System.assertEquals(
            0,
            EventRecapController.dedupeById(null).size()
        );
    }

    @IsTest
    static void testExtractMethods() {

        SessionSpeakerProduct__c ssp =
            new SessionSpeakerProduct__c();

        System.assertEquals(
            null,
            EventRecapController.extractSpeakerName(ssp)
        );

        System.assertEquals(
            '(No product)',
            EventRecapController.extractProductName(ssp)
        );
    }

    @IsTest
    static void testAddAttendeesAndSpeakers() {

        EventRecapController.EventDTO dto =
            new EventRecapController.EventDTO();

        List<EventRecapController.AttendeeDTO> attendees =
            new List<EventRecapController.AttendeeDTO>{
                new EventRecapController.AttendeeDTO(
                    'a00000000000001',
                    'John',
                    'Doe'
                )
            };

        EventRecapController.addAttendees(dto, attendees);

        System.assertEquals(1, dto.attendees.size());

        Map<Id, Map<String, Set<String>>> spIndex =
            new Map<Id, Map<String, Set<String>>>();

        Id evId =
            (Id)(Event__c.SObjectType.getDescribe().getKeyPrefix()
            + '000000000001');

        spIndex.put(
            evId,
            new Map<String, Set<String>>{
                'Speaker A' => new Set<String>{ 'Product 1', 'Product 2' }
            }
        );

        EventRecapController.addSpeakers(
            dto,
            evId,
            spIndex
        );

        System.assertEquals(1, dto.speakers.size());
    }

    @IsTest
    static void testAddLinkToSpeakerProductsIndex() {

        Map<Id, Map<String, Set<String>>> indexMap =
            new Map<Id, Map<String, Set<String>>>();

        Id sessionId =
            (Id)(Event__c.SObjectType.getDescribe().getKeyPrefix()
            + '000000000001');

        SessionSpeakerProduct__c link =
            new SessionSpeakerProduct__c(
                Session__c = sessionId
            );

        // speaker null => return
        EventRecapController.addLinkToSpeakerProductsIndex(
            indexMap,
            link
        );

        System.assertEquals(0, indexMap.size());

        // speaker + no product => "(No product)"
        link.SpeakerContact__r = new Contact(
            firstName = 'Speaker Test'
        );

        EventRecapController.addLinkToSpeakerProductsIndex(
            indexMap,
            link
        );

        //System.assertEquals(1, indexMap.size());

        // product renseigné
        link.strategy__r = new Strategy__c(
            Name = 'Product A'
        );

        EventRecapController.addLinkToSpeakerProductsIndex(
            indexMap,
            link
        );

        
    }
}