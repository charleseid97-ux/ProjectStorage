/** ──────────────────────────────────────
 * @description Tests of PageLayoutController (layoutEditableFields and projectChildTeamValidation LWCs): fields, editability and
 *                  modification conditions of a stage and a Shareclass Child, and the fields of a team's screen (getFieldStates,
 *                  US-20194 V1.2): the team's lines at the record's stage whose condition applies (ISIN__c on Legal's Filing screen of
 *                  an FCP fund, not on OPS's), required from the line or its RequiredCondition__c with the unsaved values, editable with
 *                  the team's custom permission only.
 * @covers PageLayoutController   97%   [26-10-26]
 * @lastModifiedBy Charles EID   [26-10-26]
 ────────────────────────────────────── */
@isTest
public class PageLayoutControllerTest {

    // Fund modification project: fields, editability and modification conditions of a stage and a Shareclass Child, then an empty matrix
    @isTest
    static void test_modificationProject() {
        Id rtParent = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundShareClassModification');
        Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();

        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        insert new Share_Class__c(Name = 'Test Share', Fund__c = product.Id);

        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(rtParent);
        proj.Product__c = product.Id;
        update proj;

        ProjectProductChild__c child = [SELECT Id FROM ProjectProductChild__c WHERE ProjectProductParent__c = :proj.Id LIMIT 1];
        ShareclassNavigatorController.createAndLinkShareclass(child.Id, 'A', 'EUR', 'Accumulating', 'Annually', 'False');

        Milestone__c milestone = PMTTestFactoryData.createMilestone(proj.Id, 'SPC Final', proj.EndDate__c);
        milestone.Status__c = 'Completed';
        update milestone;
        child.TECH_TeamValidation__c = 'ProductStrategy';
        update child;
        ProjectShareclassChild__c scChild = [SELECT Id, ProjectShareclasses__c
                                             FROM ProjectShareclassChild__c
                                             WHERE ProjectShareclasses__r.ProjectProduct__c = :proj.Id LIMIT 1];

        Test.startTest();

        PageLayoutController.getAllFieldsByRecordId(child.Id);
        PageLayoutController.getAllFieldsByRecordId(scChild.Id);
        PageLayoutController.checkEditableConidtions(child.Id, 'ProjectProductChild__c');
        PageLayoutController.checkEditableConidtions(scChild.Id, 'ProjectShareclassChild__c');
        PageLayoutController.checkModificationConidtions(child.Id, 'ProjectProductChild__c');
        PageLayoutController.checkModificationConidtions(scChild.Id, 'ProjectShareclassChild__c');
        Boolean projectEditable = PageLayoutController.checkEditableConidtions(proj.Id, 'ProjectProduct__c');
        SObject projectModification = PageLayoutController.checkModificationConidtions(proj.Id, 'ProjectProduct__c');
        String configurationWarning = PageLayoutController.getPMTConfigurationWarning();

        // Editable fields read from a field of the stage, or of its parent project
        PageLayoutController.getEditableFieldsFromSourceField('ISIN__c,ProjectProductParent__r.Name', 'ProjectProductChild__c', child.Id);
        List<String> parentFieldValue = PageLayoutController.getEditableFieldsFromSourceField('ProjectProductParent__r.Name', 'ProjectProductChild__c', child.Id);
        List<String> recordFieldValue = PageLayoutController.getEditableFieldsFromSourceField('Name', 'ProjectProductChild__c', child.Id);
        List<String> emptyParentFieldValue = PageLayoutController.getEditableFieldsFromSourceField('ProjectProductParent__r.InternalShortName__c', 'ProjectProductChild__c', child.Id);

        PageLayoutController.getRecordTypeId('Product__c', product.Id);
        String invalidRecordTypeId = PageLayoutController.getRecordTypeId('Product__c', 'invalidId');
        Boolean unknownObjectRejected = false;
        try {
            PageLayoutController.getAllFieldsByRecordId('zzz000000000000AAA');
        }
        catch (AuraHandledException e) {
            unknownObjectRejected = true;
        }

        // FIX-20178: empty PMT matrix (no field rule configured)
        PMTTestFactoryData.clearMatrix();
        Boolean emptyMatrixRejected = false;
        try {
            PageLayoutController.getFieldStates(child.Id, 'PRPProductStrategy', null);
        }
        catch (AuraHandledException e) {
            emptyMatrixRejected = true;
        }

        Test.stopTest();

        System.assert(!projectEditable, 'Only stages and Shareclass Children are editable here');
        System.assertEquals(null, projectModification, 'Only stages and Shareclass Children are checked');
        System.assertEquals(null, configurationWarning, 'Every PMT line field exists in this org: no warning');
        System.assert(!parentFieldValue.isEmpty(), 'Value of a parent field');
        System.assert(!recordFieldValue.isEmpty(), 'Value of a field of the record');
        System.assert(emptyParentFieldValue.isEmpty(), 'Empty parent field');
        System.assertEquals(System.Label.MasterRecordTypeId, invalidRecordTypeId, 'Master record type on error');
        System.assert(unknownObjectRejected, 'Unknown object must be rejected');
        System.assert(emptyMatrixRejected, 'No field rule configured: AuraHandledException');
    }

    // US-20194 V1.2: team screens of the Filing share class of an FR FCP fund: what each team sees, what is required (also with unsaved values), who can edit
    @isTest
    static void test_getFieldStates() {
        ProjectProduct__c project = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));
        project.LegalForm__c = 'FCP';
        update project;
        ProjectShareclass__c shareClass = PMTTestFactoryData.createProjectShareclass(project.Id, null);
        ProjectShareclassChild__c filing = [SELECT Id
                                            FROM ProjectShareclassChild__c
                                            WHERE ProjectShareclasses__c = :shareClass.Id AND TECH_Childtype__c = 'Filing' LIMIT 1];
        ProjectProductChild__c fundFiling = [SELECT Id
                                             FROM ProjectProductChild__c
                                             WHERE ProjectProductParent__c = :project.Id AND TECH_Childtype__c = 'Filing' LIMIT 1];

        // Owner of Legal's fields (custom permission PRPLegal) and a viewer without it, both able to edit the fields
        Profile admin = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        String suffix = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User legalUser = newUser('pmtleg', suffix, admin.Id);
        User otherUser = newUser('pmtoth', suffix, admin.Id);
        CustomPermission legalPermission = [SELECT Id FROM CustomPermission WHERE DeveloperName = 'PRPLegal' LIMIT 1];
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new List<User>{ legalUser, otherUser }; // Setup objects: inserted apart from the project DML (mixed DML)
            PermissionSet legalPermissionSet = new PermissionSet(Name = 'PMTLegalTest' + suffix, Label = 'PMT Legal Test ' + suffix);
            PermissionSet fieldAccess = new PermissionSet(Name = 'PMTFieldTest' + suffix, Label = 'PMT Field Test ' + suffix);
            insert new List<PermissionSet>{ legalPermissionSet, fieldAccess };
            insert new SetupEntityAccess(ParentId = legalPermissionSet.Id, SetupEntityId = legalPermission.Id);
            insert new FieldPermissions(ParentId = fieldAccess.Id, SobjectType = 'ProjectShareclassChild__c', Field = 'ProjectShareclassChild__c.ISIN__c', PermissionsRead = true, PermissionsEdit = true);
            insert new List<PermissionSetAssignment>{
                new PermissionSetAssignment(AssigneeId = legalUser.Id, PermissionSetId = legalPermissionSet.Id),
                new PermissionSetAssignment(AssigneeId = legalUser.Id, PermissionSetId = fieldAccess.Id),
                new PermissionSetAssignment(AssigneeId = otherUser.Id, PermissionSetId = fieldAccess.Id)
            };
        }

        // Test matrix: ISIN__c Legal (FCP) or OPS (SICAV); MaxPerfFees__c Risk with performance fees, required when not OEIC; ProductName__c Legal on the fund
        PMTTestFactoryData.clearMatrix();
        PMTTestFactoryData.createMatrixLine('Filing', 'Legal', 'Share_Class__c', 'ISIN__c', 'Required', 'ISPICKVAL(ProjectProduct__c.LegalForm__c, \'FCP\')');
        PMTTestFactoryData.createMatrixLine('Filing', 'OPS', 'Share_Class__c', 'ISIN__c', 'Required', 'ISPICKVAL(ProjectProduct__c.LegalForm__c, \'SICAV\')');
        PMTTestFactoryData.createMatrixLine('Filing', 'Risk', 'Share_Class__c', 'MaxPerfFees__c', 'Conditional', 'ISPICKVAL(ProjectShareclass__c.HasPerfFees__c, \'True\')', 'NOT(ISPICKVAL(ProjectProduct__c.LegalForm__c, \'OEIC\'))');
        PMTTestFactoryData.createMatrixLine('Filing', 'Legal', 'Product__c', 'ProductName__c', 'Optional', null);

        Map<String, Object> legalScreen;
        Map<String, Object> legalScreenForOther;
        Map<String, Object> opsScreen;
        Map<String, Object> riskScreen;
        Map<String, Object> riskScreenWithPerfFees;
        Map<String, Object> fundScreen;
        Map<String, Object> parentScreen;
        Map<String, Object> blankTeamScreen;
        Map<String, Object> invalidTeamScreen;

        Test.startTest();

        System.runAs(legalUser) {
            legalScreen = PageLayoutController.getFieldStates(filing.Id, 'PRPLegal', null);
            fundScreen = PageLayoutController.getFieldStates(fundFiling.Id, 'PRPLegal', null);
            parentScreen = PageLayoutController.getFieldStates(shareClass.Id, 'PRPLegal', null);
        }
        System.runAs(otherUser) {
            legalScreenForOther = PageLayoutController.getFieldStates(filing.Id, 'PRPLegal', null);
            opsScreen = PageLayoutController.getFieldStates(filing.Id, 'PRPOPS', null);
            riskScreen = PageLayoutController.getFieldStates(filing.Id, 'PRPRisk', new Map<String, Object>{ 'HasPerfFees__c' => 'False' });
            riskScreenWithPerfFees = PageLayoutController.getFieldStates(filing.Id, 'PRPRisk', new Map<String, Object>{ 'HasPerfFees__c' => 'True', 'Name' => null });
            blankTeamScreen = PageLayoutController.getFieldStates(filing.Id, '', null);
            invalidTeamScreen = PageLayoutController.getFieldStates(filing.Id, 'PRP Legal', null);
        }

        Test.stopTest();

        Map<String, Object> legalFields = (Map<String, Object>) legalScreen.get('fields');
        Map<String, Object> legalFieldsForOther = (Map<String, Object>) legalScreenForOther.get('fields');
        Map<String, Object> riskFields = (Map<String, Object>) riskScreenWithPerfFees.get('fields');
        Map<String, Object> parentFields = (Map<String, Object>) parentScreen.get('fields');
        Map<String, Boolean> legalIsin = (Map<String, Boolean>) legalFields.get('ISIN__c');
        System.assertEquals(new Set<String>{ 'ISIN__c' }, legalFields.keySet(), 'FCP fund: Legal\'s Filing screen shows ISIN__c (Share Class fields only on a share class stage)');
        System.assert(legalIsin.get('required') && legalIsin.get('editable'), 'Required, and editable by the owner of Legal\'s fields');
        System.assert(!((Map<String, Boolean>) legalFieldsForOther.get('ISIN__c')).get('editable'), 'Seen by everyone, editable only with the PRPLegal custom permission');
        System.assert(((Map<String, Object>) opsScreen.get('fields')).isEmpty(), 'FCP fund: the OPS line condition is false, ISIN__c is not on OPS\'s screen');
        System.assert(((Map<String, Object>) riskScreen.get('fields')).isEmpty(), 'Without performance fees (unsaved value): no MaxPerfFees__c');
        System.assert(((Map<String, Boolean>) riskFields.get('MaxPerfFees__c')).get('required'), 'With performance fees (unsaved value) on a non-OEIC fund: MaxPerfFees__c required');
        System.assert(((List<String>) riskScreenWithPerfFees.get('conditionFields')).contains('HasPerfFees__c'), 'A change of HasPerfFees__c re-evaluates the screen');
        System.assert(((Map<String, Object>) fundScreen.get('fields')).containsKey('ProductName__c'), 'Fund stage: Legal\'s Fund fields');
        System.assert(!((Map<String, Boolean>) parentFields.get('ISIN__c')).get('editable'), 'Project share class page: every stage of the team, read-only');
        System.assert(((Map<String, Object>) blankTeamScreen.get('fields')).isEmpty() && ((Map<String, Object>) invalidTeamScreen.get('fields')).isEmpty(), 'No or invalid c__team: empty screen, no error');
    }

    private static User newUser(String alias, String suffix, Id profileId) {
        String username = alias + suffix + '@pagelayout.test';
        return new User(Alias = alias, Email = username, Username = username, LastName = 'PageLayout', ProfileId = profileId,
                        EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', TimeZoneSidKey = 'Europe/Paris');
    }
}