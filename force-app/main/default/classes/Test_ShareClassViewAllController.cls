/** ──────────────────────────────────────
 * @description Tests of ShareClassViewAllController.getProjectShareclasses: share classes of a Fund creation project with the metadata
 *                  of their fields.
 * @covers ShareClassViewAllController   96%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_ShareClassViewAllController {

    @isTest
    static void test_getProjectShareclasses() {
        ProjectProduct__c parentProject = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));
        ProjectProductChild__c child = PMTTestFactoryData.createProjectProductChild(parentProject.Id, 'Proposal', null);
        ProjectShareclass__c shareclass = PMTTestFactoryData.createProjectShareclass(parentProject.Id, 'EUR');
        PMTTestFactoryData.createJunction(child.Id, shareclass.Id);

        Test.startTest();

        List<ShareClassViewAllController.ShareClassWrapper> result = ShareClassViewAllController.getProjectShareclasses(parentProject.Id);

        Test.stopTest();

        System.assert(!result.isEmpty(), 'Il doit y avoir au moins une shareclass retournée');
        System.assert(!result[0].fields.isEmpty(), 'Il doit y avoir des métadonnées de champs');
    }
}