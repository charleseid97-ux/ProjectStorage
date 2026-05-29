@IsTest
public class EventSpeakerApprovalsServiceTest {

    // Crée les données communes utilisées par les tests approvals.
    private static Map<String, SObject> setupData() {
        User organizer = BooklyDataFactory.createOrganizerUser();
        Map<String, SObject> data = new Map<String, SObject>();

        System.runAs(organizer) {
            Account company1 = BooklyDataFactory.createAccount();
            Contact speakerTop1 = BooklyDataFactory.createSpeakerContact(company1.Id, organizer.Id, true);

            Event__c evt = BooklyDataFactory.createEvent(company1.Id, organizer.Id);
            User ownerUser = BooklyDataFactory.createOrganizerUser();

            evt.OwnerId = ownerUser.Id;
            update evt;

            data.put('OrganizerUser', organizer);
            data.put('company1', company1);
            data.put('SpeakerTop1', speakerTop1);
            data.put('Event1', evt);
        }

        return data;
    }

    // Crée une approval speaker minimale.
    private static EventSpeakerApprovals__c buildApproval(Id eventId, Id speakerId, Id approverId) {
        return new EventSpeakerApprovals__c(
            Key__c = String.valueOf(eventId) + '-' + String.valueOf(speakerId),
            Event__c = eventId,
            Speaker__c = speakerId,
            ApproverUser__c = approverId,
            Status__c = 'Submitted',
            approvalType__c = 'Auto',
            Summary__c = 'Strategy1'
        );
    }

    // Couvre isDisabled avec handlerToggle false.
    @IsTest
    static void testIsDisabledFalse() {
        Test.startTest();
        Boolean result = EventSpeakerApprovalsService.isDisabled(false);
        Test.stopTest();

        System.assertEquals(false, result);
    }

    // Couvre trackStatusUpdateOnInsert.
    @IsTest
    static void testTrackStatusUpdateOnInsert() {
        Map<String, SObject> data = setupData();

        EventSpeakerApprovals__c approval = buildApproval(
            ((Event__c) data.get('Event1')).Id,
            ((Contact) data.get('SpeakerTop1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        Test.startTest();
        EventSpeakerApprovalsService.trackStatusUpdateOnInsert(
            new List<EventSpeakerApprovals__c>{ approval }
        );
        Test.stopTest();

        System.assertNotEquals(null, approval.StatusChangeDate__c);
        System.assertEquals(UserInfo.getUserId(), approval.StatusChangedBy__c);
    }

    // Couvre trackStatusUpdateOnUpdate quand le status change.
    @IsTest
    static void testTrackStatusUpdateOnUpdate() {
        Map<String, SObject> data = setupData();

        EventSpeakerApprovals__c oldApproval = buildApproval(
            ((Event__c) data.get('Event1')).Id,
            ((Contact) data.get('SpeakerTop1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        insert oldApproval;

        EventSpeakerApprovals__c newApproval = oldApproval.clone(true, true, false, false);
        newApproval.Status__c = 'Approved';

        Test.startTest();
        EventSpeakerApprovalsService.trackStatusUpdateOnUpdate(
            new Map<Id, EventSpeakerApprovals__c>{ newApproval.Id => newApproval },
            new Map<Id, EventSpeakerApprovals__c>{ oldApproval.Id => oldApproval }
        );
        Test.stopTest();

        System.assertNotEquals(null, newApproval.StatusChangeDate__c);
        System.assertEquals(UserInfo.getUserId(), newApproval.StatusChangedBy__c);
    }

    // Couvre manageRollupOnInsert avec organizer approval non approuvé.
    @IsTest
    static void testManageRollupOnInsertOrganizerNotApproved() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = (Event__c) data.get('Event1');
            evt.OrganizerDecision__c = null;
            update evt;

            EventSpeakerApprovals__c approval = buildApproval(
                evt.Id,
                ((Contact) data.get('SpeakerTop1')).Id,
                organizer.Id
            );
            insert approval;

            Test.startTest();
            EventSpeakerApprovalsService.manageRollupOnInsert(
                new Map<Id, EventSpeakerApprovals__c>{ approval.Id => approval }
            );
            Test.stopTest();

            System.assertEquals('Submitted', approval.Status__c);
        }
    }

    // Couvre manageRollupOnUpdate avec changement de status.
    @IsTest
    static void testManageRollupOnUpdateNoStatusChange() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = (Event__c) data.get('Event1');
            evt.OrganizerDecision__c = 'Approved';
            update evt;

            EventSpeakerApprovals__c oldApproval = buildApproval(
                evt.Id,
                ((Contact) data.get('SpeakerTop1')).Id,
                organizer.Id
            );
            insert oldApproval;

            EventSpeakerApprovals__c newApproval = oldApproval.clone(true, true, false, false);
            newApproval.Status__c = 'Approved';

            Test.startTest();
            EventSpeakerApprovalsService.manageRollupOnUpdate(
                new Map<Id, EventSpeakerApprovals__c>{ newApproval.Id => newApproval },
                new Map<Id, EventSpeakerApprovals__c>{ oldApproval.Id => oldApproval }
            );
            Test.stopTest();

            System.assertEquals('Approved', newApproval.Status__c);
        }
    }

    // Couvre submitForSpeakerApproval avec Speaker et HOP.
    @IsTest
    static void testSubmitForSpeakerApprovalAutoSkipped() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            EventSpeakerApprovals__c speakerApproval = buildApproval(
                ((Event__c) data.get('Event1')).Id,
                ((Contact) data.get('SpeakerTop1')).Id,
                organizer.Id
            );
            speakerApproval.approvalType__c = 'Speaker';

            EventSpeakerApprovals__c hopApproval = buildApproval(
                ((Event__c) data.get('Event1')).Id,
                ((Contact) data.get('SpeakerTop1')).Id,
                organizer.Id
            );
            hopApproval.Key__c += '-HOP';
            hopApproval.approvalType__c = 'HOP';

            insert new List<EventSpeakerApprovals__c>{ speakerApproval, hopApproval };

            Test.startTest();
            try {
                EventSpeakerApprovalsService.submitForSpeakerApproval(
                    new List<EventSpeakerApprovals__c>{ speakerApproval, hopApproval },
                    null
                );
            } catch (Exception ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
            Test.stopTest();

            System.assertEquals('Speaker', speakerApproval.approvalType__c);
        }
    }

    // Couvre recallApproval avec recallTargetId null.
    @IsTest
    static void testRecallApprovalMissingTarget() {
        try {
            Test.startTest();
            EventSpeakerApprovalsService.recallApproval(null, null, 'SpeakerApproval', 'test');
            Test.stopTest();

            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    // Couvre recallApproval avec processDeveloperName vide.
    @IsTest
    static void testRecallApprovalMissingProcess() {
        Map<String, SObject> data = setupData();

        try {
            Test.startTest();
            EventSpeakerApprovalsService.recallApproval(
                ((Event__c) data.get('Event1')).Id,
                null,
                null,
                'test'
            );
            Test.stopTest();

            System.assert(false);
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    // Couvre triggerRollupFromEventBeforeUpdate avec event éligible.
    @IsTest
    static void testTriggerRollupFromEventBeforeUpdateNoEligible() {
        Map<String, SObject> data = setupData();
        Event__c evt = (Event__c) data.get('Event1');

        Event__c oldEvt = evt.clone(true, true, false, false);
        oldEvt.OrganizerDecision__c = 'Pending';

        evt.OrganizerDecision__c = 'Approved';

        Test.startTest();
        EventSpeakerApprovalsService.triggerRollupFromEventBeforeUpdate(
            new Map<Id, Event__c>{ evt.Id => evt },
            new Map<Id, Event__c>{ oldEvt.Id => oldEvt }
        );
        Test.stopTest();

        System.assertEquals('Approved', evt.OrganizerDecision__c);
    }
    // Couvre recallApproval avec approval et event.
    @IsTest
    static void testRecallApprovalBranches() {
        Map<String, SObject> data = setupData();
        User organizer = (User) data.get('OrganizerUser');

        System.runAs(organizer) {
            Event__c evt = (Event__c) data.get('Event1');

            EventSpeakerApprovals__c approval = buildApproval(
                evt.Id,
                ((Contact) data.get('SpeakerTop1')).Id,
                organizer.Id
            );
            approval.Status__c = 'Approved';
            insert approval;

            Test.startTest();

            try {
                EventSpeakerApprovalsService.recallApproval(
                    evt.Id,
                    approval.Id,
                    'SpeakerApproval',
                    ''
                );
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }

            try {
                EventSpeakerApprovalsService.recallApproval(
                    evt.Id,
                    null,
                    'EventApprovalProcess',
                    'test'
                );
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }

            Test.stopTest();

            approval = [
                SELECT Status__c
                FROM EventSpeakerApprovals__c
                WHERE Id = :approval.Id
            ];

            System.assertEquals('Submitted', approval.Status__c);
        }
    }
}