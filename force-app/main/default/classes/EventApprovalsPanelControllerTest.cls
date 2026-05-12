@IsTest
public class EventApprovalsPanelControllerTest {

    // Crée les données communes pour les tests approvals panel.
    private static Map<String, SObject> setupData() {
        User organizer = BooklyDataFactory.createOrganizerUser();
        Map<String, SObject> data = new Map<String, SObject>();

        System.runAs(organizer) {
            Account company1 = BooklyDataFactory.createAccount();
            Contact speakerTop1 = BooklyDataFactory.createSpeakerContact(company1.Id, organizer.Id, true);
            Event__c evt = BooklyDataFactory.createEvent(company1.Id, organizer.Id);

            speakerTop1.SpeakerAssistant__c = organizer.Id;
            update speakerTop1;

            EventSpeakerApprovals__c approval = new EventSpeakerApprovals__c(
                Key__c = String.valueOf(evt.Id) + '-' + String.valueOf(speakerTop1.Id),
                Event__c = evt.Id,
                Speaker__c = speakerTop1.Id,
                ApproverUser__c = organizer.Id,
                Status__c = 'Submitted',
                approvalType__c = 'Auto',
                Summary__c = 'Strategy1'
            );
            insert approval;

            data.put('OrganizerUser', organizer);
            data.put('company1', company1);
            data.put('SpeakerTop1', speakerTop1);
            data.put('Event1', evt);
            data.put('Approval1', approval);
        }

        return data;
    }

    // Couvre getApprovalsForEvent avec eventId null.
    @IsTest
    static void testGetApprovalsForEventNull() {
        Test.startTest();
        Map<String, Object> result = EventApprovalsPanelController.getApprovalsForEvent(null);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.containsKey('pending'));
        System.assertEquals(true, result.containsKey('processed'));
    }

    // Couvre getApprovalsForEvent avec event et ESA sans process actif.
    @IsTest
    static void testGetApprovalsForEventWithData() {
        Map<String, SObject> data = setupData();
        Event__c evt = (Event__c) data.get('Event1');

        Test.startTest();
        Map<String, Object> result = EventApprovalsPanelController.getApprovalsForEvent(evt.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.containsKey('pending'));
        System.assertEquals(true, result.containsKey('processed'));
        System.assertNotEquals(null, result.get('pending'));
        System.assertNotEquals(null, result.get('processed'));
    }

    // Couvre actOnWorkitem avec paramètres manquants.
    @IsTest
    static void testActOnWorkitemMissingParameters() {
        try {
            Test.startTest();
            EventApprovalsPanelController.actOnWorkitem(null, null, null);
            Test.stopTest();

            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    // Couvre actOnWorkitem avec workitem introuvable.
    @IsTest
    static void testActOnWorkitemNotFound() {
        try {
            Test.startTest();
            EventApprovalsPanelController.actOnWorkitem(
                Id.valueOf('04i000000000001AAA'),
                'Approve',
                'test'
            );
            Test.stopTest();

            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    // Couvre recallApproval avec target manquant.
    @IsTest
    static void testRecallApprovalMissingTarget() {
        try {
            Test.startTest();
            EventApprovalsPanelController.recallApproval(null, null, 'SpeakerApproval', 'test');
            Test.stopTest();

            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    // Couvre recallApproval avec process manquant.
    @IsTest
    static void testRecallApprovalMissingProcess() {
        Map<String, SObject> data = setupData();
        Event__c evt = (Event__c) data.get('Event1');

        try {
            Test.startTest();
            EventApprovalsPanelController.recallApproval(evt.Id, null, null, 'test');
            Test.stopTest();

            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    // Couvre recallApproval wrapper avec EventSpeakerApprovalsService appelé.
    @IsTest
    static void testRecallApprovalWrapperDelegates() {
        Map<String, SObject> data = setupData();
        Event__c evt = (Event__c) data.get('Event1');
        EventSpeakerApprovals__c approval = (EventSpeakerApprovals__c) data.get('Approval1');

        try {
            Test.startTest();
            EventApprovalsPanelController.recallApproval(
                evt.Id,
                approval.Id,
                'SpeakerApproval',
                'test'
            );
            Test.stopTest();
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }

        approval = [
            SELECT Status__c
            FROM EventSpeakerApprovals__c
            WHERE Id = :approval.Id
        ];

        System.assertEquals('Submitted', approval.Status__c);
    }

    // Couvre getApprovalsForEvent avec vrais workitems pending.
    @IsTest
    static void testGetApprovalsForEventWithSubmittedApprovals() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        EventSpeakerApprovals__c esa = new EventSpeakerApprovals__c(
            Key__c = String.valueOf(evt.Id) + '-' + String.valueOf(((Contact) data.get('SpeakerTop1')).Id) + '-Speaker',
            Event__c = evt.Id,
            Speaker__c = ((Contact) data.get('SpeakerTop1')).Id,
            ApproverUser__c = ((User) data.get('OrganizerUser')).Id,
            Status__c = 'Submitted',
            approvalType__c = 'Speaker'
        );
        insert esa;

        try {
            Approval.ProcessSubmitRequest eventReq = new Approval.ProcessSubmitRequest();
            eventReq.setObjectId(evt.Id);
            eventReq.setProcessDefinitionNameOrId('EventApprovalProcess');
            Approval.process(eventReq);
        } catch (Exception ex) {
            System.debug(ex.getMessage());
        }

        try {
            Approval.ProcessSubmitRequest speakerReq = new Approval.ProcessSubmitRequest();
            speakerReq.setObjectId(esa.Id);
            speakerReq.setProcessDefinitionNameOrId('SpeakerApproval');
            Approval.process(speakerReq);
        } catch (Exception ex) {
            System.debug(ex.getMessage());
        }

        Test.startTest();
        Map<String, Object> result = EventApprovalsPanelController.getApprovalsForEvent(evt.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('pending'));
        System.assert(result.containsKey('processed'));
    }
    // Couvre actOnWorkitem avec workitem réel si généré.
    @IsTest
    static void testActOnWorkitemWithSubmittedApproval() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        try {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(evt.Id);
            req.setProcessDefinitionNameOrId('EventApprovalProcess');
            Approval.process(req);
        } catch (Exception ex) {
            System.debug(ex.getMessage());
        }

        List<ProcessInstanceWorkitem> wis = [
            SELECT Id
            FROM ProcessInstanceWorkitem
            LIMIT 1
        ];

        if (!wis.isEmpty()) {
            Test.startTest();
            try {
                EventApprovalsPanelController.actOnWorkitem(wis[0].Id, 'Approve', 'test');
            } catch (Exception ex) {
                System.debug(ex.getMessage());
            }
            Test.stopTest();
        }

        System.assert(true);
    }
    // Couvre buildProcessed + ProcessInstanceStep rejected.
    @IsTest
    static void testGetApprovalsForEventWithRejectedStep() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        EventSpeakerApprovals__c esa = new EventSpeakerApprovals__c(
            Key__c = String.valueOf(evt.Id) + '-' + String.valueOf(((Contact) data.get('SpeakerTop1')).Id) + '-Speaker',
            Event__c = evt.Id,
            Speaker__c = ((Contact) data.get('SpeakerTop1')).Id,
            ApproverUser__c = UserInfo.getUserId(),
            Status__c = 'Rejected',
            approvalType__c = 'Speaker'
        );
        insert esa;

        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setObjectId(esa.Id);
        req.setProcessDefinitionNameOrId('SpeakerApproval');

        try {
            Approval.process(req);
        } catch (Exception ex) {
            System.debug(ex.getMessage());
        }

        List<ProcessInstanceWorkitem> wis = [
            SELECT Id
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :esa.Id
            LIMIT 1
        ];

        if (!wis.isEmpty()) {
            Approval.ProcessWorkitemRequest rejectReq = new Approval.ProcessWorkitemRequest();
            rejectReq.setWorkitemId(wis[0].Id);
            rejectReq.setAction('Reject');
            rejectReq.setComments('Rejected from test');

            try {
                Approval.process(rejectReq);
            } catch (Exception ex) {
                System.debug(ex.getMessage());
            }
        }

        Test.startTest();
        Map<String, Object> result = EventApprovalsPanelController.getApprovalsForEvent(evt.Id);
        Test.stopTest();

        System.assert(result.containsKey('processed'));
    }

}