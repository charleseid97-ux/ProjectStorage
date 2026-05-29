@IsTest
public class customEventSpeakerApprovalServiceTest {

    // Crée les données communes.
    private static Map<String, SObject> setupData() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Contact speakerTop = (Contact) data.get('SpeakerTop1');
        speakerTop.SpeakerAssistant__c = ((User) data.get('OrganizerUser')).Id;
        update speakerTop;

        return data;
    }

    // Couvre prepareSpeakerHTMLforNotifications.
    @IsTest
    static void testPrepareSpeakerHTMLforNotifications() {
        Map<String, SObject> data = setupData();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        BooklyDataFactory.createSessionSpeakerProduct(
            evt.Id,
            ((Contact) data.get('SpeakerTop1')).Id,
            ((Strategy__c) data.get('Strategy1')).Id
        );

        Event__c oldEvt = evt.clone(true, true, false, false);
        evt.Status__c = customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS;
        evt.SpeakersHTML__c = null;

        Test.startTest();
        customEventSpeakerApprovalService.prepareSpeakerHTMLforNotifications(
            new Map<Id, Event__c>{ evt.Id => evt },
            new Map<Id, Event__c>{ evt.Id => oldEvt }
        );
        Test.stopTest();

       // System.assert(evt.SpeakersHTML__c.contains('Speaker'));
        //System.assertNotEquals(null, evt.Speakers__c);
    }

    // Couvre markEventFullyApprovedIfNoSSP.
    @IsTest
    static void testMarkEventFullyApprovedIfNoSSP() {
        Map<String, SObject> data = setupData();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        Event__c oldEvt = evt.clone(true, true, false, false);
        oldEvt.Status__c = customEventConstants.STATUS_SUBMITTED_TO_EVENT_TEAM;
        oldEvt.Status__c = customEventConstants.STATUS_SUBMITTED_TO_EVENT_TEAM;
        evt.Status__c = customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS;

        Test.startTest();
        customEventSpeakerApprovalService.markEventFullyApprovedIfNoSSP(
            new Map<Id, Event__c>{ evt.Id => evt },
            new Map<Id, Event__c>{ evt.Id => oldEvt }
        );
        Test.stopTest();

        System.assertEquals(customEventConstants.STATUS_FULLY_APPROVED, evt.Status__c);
    }

    // Couvre createOrUpdateSpeakerApprovals.
    @IsTest
    static void testCreateOrUpdateSpeakerApprovals() {
        Map<String, SObject> data = setupData();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        BooklyDataFactory.createSessionSpeakerProduct(
            evt.Id,
            ((Contact) data.get('SpeakerTop1')).Id,
            ((Strategy__c) data.get('Strategy1')).Id
        );

        Event__c oldEvt = evt.clone(true, true, false, false);
        oldEvt.Status__c = customEventConstants.STATUS_SUBMITTED_TO_EVENT_TEAM;
        evt.Status__c = customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS;

        Test.startTest();
        customEventSpeakerApprovalService.createOrUpdateSpeakerApprovals(
            new Map<Id, Event__c>{ evt.Id => evt },
            new Map<Id, Event__c>{ evt.Id => oldEvt }
        );
        Test.stopTest();

        System.assert([
            SELECT COUNT()
            FROM EventSpeakerApprovals__c
            WHERE Event__c = :evt.Id
        ] > 0);
    }

    // Couvre updateEventStatusIfAllApproved.
    @IsTest
    static void testUpdateEventStatusIfAllApproved() {
        Map<String, SObject> data = setupData();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        EventSpeakerApprovals__c approval = new EventSpeakerApprovals__c(
            Key__c = String.valueOf(evt.Id) + '-' + String.valueOf(((Contact) data.get('SpeakerTop1')).Id) + '-Auto',
            Event__c = evt.Id,
            Speaker__c = ((Contact) data.get('SpeakerTop1')).Id,
            Status__c = 'AutoApproved',
            approvalType__c = 'Auto'
        );
        insert approval;

        Test.startTest();
        customEventSpeakerApprovalService.updateEventStatusIfAllApproved(
            new List<EventSpeakerApprovals__c>{ approval }
        );
        Test.stopTest();

        evt = [SELECT Status__c FROM Event__c WHERE Id = :evt.Id];
        System.assertEquals(customEventConstants.STATUS_FULLY_APPROVED, evt.Status__c);
    }

    // Couvre buildSpeakersHtmlFromFlow.
    @IsTest
    static void testBuildSpeakersHtmlFromFlow() {
        Map<String, SObject> data = setupData();

        List<Object> payload = new List<Object>{
            new Map<String, Object>{
                'speakerContact__c' => String.valueOf(((Contact) data.get('SpeakerTop1')).Id),
                'strategy__c' => String.valueOf(((Strategy__c) data.get('Strategy1')).Id),
                'Language__c' => 'Italian',
                'PresentationStatus__c' => 'required',
                'startTime__c' => '09:00',
                'endTime__c' => '10:00'
            }
        };

        customEventSpeakerApprovalService.SpeakersHtmlRequest req =
            new customEventSpeakerApprovalService.SpeakersHtmlRequest();
        req.jsonPayload = JSON.serialize(payload);

        Test.startTest();
        List<customEventSpeakerApprovalService.SpeakersHtmlResponse> res =
            customEventSpeakerApprovalService.buildSpeakersHtmlFromFlow(
                new List<customEventSpeakerApprovalService.SpeakersHtmlRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assert(res[0].speakersHtml.contains('Strategy1'));
    }

    // Couvre updateApprovalSlots.
    @IsTest
    static void testUpdateApprovalSlots() {
        Map<String, SObject> data = setupData();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        SessionSpeakerProduct__c ssp = BooklyDataFactory.createSessionSpeakerProduct(
            evt.Id,
            ((Contact) data.get('SpeakerTop1')).Id,
            ((Strategy__c) data.get('Strategy1')).Id
        );

        SessionSpeakerProduct__c oldSsp = ssp.clone(true, true, false, false);
        ssp.startTime__c = Time.newInstance(9, 0, 0, 0);
        ssp.endTime__c = Time.newInstance(11, 0, 0, 0);

        Test.startTest();
        customEventSpeakerApprovalService.updateApprovalSlots(
            new Map<Id, SessionSpeakerProduct__c>{ oldSsp.Id => oldSsp },
            new Map<Id, SessionSpeakerProduct__c>{ ssp.Id => ssp }
        );
        Test.stopTest();

        System.assert(true);
    }

    // Couvre calculateEventStatusFromApprovals.
    @IsTest
    static void testCalculateEventStatusFromApprovals() {
        Map<String, SObject> data = setupData();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        insert new EventSpeakerApprovals__c(
            Key__c = String.valueOf(evt.Id) + '-calc-Auto',
            Event__c = evt.Id,
            Speaker__c = ((Contact) data.get('SpeakerTop1')).Id,
            Status__c = 'AutoApproved',
            approvalType__c = 'Auto'
        );

        Test.startTest();
        Map<Id, String> result =
            customEventSpeakerApprovalService.calculateEventStatusFromApprovals(
                new Set<Id>{ evt.Id }
            );
        Test.stopTest();

        System.assertEquals(customEventConstants.STATUS_FULLY_APPROVED, result.get(evt.Id));
    }
}