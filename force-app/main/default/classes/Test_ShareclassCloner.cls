/** ──────────────────────────────────────
 * @description Tests of ShareclassCloner: Project Shareclass cloned from a referential Share Class and from another Project Shareclass,
 *                  junctions with a stage, and the Project Shareclass Children created with and without the share class fields.
 * @covers ShareclassCloner   94%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_ShareclassCloner {

    @isTest
    static void test_cloneShareclasses() {
        Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();
        ProjectProduct__c project = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(project.Id, 'Proposal', null);
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        Share_Class__c share = new Share_Class__c(Name = 'Original Share', Fund__c = product.Id);
        insert share;
        ProjectShareclass__c original = PMTTestFactoryData.createProjectShareclass(project.Id, 'EUR');
        original = [SELECT Id, Type__c, CurrencyIsoCode, DividendPolicy__c, CurrencyHedging__c FROM ProjectShareclass__c WHERE Id = :original.Id];

        Test.startTest();

        Id referentialCloneId = ShareclassCloner.cloneShareClass(share.Id, project.Id);
        Id projectCloneId = ShareclassCloner.cloneProjectShareClass(original.Id, project.Id);
        ShareclassCloner.createObjectJunctions(child.Id, original.Id);
        ShareclassCloner.createShareclassChildren(original.Id);
        ShareclassCloner.createShareclassChildrenWithFields(original.Id, original, 'BaseName');

        Test.stopTest();

        List<ProjectShareclass__c> clones = [SELECT ClonedByReferential__c, ClonedByProjectShareclass__c
                                             FROM ProjectShareclass__c
                                             WHERE Id IN :new List<Id>{ referentialCloneId, projectCloneId }];
        Map<Id, ProjectShareclass__c> cloneById = new Map<Id, ProjectShareclass__c>(clones);
        Integer junctionCount = [SELECT COUNT() FROM ProjectChildJunction__c WHERE ProjectShareclass__c = :original.Id];
        Integer childCount = [SELECT COUNT() FROM ProjectShareclassChild__c WHERE ProjectShareclasses__c = :original.Id];
        System.assertEquals(share.Id, cloneById.get(referentialCloneId).ClonedByReferential__c);
        System.assertEquals(original.Id, cloneById.get(projectCloneId).ClonedByProjectShareclass__c);
        System.assert(junctionCount > 0, 'Junctions of the share class');
        System.assert(childCount > 0, 'Children of the share class');
    }
}