@IsTest
private class EventApprovalControllerTest {

    // Couvre constructeur + initPage sans eid.
    @IsTest
    static void testInitPageMissingEid() {
        Test.setCurrentPage(new PageReference('/apex/EventApproval'));

        Test.startTest();
        EventApprovalController ctrl = new EventApprovalController();
        ctrl.initPage();
        Test.stopTest();

        System.assertEquals('Error', ctrl.resultMessage);
        System.assert(ctrl.errorMessage.contains('Missing eid'));
    }

    // Couvre reject avec formulaire affiché.
    @IsTest
    static void testInitPageRejectForm() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        Test.setCurrentPage(new PageReference('/apex/EventApproval'));
        ApexPages.currentPage().getParameters().put('eid', evt.Id);
        ApexPages.currentPage().getParameters().put('action', 'reject');

        Test.startTest();
        EventApprovalController ctrl = new EventApprovalController();
        ctrl.initPage();
        Test.stopTest();

        System.assertEquals(true, ctrl.showRejectForm);
    }

    // Couvre reject sans commentaire.
    @IsTest
    static void testRejectWithoutComment() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        Test.setCurrentPage(new PageReference('/apex/EventApproval'));
        ApexPages.currentPage().getParameters().put('eid', evt.Id);
        ApexPages.currentPage().getParameters().put('action', 'reject');

        Test.startTest();
        EventApprovalController ctrl = new EventApprovalController();
        ctrl.rejectComment = '';
        ctrl.processApproval();
        Test.stopTest();

        System.assertEquals('Error', ctrl.resultMessage);
        System.assert(ctrl.errorMessage.contains('Rejection comment'));
    }

    // Couvre invalid action.
    @IsTest
    static void testInvalidAction() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        Test.setCurrentPage(new PageReference('/apex/EventApproval'));
        ApexPages.currentPage().getParameters().put('eid', evt.Id);
        ApexPages.currentPage().getParameters().put('action', 'invalid');

        Test.startTest();
        EventApprovalController ctrl = new EventApprovalController();
        ctrl.processApproval();
        Test.stopTest();

        System.assertEquals('Error', ctrl.resultMessage);
    }

    // Couvre resolveOpenRecordId avec ESA.
    @IsTest
    static void testResolveOpenRecordIdWithESA() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        EventSpeakerApprovals__c esa = new EventSpeakerApprovals__c(
            Key__c = String.valueOf(evt.Id) + '-ESA',
            Event__c = evt.Id,
            Speaker__c = ((Contact) data.get('SpeakerTop1')).Id,
            ApproverUser__c = ((User) data.get('OrganizerUser')).Id,
            Status__c = 'Submitted',
            approvalType__c = 'Speaker'
        );
        insert esa;

        Test.setCurrentPage(new PageReference('/apex/EventApproval'));
        ApexPages.currentPage().getParameters().put('eid', esa.Id);
        ApexPages.currentPage().getParameters().put('action', 'approve');

        Test.startTest();
        EventApprovalController ctrl = new EventApprovalController();
        ctrl.initPage();
        Test.stopTest();

        System.assertEquals(String.valueOf(evt.Id), ctrl.openRecordId);
    }

    // Couvre processApproval avec aucun workitem.
    @IsTest
    static void testProcessApprovalWithoutWorkItem() {
        Map<String, SObject> data = BooklyDataFactory.setupForBookly();

        Event__c evt = BooklyDataFactory.createEvent(
            ((Account) data.get('company1')).Id,
            ((User) data.get('OrganizerUser')).Id
        );

        Test.setCurrentPage(new PageReference('/apex/EventApproval'));
        ApexPages.currentPage().getParameters().put('eid', evt.Id);
        ApexPages.currentPage().getParameters().put('action', 'approve');

        Test.startTest();
        EventApprovalController ctrl = new EventApprovalController();
        ctrl.processApproval();
        Test.stopTest();

        System.assertEquals('Error', ctrl.resultMessage);
        System.assert(ctrl.errorMessage.contains('No ProcessInstanceWorkitem'));
    }
}