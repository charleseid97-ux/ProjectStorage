/** ──────────────────────────────────────
 * @description Tests of the ProjectProductChild__c trigger on a modification project: the active share classes of the fund cloned into Project Share Classes linked to
 *                  every phase, a field edited on a phase copied to the project, and the completion rate of a Completed phase of a modification project (100).
 * @covers ProjectProductChildHandler   93%   [21-10-26]
 * @covers ProjectProductChildTriggerHandler   100%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
private class Test_ProjectProductChildTriggerHandler {

    @isTest
    static void test_modificationProjectPhases() {
        Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        Share_Class__c shareClass = new Share_Class__c(Name = 'Test Share', Fund__c = product.Id, Status__c = 'Active');
        insert shareClass;

        ProjectProduct__c project = new ProjectProduct__c(
            Name = 'Test Project Full',
            RecordTypeId = PMTTestFactoryData.getRecordTypeId('ProjectProduct__c', 'FundShareClassModification'),
            VehicleType__c = 'Funds',
            ProjectStartDate__c = Date.today() - 20,
            EndDate__c = Date.today(),
            RiskAssociated__c = 'Equity;Interest rates;Credit;Currency',
            InvestmentObjective__c = 'Sample Objective',
            InvestmentStrategy__c = 'Sample Strategy',
            DomiciledIn__c = 'FR',
            ProjectStatus__c = 'Closed',
            ProductName__c = 'toto',
            Product__c = product.Id,
            LettreRequise__c = 'No',
            TECH_FieldsToModify__c = 'InternalShortName__c'
        );
        insert project;
        Map<String, ProjectProductChild__c> phaseByName = new Map<String, ProjectProductChild__c>();
        for (ProjectProductChild__c phase : [SELECT Id, Name FROM ProjectProductChild__c WHERE ProjectProductParent__c = :project.Id]) {
            phaseByName.put(phase.Name, phase);
        }

        Test.startTest();

        ProjectProductChild__c proposal = phaseByName.get('Proposal');
        proposal.InternalShortName__c = 'NEWNAME';
        ProjectProductChild__c engineering = phaseByName.get('Engineering');
        engineering.Status__c = 'Completed';
        update new List<ProjectProductChild__c>{ proposal, engineering };

        Test.stopTest();

        List<ProjectShareclass__c> projectShareclasses = [SELECT Id, Tech_ShareClass__c
                                                          FROM ProjectShareclass__c
                                                          WHERE ProjectProduct__c = :project.Id];
        Integer junctionCount = [SELECT COUNT() FROM ProjectChildJunction__c WHERE ProjectShareclass__c = :projectShareclasses[0].Id];
        ProjectProduct__c updatedProject = [SELECT InternalShortName__c FROM ProjectProduct__c WHERE Id = :project.Id];
        ProjectProductChild__c completedPhase = [SELECT CompletionRateStep__c FROM ProjectProductChild__c WHERE Id = :engineering.Id];
        System.assertEquals(1, projectShareclasses.size(), 'The active share class of the fund is cloned');
        System.assertEquals(shareClass.Id, projectShareclasses[0].Tech_ShareClass__c);
        System.assertEquals(phaseByName.size(), junctionCount, 'The cloned share class is linked to every phase');
        System.assertEquals('NEWNAME', updatedProject.InternalShortName__c, 'A field edited on a phase is copied to the project');
        System.assertEquals(100, completedPhase.CompletionRateStep__c, 'A Completed phase of a modification project is at 100');
    }
}