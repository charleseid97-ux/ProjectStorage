/** ──────────────────────────────────────
 * @description Tests of PageLayoutController (layoutEditableFields and projectChildTeamValidation LWCs): fields, editability and
 *                  modification conditions of a stage and a Shareclass Child, editable fields from the PRP permission sets, and the
 *                  required fields of the PMT matrix (US-20194: according to the conditions of the record's project).
 * @covers PageLayoutController   94%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class PageLayoutControllerTest {

    // Fund modification project: fields, editability and modification conditions of a stage and a Shareclass Child, then the required fields of a test matrix
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

        // US-20194: required fields according to the conditions of the record's project, and of its share class
        PMTMatrix projectMatrix = PMTMatrix.get().forConditions(proj);
        List<String> expectedFundFields = projectMatrix.getRequiredFields(true);
        List<String> stageFundFields = PageLayoutController.getFields('ProjectProductChild__c', child.Id);
        List<String> shareClassFieldsFromStage = PageLayoutController.getFields('ProjectShareclassChild__c', scChild.Id);
        List<String> shareClassFieldsFromShareclass = PageLayoutController.getFields('ProjectShareclassChild__c', scChild.ProjectShareclasses__c);

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

        // Required fields of the PMT matrix without a record (getFields), then an empty matrix
        PMTTestFactoryData.createMatrice('Design', 'Legal', 'AssetClass__c;ISIN__c', 'IsValid__c;LegalType__c');
        List<String> fundFields = PageLayoutController.getFields('ProjectProductChild__c', null);
        List<String> shareClassFields = PageLayoutController.getFields('ProjectShareclassChild__c', null);

        // FIX-20178: empty PMT matrix (no field rule configured)
        PMTTestFactoryData.clearMatrix();
        Boolean emptyMatrixRejected = false;
        try {
            PageLayoutController.getFields('ProjectProductChild__c', null);
        }
        catch (AuraHandledException e) {
            emptyMatrixRejected = true;
        }
        PageLayoutController.getUserPermissionSet('PRPProductStrategy');

        Test.stopTest();

        System.assert(!projectEditable, 'Only stages and Shareclass Children are editable here');
        System.assertEquals(null, projectModification, 'Only stages and Shareclass Children are checked');
        System.assertEquals(expectedFundFields, stageFundFields, 'Required Fund fields of the project');
        System.assertEquals(shareClassFieldsFromStage, shareClassFieldsFromShareclass, 'Same share class from its stage or its Project Shareclass');
        System.assert(!parentFieldValue.isEmpty(), 'Value of a parent field');
        System.assert(!recordFieldValue.isEmpty(), 'Value of a field of the record');
        System.assert(emptyParentFieldValue.isEmpty(), 'Empty parent field');
        System.assertEquals('012000000000000AAA', invalidRecordTypeId, 'Master record type on error');
        System.assert(unknownObjectRejected, 'Unknown object must be rejected');
        System.assert(fundFields.contains('AssetClass__c') && fundFields.contains('ISIN__c'), 'Required Fund fields of the matrix');
        System.assert(shareClassFields.contains('IsValid__c') && shareClassFields.contains('LegalType__c'), 'Required Share Class fields of the matrix');
        System.assert(emptyMatrixRejected, 'No field rule configured: AuraHandledException');
    }

    // Editable fields from the user's PRP permission set, with and without "view all"
    @isTest
    static void test_getEditableFields() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@test.com',
            Username = 'testuser@test.com.' + System.currentTimeMillis(),
            Alias = 'test',
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'fr_FR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'fr',
            ProfileId = p.Id
        );
        insert u;

        PermissionSet psMin = [SELECT Id FROM PermissionSet WHERE Name = 'PRPMinimumAccess'];
        PermissionSet psPS = [SELECT Id FROM PermissionSet WHERE Name = 'PRPProductStrategy'];
        insert new List<PermissionSetAssignment>{
            new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = psMin.Id),
            new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = psPS.Id)
        };

        Map<String, Boolean> viewAllFields;
        Map<String, Boolean> editableFields;
        System.runAs(u) {
            Test.startTest();

            viewAllFields = PageLayoutController.getEditableFields('ProjectShareclass__c', 'PRPProductStrategy', true);
            editableFields = PageLayoutController.getEditableFields('ProjectShareclass__c', 'PRPProductStrategy', false);

            Test.stopTest();
        }

        System.assertNotEquals(0, viewAllFields.size(), 'View all');
        System.assertNotEquals(0, editableFields.size(), 'Without view all');
    }
}