@isTest
public class PageLayoutControllerTest {

    // Fund modification project: fields, editability and modification conditions of a stage and a Shareclass Child
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
        ProjectShareclassChild__c scChild = [SELECT Id FROM ProjectShareclassChild__c WHERE ProjectShareclasses__r.ProjectProduct__c = :proj.Id LIMIT 1];

        Test.startTest();
        PageLayoutController.getAllFieldsByRecordId(child.Id);
        PageLayoutController.getAllFieldsByRecordId(scChild.Id);
        PageLayoutController.checkEditableConidtions(child.Id, 'ProjectProductChild__c');
        PageLayoutController.checkEditableConidtions(scChild.Id, 'ProjectShareclassChild__c');
        PageLayoutController.checkModificationConidtions(child.Id, 'ProjectProductChild__c');
        PageLayoutController.checkModificationConidtions(scChild.Id, 'ProjectShareclassChild__c');
        System.assert(!PageLayoutController.checkEditableConidtions(proj.Id, 'ProjectProduct__c'), 'Only stages and Shareclass Children are editable here');
        System.assertEquals(null, PageLayoutController.checkModificationConidtions(proj.Id, 'ProjectProduct__c'), 'Only stages and Shareclass Children are checked');

        // Editable fields read from a field of the stage, or of its parent project
        PageLayoutController.getEditableFieldsFromSourceField('ISIN__c,ProjectProductParent__r.Name', 'ProjectProductChild__c', child.Id);
        System.assert(!PageLayoutController.getEditableFieldsFromSourceField('ProjectProductParent__r.Name', 'ProjectProductChild__c', child.Id).isEmpty(), 'Value of a parent field');
        System.assert(!PageLayoutController.getEditableFieldsFromSourceField('Name', 'ProjectProductChild__c', child.Id).isEmpty(), 'Value of a field of the record');
        System.assert(PageLayoutController.getEditableFieldsFromSourceField('ProjectProductParent__r.InternalShortName__c', 'ProjectProductChild__c', child.Id).isEmpty(), 'Empty parent field');

        PageLayoutController.getRecordTypeId('Product__c', product.Id);
        System.assertEquals('012000000000000AAA', PageLayoutController.getRecordTypeId('Product__c', 'invalidId'), 'Master record type on error');
        try {
            PageLayoutController.getAllFieldsByRecordId('zzz000000000000AAA');
            System.assert(false, 'Unknown object must be rejected');
        } catch (AuraHandledException e) {
            // Unsupported or unknown SObject type
        }
        Test.stopTest();
    }

    // Required fields of the PMT matrix (getFields), and an empty matrix
    @isTest
    static void test_getFields() {
        PMTTestFactoryData.createMatrice('Design', 'Legal', 'AssetClass__c;ISIN__c', 'IsValid__c;LegalType__c');

        Test.startTest();
        List<String> fundFields = PageLayoutController.getFields('ProjectProductChild__c', null);
        System.assert(fundFields.contains('AssetClass__c') && fundFields.contains('ISIN__c'), 'Required Fund fields of the matrix');

        List<String> shareClassFields = PageLayoutController.getFields('ProjectShareclassChild__c', null);
        System.assert(shareClassFields.contains('IsValid__c') && shareClassFields.contains('LegalType__c'), 'Required Share Class fields of the matrix');

        // FIX-20178: empty PMT matrix (no field rule configured)
        PMTMatrix.clearForTest();
        try {
            PageLayoutController.getFields('ProjectProductChild__c', null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            // Aucun champ trouvé
        }

        PageLayoutController.getUserPermissionSet('PRPProductStrategy');
        Test.stopTest();
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

        System.runAs(u) {
            Test.startTest();
            System.assertNotEquals(0, PageLayoutController.getEditableFields('ProjectShareclass__c', 'PRPProductStrategy', true).size(), 'View all');
            System.assertNotEquals(0, PageLayoutController.getEditableFields('ProjectShareclass__c', 'PRPProductStrategy', false).size(), 'Without view all');
            Test.stopTest();
        }
    }
}