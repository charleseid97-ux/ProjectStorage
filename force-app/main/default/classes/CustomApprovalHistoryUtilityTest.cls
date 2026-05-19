@IsTest
public with sharing class CustomApprovalHistoryUtilityTest {

    @TestSetup
    static void setupTestData() {
        GridTestSetupHelper.setupTestData();
    }

    // ─── submitForApproval ───────────────────────────────────────────────────────

    @IsTest
    static void testSubmitForApproval_InvalidProcess() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryUtility.submitForApproval(grid.Id, 'NonExistentProcess', null);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail for unknown process name');
        System.assertNotEquals(null, result.errorMessage, 'Error message should be set');
    }

    // ─── processApproval — Recall ────────────────────────────────────────────────

    @IsTest
    static void testProcessApproval_Recall() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = new CustomApproval__c(
            TargetRecordId__c       = String.valueOf(grid.Id),
            Status__c               = 'Pending',
            SubmittedBy__c          = UserInfo.getUserId(),
            ProcessDeveloperName__c = 'GridAmendment',
            CurrentStepDevName__c   = 'GridAmendment_HOC'
        );
        insert approval;

        List<CustomApprovalStep__c> steps = new List<CustomApprovalStep__c>{
            new CustomApprovalStep__c(
                CustomApproval__c     = approval.Id,
                StepDeveloperName__c  = 'GridAmendment_HOC',
                StepLabel__c         = 'HOC Approval',
                Status__c            = 'Pending',
                IsCurrentStep__c     = true,
                AssignedTo__c        = String.valueOf(UserInfo.getUserId()),
                AssignedToName__c    = 'Test User'
            )
        };
        insert steps;

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryUtility.processApproval(steps[0].Id, 'Removed', 'Test recall', null);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Recall should succeed: ' + result.errorMessage);

        CustomApproval__c updatedApproval = [SELECT Status__c, CurrentStepDevName__c FROM CustomApproval__c WHERE Id = :approval.Id];
        System.assertEquals('Recalled', updatedApproval.Status__c, 'Approval status should be Recalled');
        System.assertEquals(null, updatedApproval.CurrentStepDevName__c, 'CurrentStepDevName should be cleared');

        List<CustomApprovalStep__c> updatedSteps = [SELECT Status__c, IsCurrentStep__c FROM CustomApprovalStep__c WHERE CustomApproval__c = :approval.Id];
        for (CustomApprovalStep__c s : updatedSteps) {
            System.assertEquals('Recalled', s.Status__c, 'Step status should be Recalled');
            System.assertEquals(false, s.IsCurrentStep__c, 'IsCurrentStep should be false after recall');
        }
    }

    // ─── processApproval — Reject ────────────────────────────────────────────────

    @IsTest
    static void testProcessApproval_Reject() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = new CustomApproval__c(
            TargetRecordId__c       = String.valueOf(grid.Id),
            Status__c               = 'Pending',
            SubmittedBy__c          = UserInfo.getUserId(),
            ProcessDeveloperName__c = 'GridAmendment',
            CurrentStepDevName__c   = 'GridAmendment_HOC'
        );
        insert approval;

        CustomApprovalStep__c step = new CustomApprovalStep__c(
            CustomApproval__c     = approval.Id,
            StepDeveloperName__c  = 'GridAmendment_HOC',
            StepLabel__c         = 'HOC Approval',
            Status__c            = 'Pending',
            IsCurrentStep__c     = true,
            AssignedTo__c        = String.valueOf(UserInfo.getUserId()),
            AssignedToName__c    = 'Test User'
        );
        insert step;

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryUtility.processApproval(step.Id, 'Reject', 'Not approved', null);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Reject should succeed: ' + result.errorMessage);

        CustomApproval__c updatedApproval = [SELECT Status__c FROM CustomApproval__c WHERE Id = :approval.Id];
        System.assertEquals('Rejected', updatedApproval.Status__c, 'Approval status should be Rejected');
    }

    // ─── processApproval — Approve, no next step (final) ────────────────────────

    @IsTest
    static void testProcessApproval_Approve_NoNextStep() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = new CustomApproval__c(
            TargetRecordId__c       = String.valueOf(grid.Id),
            Status__c               = 'Pending',
            SubmittedBy__c          = UserInfo.getUserId(),
            ProcessDeveloperName__c = 'GridAmendment',
            CurrentStepDevName__c   = 'GridAmendment_DCO'
        );
        insert approval;

        CustomApprovalStep__c step = new CustomApprovalStep__c(
            CustomApproval__c     = approval.Id,
            StepDeveloperName__c  = 'GridAmendment_DCO',
            StepLabel__c         = 'DCO-DO Approval',
            Status__c            = 'Pending',
            IsCurrentStep__c     = true,
            AssignedTo__c        = String.valueOf(UserInfo.getUserId()),
            AssignedToName__c    = 'Test User'
        );
        insert step;

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryUtility.processApproval(step.Id, 'Approve', 'Final approved', null);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Final approve should succeed: ' + result.errorMessage);

        CustomApproval__c updatedApproval = [SELECT Status__c FROM CustomApproval__c WHERE Id = :approval.Id];
        System.assertEquals('Approved', updatedApproval.Status__c, 'Approval status should be Approved');
    }

    // ─── processApproval — Approve unanimous, partial (All mode, sibling still pending) ──

    @IsTest
    static void testProcessApproval_Approve_Unanimous_Partial() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = new CustomApproval__c(
            TargetRecordId__c       = String.valueOf(grid.Id),
            Status__c               = 'Pending',
            SubmittedBy__c          = UserInfo.getUserId(),
            ProcessDeveloperName__c = 'GridAmendment',
            CurrentStepDevName__c   = 'GridAmendment_DCO'
        );
        insert approval;

        List<CustomApprovalStep__c> steps = new List<CustomApprovalStep__c>{
            new CustomApprovalStep__c(
                CustomApproval__c    = approval.Id,
                StepDeveloperName__c = 'GridAmendment_DCO',
                StepLabel__c        = 'DCO-DO Approval',
                Status__c           = 'Pending',
                IsCurrentStep__c    = true,
                AssignedTo__c       = String.valueOf(UserInfo.getUserId()),
                AssignedToName__c   = 'User 1'
            ),
            new CustomApprovalStep__c(
                CustomApproval__c    = approval.Id,
                StepDeveloperName__c = 'GridAmendment_DCO',
                StepLabel__c        = 'DCO-DO Approval',
                Status__c           = 'Pending',
                IsCurrentStep__c    = true,
                AssignedTo__c       = String.valueOf(UserInfo.getUserId()),
                AssignedToName__c   = 'User 2'
            )
        };
        insert steps;

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryUtility.processApproval(steps[0].Id, 'Approve', 'First approval', null);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Partial unanimous approve should succeed: ' + result.errorMessage);

        CustomApproval__c updatedApproval = [SELECT Status__c FROM CustomApproval__c WHERE Id = :approval.Id];
        System.assertEquals('Pending', updatedApproval.Status__c, 'Approval should still be Pending (waiting for second approver)');

        List<CustomApprovalStep__c> remainingPending = [
            SELECT Id FROM CustomApprovalStep__c
            WHERE CustomApproval__c = :approval.Id AND IsCurrentStep__c = true AND Status__c = 'Pending'
        ];
        System.assertEquals(1, remainingPending.size(), 'One sibling should still be pending');
    }

    // ─── processApproval — Approve, with next step ───────────────────────────────

    @IsTest
    static void testProcessApproval_Approve_WithNextStep() {
        Grid__c grid = GridTestSetupHelper.getTestGridByName(GridTestSetupHelper.GRID_NAME_S1);
        CustomApproval__c approval = new CustomApproval__c(
            TargetRecordId__c       = String.valueOf(grid.Id),
            Status__c               = 'Pending',
            SubmittedBy__c          = UserInfo.getUserId(),
            ProcessDeveloperName__c = 'GridAmendment',
            CurrentStepDevName__c   = 'GridAmendment_HOC'
        );
        insert approval;

        CustomApprovalStep__c step = new CustomApprovalStep__c(
            CustomApproval__c     = approval.Id,
            StepDeveloperName__c  = 'GridAmendment_HOC',
            StepLabel__c         = 'HOC Approval',
            Status__c            = 'Pending',
            IsCurrentStep__c     = true,
            AssignedTo__c        = String.valueOf(UserInfo.getUserId()),
            AssignedToName__c    = 'Test User'
        );
        insert step;

        List<Id> nextApproverIds = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        CustomApprovalHistoryUtility.ProcessResult result = CustomApprovalHistoryUtility.processApproval(step.Id, 'Approve', 'HOC approved', nextApproverIds);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Approve with next step should succeed: ' + result.errorMessage);

        CustomApproval__c updatedApproval = [SELECT Status__c, CurrentStepDevName__c FROM CustomApproval__c WHERE Id = :approval.Id];
        System.assertEquals('Pending', updatedApproval.Status__c, 'Approval should remain Pending (now at next step)');
        System.assertEquals('GridAmendment_DCO', updatedApproval.CurrentStepDevName__c, 'Should advance to DCO step');

        List<CustomApprovalStep__c> newSteps = [
            SELECT Id FROM CustomApprovalStep__c
            WHERE CustomApproval__c = :approval.Id AND StepDeveloperName__c = 'GridAmendment_DCO' AND IsCurrentStep__c = true
        ];
        System.assertNotEquals(0, newSteps.size(), 'New pending steps should have been created for DCO');
    }
}
