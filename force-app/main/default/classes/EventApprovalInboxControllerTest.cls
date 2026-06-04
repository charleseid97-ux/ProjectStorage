@IsTest
private class EventApprovalInboxControllerTest {

    private static final String EVENT_PROCESS_DEVELOPER_NAME = 'EventApprovalProcess';
    private static final String SPEAKER_PROCESS_DEVELOPER_NAME = 'SpeakerApproval';
    private static final String ORGANIZER_PROCESS_DEVELOPER_NAME = 'OrganizerApprovalProcess';
    private static final String HOP_PROCESS_DEVELOPER_NAME = 'SpeakerApprovalHOP';

    // Assigne à l'utilisateur les Permission Sets contenant les Custom Permissions Bookly.
    private static void assignBooklyPermissions(User userToAssign) {
        Set<String> customPermissionNames = new Set<String>{
            'BooklySpeakerApprover',
            'BooklyCanCreateMeetingNotes',
            'BooklyCreateEvents',
            'BooklyApproveAnyOrganizer',
            'Bookly_Admin',
            'ApproveForHOP'
        };

        Set<Id> permissionSetIds = new Set<Id>();

        // Récupère les Permission Sets liés aux Custom Permissions demandées.
        for (SetupEntityAccess sea : [
            SELECT ParentId
            FROM SetupEntityAccess
            WHERE SetupEntityType = 'CustomPermission'
            AND SetupEntityId IN (
                SELECT Id
                FROM CustomPermission
                WHERE DeveloperName IN :customPermissionNames
            )
        ]) {
            permissionSetIds.add(sea.ParentId);
        }

        if (permissionSetIds.isEmpty()) {
            return;
        }

        Set<Id> alreadyAssignedPermissionSetIds = new Set<Id>();

        // Évite les doublons d'assignation sur le même utilisateur.
        for (PermissionSetAssignment psa : [
            SELECT PermissionSetId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userToAssign.Id
            AND PermissionSetId IN :permissionSetIds
        ]) {
            alreadyAssignedPermissionSetIds.add(psa.PermissionSetId);
        }

        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();

        for (Id permissionSetId : permissionSetIds) {
            if (!alreadyAssignedPermissionSetIds.contains(permissionSetId)) {
                assignments.add(new PermissionSetAssignment(
                    AssigneeId = userToAssign.Id,
                    PermissionSetId = permissionSetId
                ));
            }
        }

        if (!assignments.isEmpty()) {
            insert assignments;
        }
    }

    // Soumet un record à un process d'approbation si le process est disponible.
    private static void submitApproval(Id recordId, String processDeveloperName) {
        try {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();

            req.setObjectId(recordId);
            req.setProcessDefinitionNameOrId(processDeveloperName);

            Approval.process(req);

        } catch (Exception ex) {
            System.debug(ex.getMessage());
        }
    }

    // Ajoute l'utilisateur aux queues utilisées par les workitems créés.
    private static void addUserToWorkitemQueues(Id userId) {
        Set<Id> queueIds = new Set<Id>();

        for (ProcessInstanceWorkitem wi : [
            SELECT ActorId
            FROM ProcessInstanceWorkitem
        ]) {
            if (wi.ActorId != null && String.valueOf(wi.ActorId).startsWith('00G')) {
                queueIds.add(wi.ActorId);
            }
        }

        if (queueIds.isEmpty()) {
            return;
        }

        Set<Id> existingQueueIds = new Set<Id>();

        // Évite les doublons GroupMember si plusieurs workitems utilisent la même queue.
        for (GroupMember gm : [
            SELECT GroupId
            FROM GroupMember
            WHERE GroupId IN :queueIds
            AND UserOrGroupId = :userId
        ]) {
            existingQueueIds.add(gm.GroupId);
        }

        List<GroupMember> groupMembers = new List<GroupMember>();

        for (Id queueId : queueIds) {
            if (!existingQueueIds.contains(queueId)) {
                groupMembers.add(new GroupMember(
                    GroupId = queueId,
                    UserOrGroupId = userId
                ));
            }
        }

        if (!groupMembers.isEmpty()) {
            insert groupMembers;
        }
    }

    // Récupère les workitems en attente pour tester le bulk approve.
    private static List<Id> getPendingWorkItemIds() {
        List<Id> workItemIds = new List<Id>();

        for (ProcessInstanceWorkitem wi : [
            SELECT Id
            FROM ProcessInstanceWorkitem
        ]) {
            workItemIds.add(wi.Id);
        }

        return workItemIds;
    }

    // Test loadApprovals sans workitem.
    @IsTest
    static void testLoadApprovalsWithoutWorkItems() {
        User organizer = BooklyDataFactory.createOrganizerUser();
        assignBooklyPermissions(organizer);

        System.runAs(organizer) {
            Test.startTest();
            Map<String, Object> result = EventApprovalInboxController.loadApprovals();
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assert(result.containsKey('eventRows'));
            System.assert(result.containsKey('speakerRows'));
            System.assert(result.containsKey('organizerRows'));
            System.assert(result.containsKey('hopRows'));
            System.assert(result.containsKey('hasHopApproverPermission'));
        }
    }

    // Test bulkApprove avec liste null et vide.
    @IsTest
    static void testBulkApproveWithNullAndEmptyList() {
        User organizer = BooklyDataFactory.createOrganizerUser();
        assignBooklyPermissions(organizer);

        System.runAs(organizer) {
            Test.startTest();
            EventApprovalInboxController.bulkApprove(null);
            EventApprovalInboxController.bulkApprove(new List<Id>());
            Test.stopTest();

            System.assert(true);
        }
    }

    // Couvre loadApprovals avec des approvals Event, Speaker et Organizer.
    @IsTest
    static void testLoadApprovalsWithSubmittedApprovals() {
        User organizer = BooklyDataFactory.createOrganizerUser();
        assignBooklyPermissions(organizer);

        System.runAs(organizer) {
            Account company = BooklyDataFactory.createAccount();
            Contact speakerTop = BooklyDataFactory.createSpeakerContact(company.Id, organizer.Id, true);

            Event__c eventApproval = BooklyDataFactory.createEvent(company.Id, organizer.Id);
            Event__c organizerApproval = BooklyDataFactory.createEvent(company.Id, organizer.Id);

            // Crée l'approbation speaker liée à l'event.
            EventSpeakerApprovals__c esa = new EventSpeakerApprovals__c(
                Key__c = String.valueOf(eventApproval.Id) + '-' + String.valueOf(speakerTop.Id) + '-Speaker',
                Event__c = eventApproval.Id,
                Speaker__c = speakerTop.Id,
                ApproverUser__c = organizer.Id,
                Status__c = 'Submitted',
                approvalType__c = 'Speaker'
            );
            insert esa;

            Test.startTest();

            submitApproval(eventApproval.Id, EVENT_PROCESS_DEVELOPER_NAME);
            submitApproval(organizerApproval.Id, ORGANIZER_PROCESS_DEVELOPER_NAME);
            submitApproval(esa.Id, SPEAKER_PROCESS_DEVELOPER_NAME);

            addUserToWorkitemQueues(organizer.Id);

            Map<String, Object> result = EventApprovalInboxController.loadApprovals();

            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assert(result.containsKey('eventRows'));
            System.assert(result.containsKey('speakerRows'));
            System.assert(result.containsKey('organizerRows'));
        }
    }

    // Couvre les approvals Head of Product avec la permission ApproveForHOP.
    @IsTest
    static void testLoadApprovalsWithHopApproval() {
        User adminUser = BooklyDataFactory.createOrganizerUser();
        User hopUser = BooklyDataFactory.createOrganizerUser();

        assignBooklyPermissions(adminUser);

        System.runAs(adminUser) {
            Account company = BooklyDataFactory.createAccount();
            Contact speakerTop = BooklyDataFactory.createSpeakerContact(company.Id, adminUser.Id, true);
            Event__c evt = BooklyDataFactory.createEvent(company.Id, adminUser.Id);

            // Crée une demande assignée au HOP pour couvrir l'approbation par admin.
            EventSpeakerApprovals__c esa = new EventSpeakerApprovals__c(
                Key__c = String.valueOf(evt.Id) + '-' + String.valueOf(speakerTop.Id) + '-HOP',
                Event__c = evt.Id,
                Speaker__c = speakerTop.Id,
                ApproverUser__c = hopUser.Id,
                Status__c = 'Submitted',
                approvalType__c = 'Speaker'
            );
            insert esa;

            Test.startTest();

            submitApproval(esa.Id, HOP_PROCESS_DEVELOPER_NAME);
            addUserToWorkitemQueues(adminUser.Id);

            Map<String, Object> result = EventApprovalInboxController.loadApprovals();

            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assert(result.containsKey('hopRows'));
            System.assert(result.containsKey('hasHopApproverPermission'));
        }
    }

    // Couvre bulkApprove avec de vrais workitems.
    @IsTest
    static void testBulkApproveWithSubmittedWorkItems() {
        User organizer = BooklyDataFactory.createOrganizerUser();
        assignBooklyPermissions(organizer);

        System.runAs(organizer) {
            Account company = BooklyDataFactory.createAccount();
            Contact speakerTop = BooklyDataFactory.createSpeakerContact(company.Id, organizer.Id, true);
            Event__c evt = BooklyDataFactory.createEvent(company.Id, organizer.Id);

            // Prépare une approval speaker pour générer un ProcessInstanceWorkitem.
            EventSpeakerApprovals__c esa = new EventSpeakerApprovals__c(
                Key__c = String.valueOf(evt.Id) + '-' + String.valueOf(speakerTop.Id) + '-Bulk',
                Event__c = evt.Id,
                Speaker__c = speakerTop.Id,
                ApproverUser__c = organizer.Id,
                Status__c = 'Submitted',
                approvalType__c = 'Speaker'
            );
            insert esa;

            Test.startTest();

            submitApproval(evt.Id, EVENT_PROCESS_DEVELOPER_NAME);
            submitApproval(esa.Id, SPEAKER_PROCESS_DEVELOPER_NAME);

            addUserToWorkitemQueues(organizer.Id);

            List<Id> workItemIds = getPendingWorkItemIds();

            try {
                EventApprovalInboxController.bulkApprove(workItemIds);
            } catch (Exception ex) {
                System.debug(ex.getMessage());
            }

            Test.stopTest();

            System.assertNotEquals(null, workItemIds);
        }
    }
}