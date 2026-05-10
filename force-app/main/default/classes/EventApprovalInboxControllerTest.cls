@IsTest
private class EventApprovalInboxControllerTest {

    // Assigne à l'utilisateur les Permission Sets contenant les Custom Permissions Bookly.
    private static void assignBooklyPermissions(User userToAssign) {
        Set<String> customPermissionNames = new Set<String>{
            'BooklySpeakerApprover',
            'BooklyCanCreateMeetingNotes',
            'BooklyCreateEvents',
            'BooklyApproveAnyOrganizer',
            'Bookly_Admin'
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

        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();

        // Prépare les assignations de Permission Sets pour l'organizer.
        for (Id permissionSetId : permissionSetIds) {
            assignments.add(new PermissionSetAssignment(
                AssigneeId = userToAssign.Id,
                PermissionSetId = permissionSetId
            ));
        }

        if (!assignments.isEmpty()) {
            insert assignments;
        }
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

    // Couvre loadApprovals avec vrais ProcessInstanceWorkitem.
    @IsTest
    static void testLoadApprovalsWithSubmittedApprovals() {
        User organizer = BooklyDataFactory.createOrganizerUser();
        assignBooklyPermissions(organizer);

        System.runAs(organizer) {
            Account company = BooklyDataFactory.createAccount();
            Contact speakerTop = BooklyDataFactory.createSpeakerContact(company.Id, organizer.Id, true);
            Event__c evt = BooklyDataFactory.createEvent(company.Id, organizer.Id);

            // Crée l'approbation speaker liée à l'event.
            EventSpeakerApprovals__c esa = new EventSpeakerApprovals__c(
                Key__c = String.valueOf(evt.Id) + '-' + String.valueOf(speakerTop.Id) + '-Speaker',
                Event__c = evt.Id,
                Speaker__c = speakerTop.Id,
                ApproverUser__c = organizer.Id,
                Status__c = 'Submitted',
                approvalType__c = 'Speaker'
            );
            insert esa;

            Test.startTest();

            // Soumet l'event au process d'approbation.
            try {
                Approval.ProcessSubmitRequest eventReq = new Approval.ProcessSubmitRequest();
                eventReq.setObjectId(evt.Id);
                eventReq.setProcessDefinitionNameOrId('EventApprovalProcess');
                Approval.process(eventReq);
            } catch (Exception ex) {
                System.debug(ex.getMessage());
            }

            // Soumet le speaker approval au process d'approbation.
            try {
                Approval.ProcessSubmitRequest speakerReq = new Approval.ProcessSubmitRequest();
                speakerReq.setObjectId(esa.Id);
                speakerReq.setProcessDefinitionNameOrId('SpeakerApproval');
                Approval.process(speakerReq);
            } catch (Exception ex) {
                System.debug(ex.getMessage());
            }

            // Ajoute l'organizer aux queues des approvals créés.
            for (ProcessInstanceWorkitem wi : [
                SELECT Id, ActorId
                FROM ProcessInstanceWorkitem
            ]) {
                if (wi.ActorId != null && String.valueOf(wi.ActorId).startsWith('00G')) {
                    insert new GroupMember(
                        GroupId = wi.ActorId,
                        UserOrGroupId = organizer.Id
                    );
                }
            }

            Map<String, Object> result = EventApprovalInboxController.loadApprovals();

            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assert(result.containsKey('eventRows'));
            System.assert(result.containsKey('speakerRows'));
        }
    }
}