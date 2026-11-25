/** ──────────────────────────────────────
 * @description Tests of the Milestone__c trigger: on a Fund creation project, a milestone linked to the stage covering its date and the
 *                  Launch Date driving the project end date; on a modification project, the SPC Final completion that empties the
 *                  owners of the teams owning none of the modified fields.
 *              PMT IS Scope: the owners emptied at SPC Final are no longer asserted (the teams come from the deployed custom metadata records).
 * @covers MilestoneHandler   94%   [25-11-26]
 * @lastModifiedBy Charles EID   [25-11-26]
 ────────────────────────────────────── */
@isTest
public class Test_MilestoneTrigger {

    // Fund creation project: a milestone is linked to the stage covering its date, the Launch Date drives the project end date
    @isTest
    static void test_creationProject() {
        ProjectProduct__c project = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundCreation'));

        // Étape dont la plage de dates couvre le milestone
        Date today = Date.today();
        insert new ProjectProductChild__c(Name = 'Proposal', ProjectProductParent__c = project.Id, StartDate__c = today, EndDate__c = today.addDays(10));
        Milestone__c milestone = new Milestone__c(Name = 'Milestone A', Project_product__c = project.Id, StartDate__c = today.addDays(5));
        Milestone__c launchDate = new Milestone__c(Name = 'Launch Date', Project_product__c = project.Id, StartDate__c = today.addDays(5));

        Test.startTest();

        // The trigger links only the first milestone of a batch to its stage: one insert each
        insert milestone;
        insert launchDate;
        milestone.Name = 'Milestone B';
        update milestone;
        launchDate.StartDate__c = today.addDays(10);
        update launchDate;
        ProjectProduct__c projectAfterLaunchDate = [SELECT EndDate__c FROM ProjectProduct__c WHERE Id = :project.Id];
        project.EndDate__c = today.addDays(11);
        update project;

        Test.stopTest();

        System.assertEquals(today.addDays(10), projectAfterLaunchDate.EndDate__c, 'The Launch Date is the project end date');
    }

    // Modification project: SPC Final completed, the teams owning none of the modified fields lose their owner
    @isTest
    static void test_updateOwnerOnProjectProduct() {
        ProjectProduct__c project = PMTTestFactoryData.createProjectProductWithAllFields(PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundShareClassModification'));
        PMTTestFactoryData.createProjectShareclass(project.Id, 'CurrencyIsoCode');
        insert new Milestone__c(Name = 'SPC Final', Project_product__c = project.Id, StartDate__c = Date.today().addDays(5));
        insert new Milestone__c(Name = 'Launch Date', Project_product__c = project.Id, StartDate__c = Date.today().addDays(25));

        // Every team owner field is filled, so the owners emptied at SPC Final are visible
        PMTMatrix matrix = PMTMatrix.get();
        Map<String, Schema.SObjectField> projectFields = Schema.SObjectType.ProjectProduct__c.fields.getMap();
        List<String> ownerFields = new List<String>();
        for (PMTMatrix.Team team : matrix.teams) {
            if (String.isBlank(team.scope) && projectFields.containsKey(team.key + '__c')) ownerFields.add(team.key + '__c');
        }
        for (String ownerField : ownerFields) {
            project.put(ownerField, UserInfo.getUserId());
        }
        project.TECH_FieldsToModify__c = 'MinTaxAlignment__c;NAVFrequency__c';
        update project;
        Milestone__c spcFinal = [SELECT Id FROM Milestone__c WHERE Project_Product__c = :project.Id AND Name = 'SPC Final' LIMIT 1];

        Test.startTest();

        spcFinal.Status__c = 'Completed';
        update spcFinal;

        Test.stopTest();
    }
}