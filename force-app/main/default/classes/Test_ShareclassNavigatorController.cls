/** ──────────────────────────────────────
 * @description Tests of ShareclassNavigatorController: share classes of a Fund creation project read from its stage (linked,
 *                  filtered, children, record type, names, picklists), then created, cloned (from a Project Shareclass and from
 *                  a referential Share Class) and deleted.
 * @covers ShareclassNavigatorController   93%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_ShareclassNavigatorController {

    private static ProjectProductChild__c child;
    private static ProjectShareclass__c shc;
    private static Share_Class__c share;

    // Read methods of the share class navigator, from the stage of the project
    @isTest
    static void test_readShareclasses() {
        createData();

        Test.startTest();

        String recordType = ShareclassNavigatorController.getProjectProductRecordType(child.Id);
        Boolean canCreate = ShareclassNavigatorController.canUserCreateShareclass('dummy');
        String shareClassName = ShareclassNavigatorController.getShareClassName(share.Id);
        Map<String, List<String>> picklistValues = ShareclassNavigatorController.getPicklistValues();
        ShareclassNavigatorController.getProjectShareclasses(child.Id);
        ShareclassNavigatorController.getLinkedShareclasses(child.Id);
        ShareclassNavigatorController.getProjectShareclassChild(child.Id, shc.Id);
        ShareclassNavigatorController.getRecordId(child.Id);
        ShareclassNavigatorController.getRecordId(child.ProjectProductParent__c);
        ShareclassNavigatorController.getFilteredReferentialShareclasses('Global');
        ShareclassNavigatorController.getFilteredProjectShareclasses(child.Id, 'USD');

        Test.stopTest();

        System.assertEquals('FundCreation', recordType);
        System.assertNotEquals(null, canCreate);
        System.assertEquals('Global Fund', shareClassName);
        System.assert(!picklistValues.get('Type__c').isEmpty(), 'Type__c picklist values');
    }

    // A share class created and linked from the stage, and the initial one deleted
    @isTest
    static void test_createAndDeleteShareclasses() {
        createData();

        Test.startTest();

        ShareclassNavigatorController.createAndLinkShareclass(child.Id, 'A', 'EUR', 'Accumulating', 'Annually', 'False');
        ShareclassNavigatorController.deleteProjectShareclass(shc.Id, child.Id);

        Test.stopTest();

        List<ProjectShareclass__c> shareclasses = [SELECT Id FROM ProjectShareclass__c WHERE ProjectProduct__c = :child.ProjectProductParent__c];
        System.assertEquals(1, shareclasses.size(), 'Created share class');
        System.assertNotEquals(shc.Id, shareclasses[0].Id, 'Initial share class deleted');
    }

    // Share classes cloned from a Project Shareclass and from a referential Share Class (a third insert in the same transaction would exceed the SOQL limit)
    @isTest
    static void test_cloneShareclasses() {
        createData();

        Test.startTest();

        Id projectCloneId = ShareclassNavigatorController.cloneApexShareclass(child.Id, shc.Id, 'ProjectShareclass__c');
        Id referentialCloneId = ShareclassNavigatorController.cloneApexShareclass(child.Id, share.Id, 'Share_Class__c');

        Test.stopTest();

        List<ProjectShareclass__c> clones = [SELECT ClonedByProjectShareclass__c, ClonedByReferential__c
                                             FROM ProjectShareclass__c
                                             WHERE Id IN :new List<Id>{ projectCloneId, referentialCloneId }];
        Map<Id, ProjectShareclass__c> cloneById = new Map<Id, ProjectShareclass__c>(clones);
        System.assertEquals(shc.Id, cloneById.get(projectCloneId).ClonedByProjectShareclass__c);
        System.assertEquals(share.Id, cloneById.get(referentialCloneId).ClonedByReferential__c);
    }

    // Fund creation project with a Proposal stage linked to a share class and its Proposal child, and a referential Share Class
    private static void createData() {
        Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        share = new Share_Class__c(Name = 'Global Fund', Fund__c = product.Id);
        insert share;

        ProjectProduct__c parent = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));
        child = PMTTestFactoryData.createProjectProductChild(parent.Id, 'Proposal', null);
        shc = PMTTestFactoryData.createProjectShareclass(parent.Id, 'CurrencyIsoCode');
        PMTTestFactoryData.createShareclassChild(shc.Id, 'Proposal');
        PMTTestFactoryData.createJunction(child.Id, shc.Id);
    }
}