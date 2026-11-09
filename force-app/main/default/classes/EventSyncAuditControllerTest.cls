@IsTest
private class EventSyncAuditControllerTest {

    private static final String MATCHING_GRAPH_ID =
        'AAMkADJlMTUwYWZiLWE5MDgtNGI5My04OGUxLTMxMTBmMDhjZjIwNQ_MATCHING';

    private static final String GRAPH_ONLY_ID =
        'AAMkADJlMTUwYWZiLWE5MDgtNGI5My04OGUxLTMxMTBmMDhjZjIwNQ_GRAPH_ONLY';

    /**
     * Simulates Microsoft Graph calendarView responses.
     */
    private class GraphMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('GET', request.getMethod());
            System.assert(
                request.getEndpoint().contains('/me/calendarView'),
                'The controller must call the Graph calendarView endpoint.'
            );

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody(
                JSON.serialize(
                    new Map<String, Object>{
                        'value' => new List<Object>{
                            new Map<String, Object>{
                                'id' => MATCHING_GRAPH_ID,
                                'subject' => '[Bookly] - Matching Event',
                                'start' => new Map<String, Object>{
                                    'dateTime' => '2026-11-10T10:00:00.0000000',
                                    'timeZone' => 'Europe/Paris'
                                },
                                'end' => new Map<String, Object>{
                                    'dateTime' => '2026-11-10T11:00:00.0000000',
                                    'timeZone' => 'Europe/Paris'
                                }
                            },
                            new Map<String, Object>{
                                'id' => GRAPH_ONLY_ID,
                                'subject' => '[Bookly] - Graph Only Event',
                                'start' => new Map<String, Object>{
                                    'dateTime' => '2026-11-12T10:00:00.0000000',
                                    'timeZone' => 'Europe/Paris'
                                },
                                'end' => new Map<String, Object>{
                                    'dateTime' => '2026-11-12T11:00:00.0000000',
                                    'timeZone' => 'Europe/Paris'
                                }
                            }
                        }
                    }
                )
            );

            return response;
        }
    }

    /**
     * Creates the Bookly records required by the audit controller.
     */
    private static List<Event__c> createEvents() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Account company = (Account) data.get('company1');
        User organizer = (User) data.get('OrganizerUser');

        Event__c syncedEvent = BooklyDataFactory.createEvent(
            company.Id,
            organizer.Id
        );

        Event__c missingGraphEvent = BooklyDataFactory.createEvent(
            company.Id,
            organizer.Id
        );

        Event__c booklyCandidateEvent = BooklyDataFactory.createEvent(
            company.Id,
            organizer.Id
        );

        syncedEvent.noAutomations__c = true;
        syncedEvent.Status__c = 'FullyApproved';
        syncedEvent.StartDate__c = Date.newInstance(2026, 11, 10);
        syncedEvent.MicrosoftEventId__c = MATCHING_GRAPH_ID;

        missingGraphEvent.noAutomations__c = true;
        missingGraphEvent.Status__c = 'FullyApproved';
        missingGraphEvent.StartDate__c = Date.newInstance(2026, 11, 11);
        missingGraphEvent.MicrosoftEventId__c = 'GRAPH_ID_NOT_FOUND';

        booklyCandidateEvent.noAutomations__c = true;
        booklyCandidateEvent.Status__c = 'FullyApproved';
        booklyCandidateEvent.StartDate__c = Date.newInstance(2026, 11, 12);
        booklyCandidateEvent.Title__c = 'Graph Only Event';
        booklyCandidateEvent.MicrosoftEventId__c = null;

        update new List<Event__c>{
            syncedEvent,
            missingGraphEvent,
            booklyCandidateEvent
        };

        return [
            SELECT Id, Status__c, StartDate__c, MicrosoftEventId__c, Title__c
            FROM Event__c
            WHERE Id IN :new Set<Id>{
                syncedEvent.Id,
                missingGraphEvent.Id,
                booklyCandidateEvent.Id
            }
            ORDER BY StartDate__c
        ];
    }

    /**
     * Verifies reconciliation using only MicrosoftEventId__c.
     */
    @IsTest
    static void testSearchEvents() {
        List<Event__c> events = createEvents();
        System.assertEquals(3, events.size());
        System.assertEquals('FullyApproved', events[0].Status__c);
        System.assertEquals(Date.newInstance(2026, 11, 10), events[0].StartDate__c);
        System.assertEquals(MATCHING_GRAPH_ID, events[0].MicrosoftEventId__c);

        System.assertEquals('FullyApproved', events[1].Status__c);
        System.assertEquals(Date.newInstance(2026, 11, 11), events[1].StartDate__c);
        Test.setMock(HttpCalloutMock.class, new GraphMock());

        EventSyncAuditController controller =
            new EventSyncAuditController();

        controller.startDate = Date.newInstance(2026, 11, 1);
        controller.endDate = Date.newInstance(2026, 11, 30);

        Test.startTest();
        controller.searchEvents();
        Test.stopTest();

        System.assertEquals(null, controller.errorMessage);

        Set<Id> testEventIds = new Set<Id>{
            events[0].Id,
            events[1].Id
        };

        Boolean syncedFound = false;
        Boolean missingGraphFound = false;
        Boolean missingSalesforceFound = false;

        for (EventSyncAuditController.AuditRow row : controller.rows) {
            if (row.salesforceId != null && testEventIds.contains(row.salesforceId)) {
                if (row.salesforceId == events[0].Id) {
                    System.assertEquals('Synced', row.status);
                    System.assertEquals(MATCHING_GRAPH_ID, row.salesforceGraphId);
                    syncedFound = true;
                } else if (row.salesforceId == events[1].Id) {
                    System.assertEquals('Missing in Graph', row.status);
                    missingGraphFound = true;
                }
            }

            if (
                row.salesforceId == null &&
                !row.graphEvents.isEmpty() &&
                row.graphEvents[0].id == GRAPH_ONLY_ID
            ) {
                System.assertEquals('Missing in Salesforce', row.status);
                missingSalesforceFound = true;
            }
        }
        controller.selectedMicrosoftEventId = GRAPH_ONLY_ID;
        controller.selectedMicrosoftSubject = '[Bookly] - Graph Only Event';
        controller.selectedMicrosoftDate = '2026-11-12';

        controller.findInBookly();

        System.assertEquals(1, controller.booklyCandidates.size());
        System.assertEquals(
            events[2].Id,
            controller.booklyCandidates[0].id
        );
        System.assertEquals(
            true,
            controller.booklyCandidates[0].canLink
        );

        controller.selectedBooklyEventId =
            controller.booklyCandidates[0].id;

        controller.linkBooklyEvent();

        Event__c linkedEvent = [
            SELECT MicrosoftEventId__c
            FROM Event__c
            WHERE Id = :events[2].Id
        ];

        System.assertEquals(
            GRAPH_ONLY_ID,
            linkedEvent.MicrosoftEventId__c
        );
        System.assertEquals(
            'Event successfully linked to Microsoft Calendar.',
            controller.linkMessage
        );
        System.assertEquals(true, syncedFound);
        System.assertEquals(true, missingGraphFound);
        System.assertEquals(true, missingSalesforceFound);
    }

    /**
     * Verifies that an invalid date range is rejected before any callout.
     */
    @IsTest
    static void testInvalidDateRange() {
        EventSyncAuditController controller =
            new EventSyncAuditController();

        controller.startDate = Date.newInstance(2026, 11, 30);
        controller.endDate = Date.newInstance(2026, 11, 1);

        Test.startTest();
        controller.searchEvents();
        Test.stopTest();

        System.assertEquals(
            'Please select a valid date range.',
            controller.errorMessage
        );
        System.assertEquals(0, controller.totalCount);

        controller.selectedMicrosoftEventId = null;
        controller.deleteMicrosoftEvent();

        System.assertEquals(
            'No Microsoft Calendar Event selected.',
            controller.errorMessage
        );

        controller.resendEventId = null;
        controller.resendEvent();

        System.assertEquals(
            'No Event selected.',
            controller.resendMessage
        );
    }
}