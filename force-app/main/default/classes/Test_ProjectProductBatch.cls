/** ──────────────────────────────────────
 * @description Tests of ProjectProductBatch, launched by its scheduler on one project per type: fund creation (created
 *                  product with its Scope__c and PMTScope__c, share classes), fund/share class modification, share class
 *                  creation, and a project not ready for launch (skipped). The controller's error paths are tested
 *                  directly (no project enriched, project without product).
 * @lastModifiedBy Charles EID   [21-10-26]
 * @covers ProjectProductBatch   85%   [21-10-26]
 * @covers ProjectProductBatchController   94%   [21-10-26]
 * @covers ProjectProductBatchUtilities   80%   [21-10-26]
 * @covers ProjectProductBatchScheduler   100%   [21-10-26]
 ────────────────────────────────────── */
@isTest
private class Test_ProjectProductBatch {

    private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();
    private static final Id fundModificationRtId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();
    private static final Id shareclassCreationRtId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('ShareclassCreation').getRecordTypeId();
    private static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();

    @testSetup
    static void setupData() {
        // Single DML per object: the PMT triggers run many queries per DML
        Product__c fundToModify = new Product__c(RecordTypeId = fundRecordTypeId, Name = 'FundModCode', ProductName__c = 'Fund To Modify', Validity__c = true);
        Product__c fundForShareclass = new Product__c(RecordTypeId = fundRecordTypeId, Name = 'ShareClsProd', ProductName__c = 'Fund For Shareclass', Validity__c = true);
        insert new List<Product__c>{ fundToModify, fundForShareclass };

        // Fund creation, modification, share class creation, and a fund creation not ready for launch (its PMT steps and Launch Date milestone are kept)
        ProjectProduct__c fundCreation = buildProject(fundCreationRtId);
        ProjectProduct__c modification = buildProject(fundModificationRtId);
        ProjectProduct__c shareclassCreation = buildProject(shareclassCreationRtId);
        List<ProjectProduct__c> projects = new List<ProjectProduct__c>{ fundCreation, modification, shareclassCreation, buildProject(fundCreationRtId) };
        insert projects;

        // The insert recalculates EndDate__c from the PMT steps: it is set back to today, the batch launches the projects ending today
        for (ProjectProduct__c project : projects) {
            project.EndDate__c = Date.today();
        }

        // Products set after insert, as in the PMT flow (not cloned into the project); the modification selects the product narrative fields
        modification.Product__c = fundToModify.Id;
        modification.InvestmentObjective__c = 'Test Content';
        modification.IntentedRetailInvestor__c = 'Test Retail';
        modification.ReasonForRHP__c = 'Test Reason';
        modification.TECH_FieldsToModify__c = 'InvestmentObjective__c;RiskAssociated__c;IntentedRetailInvestor__c;ReasonForRHP__c';
        shareclassCreation.Product__c = fundForShareclass.Id;
        update projects;

        Share_Class__c shareclassToModify = new Share_Class__c(Name = 'SC To Modify', Fund__c = fundToModify.Id, Validity__c = true);
        insert shareclassToModify;

        ProjectShareclass__c fundCreationSc = buildProjectShareclass(fundCreation.Id, 'CurrencyIsoCode;Type__c');
        ProjectShareclass__c modificationSc = buildProjectShareclass(modification.Id, 'Name');
        ProjectShareclass__c shareclassCreationSc = buildProjectShareclass(shareclassCreation.Id, 'CurrencyIsoCode;Type__c');
        insert new List<ProjectShareclass__c>{ fundCreationSc, modificationSc, shareclassCreationSc };

        // The modification updates the existing share class and its narrative fields
        modificationSc.TECH_ShareClass__c = shareclassToModify.Id;
        modificationSc.ShareclassInvestmentObjective__c = 'Test';
        modificationSc.PerformanceFeeUCITSKIID__c = 'Test';
        modificationSc.PerformanceFeeEPTKID__c = 'Test';
        modificationSc.TECH_FieldsToModify__c = 'ShareclassInvestmentObjective__c;PerformanceFeeUCITSKIID__c;PerformanceFeeEPTKID__c';
        update modificationSc;

        FundManager__c manager = PMTTestFactoryData.createFundManager('Test Manager');
        PMTTestFactoryData.createFundManagerAssignment(fundCreation.Id, manager.Id);

        insert new List<TaxData__c>{
            new TaxData__c(ProjectProduct__c = fundCreation.Id, ProjectShareclass__c = fundCreationSc.Id, Country__c = 'AT', Type__c = 'Transparency', Status__c = 'Requested', Source__c = 'PMT'),
            new TaxData__c(ProjectProduct__c = shareclassCreation.Id, ProjectShareclass__c = shareclassCreationSc.Id, Country__c = 'AT', Type__c = 'Transparency', Status__c = 'Requested', Source__c = 'PMT')
        };

        // Ready for launch: every step is done (steps deleted) and the Launch Date milestone created by the PMT is completed
        Set<Id> readyProjectIds = new Set<Id>{ fundCreation.Id, modification.Id, shareclassCreation.Id };
        List<ProjectProductChild__c> steps = [SELECT Id FROM ProjectProductChild__c WHERE ProjectProductParent__c IN :readyProjectIds];
        delete steps;

        List<Milestone__c> launchMilestones = [SELECT Id FROM Milestone__c WHERE Project_Product__c IN :readyProjectIds AND Name = 'Launch Date'];
        for (Milestone__c milestone : launchMilestones) {
            milestone.Status__c = 'Completed';
        }
        update launchMilestones;
    }

    // The scheduler launches the batch on the 4 projects: the 3 ready ones are launched, the other one is skipped
    @isTest
    static void testBatchLaunchesReadyProjects() {
        Test.startTest();

        new ProjectProductBatchScheduler().execute(null);

        Test.stopTest();

        Map<Id, ProjectProduct__c> projectsByRecordType = new Map<Id, ProjectProduct__c>();
        ProjectProduct__c notReadyProject;
        List<ProjectProduct__c> projects = [SELECT Id, RecordTypeId, LaunchedDate__c, (SELECT Id FROM Milestones__r WHERE Name = 'Launch Date' AND Status__c = 'Completed')
                                            FROM ProjectProduct__c];
        for (ProjectProduct__c project : projects) {
            if (project.Milestones__r.isEmpty()) {
                notReadyProject = project;
            }
            else {
                projectsByRecordType.put(project.RecordTypeId, project);
            }
        }

        PMTBatchLog__c batchLog = [SELECT Status__c, ErrorMessages__c FROM PMTBatchLog__c LIMIT 1];
        for (ProjectProduct__c project : projectsByRecordType.values()) {
            System.assertEquals(Date.today(), project.LaunchedDate__c, 'A ready project should be launched. Batch errors: ' + batchLog.ErrorMessages__c);
        }
        System.assertEquals(null, notReadyProject.LaunchedDate__c, 'A project with steps and milestone not completed should not be launched');

        // Fund creation: US-20123, the product takes its project's Scope (PS for a user without PRPIS) and PMTScope__c = true
        Id fundCreationId = projectsByRecordType.get(fundCreationRtId).Id;
        List<Product__c> createdProducts = [SELECT Id, RecordTypeId, Validity__c, Scope__c, PMTScope__c, (SELECT Id FROM Share_Classes__r)
                                            FROM Product__c
                                            WHERE ParentProject__c = :fundCreationId];
        System.assertEquals(1, createdProducts.size(), 'The batch should create one Product__c for the fund creation project');
        System.assertEquals(fundRecordTypeId, createdProducts[0].RecordTypeId);
        System.assertEquals(true, createdProducts[0].Validity__c);
        System.assertEquals('PS', createdProducts[0].Scope__c, 'The product should take the project Scope');
        System.assertEquals(true, createdProducts[0].PMTScope__c, 'A product created by the PMT should have PMTScope__c checked');
        System.assertEquals(1, createdProducts[0].Share_Classes__r.size(), 'The project share class should be created under the new product');

        // Modification: the existing share class gets the launch date as ESMA application start date
        Share_Class__c modifiedShareclass = [SELECT ESMAApplicationStartDate__c FROM Share_Class__c WHERE Name = 'SC To Modify'];
        System.assertEquals(Date.today(), modifiedShareclass.ESMAApplicationStartDate__c);

        // Share class creation: the new share class is active and its tax data is linked to it
        List<Share_Class__c> createdShareclasses = [SELECT Id, Status__c FROM Share_Class__c WHERE Fund__r.Name = 'ShareClsProd'];
        System.assertEquals(1, createdShareclasses.size());
        System.assertEquals('Active', createdShareclasses[0].Status__c);
        Id shareclassCreationId = projectsByRecordType.get(shareclassCreationRtId).Id;
        TaxData__c taxData = [SELECT ShareClass__c FROM TaxData__c WHERE ProjectProduct__c = :shareclassCreationId];
        System.assertEquals(createdShareclasses[0].Id, taxData.ShareClass__c);

        System.assertEquals('PARTIAL SUCCESS', batchLog.Status__c, 'The skipped project makes the run a partial success');
    }

    // Errors are logged and the project is not launched: no project enriched, project without product (rollback)
    @isTest
    static void testControllerErrorPaths() {
        // Fund creation project (no Product__c, one share class): modification stops on its missing product, share class creation fails and rolls back
        List<ProjectProduct__c> projectWithoutProduct = [SELECT Id
                                                         FROM ProjectProduct__c
                                                         WHERE Product__c = NULL AND Id IN (SELECT ProjectProduct__c FROM ProjectShareclass__c)];
        List<String> debugInformation = new List<String>();
        List<String> errorMessages = new List<String>();
        Integer[] recordsFailed = new Integer[] { 0 };
        List<Id> launchedProjectIds = new List<Id>();

        Test.startTest();

        ProjectProductBatchController.createFundShareclass(new List<ProjectProduct__c>(), debugInformation, errorMessages, recordsFailed, new List<Id>(), launchedProjectIds);
        ProjectProductBatchController.createShareclasses(projectWithoutProduct, debugInformation, errorMessages, recordsFailed, new List<Id>(), launchedProjectIds);
        ProjectProductBatchController.updateFundShareclassModification(projectWithoutProduct, debugInformation, errorMessages, recordsFailed, new List<Id>(), launchedProjectIds);

        Test.stopTest();

        System.assertEquals(3, recordsFailed[0], 'Each call should count one failure');
        System.assert(errorMessages[0].contains('No ProjectProduct enriched'), errorMessages[0]);
        System.assert(String.join(debugInformation, '\n').contains('[ROLLBACK]'), 'The share class creation without product should be rolled back');
        System.assert(launchedProjectIds.isEmpty(), 'No project should be marked as launched');
    }

    // Same values as PMTTestFactoryData.createProjectProductWithAllFields, without the insert (projects are inserted in one DML)
    private static ProjectProduct__c buildProject(Id recordTypeId) {
        return new ProjectProduct__c(Name = 'Test Project', RecordTypeId = recordTypeId, VehicleType__c = 'Funds', ProjectStartDate__c = Date.today() - 20, EndDate__c = Date.today(), RiskAssociated__c = 'Equity;Interest rates;Credit;Currency', InvestmentObjective__c = 'Sample Objective', InvestmentStrategy__c = 'Sample Strategy', DomiciledIn__c = 'FR', ProjectStatus__c = 'Closed', ProductName__c = 'toto', SFDRCategory__c = '0', LegalForm__c = 'Other', LettreRequise__c = 'No');
    }

    // Same values as PMTTestFactoryData.createProjectShareclass, without the insert
    private static ProjectShareclass__c buildProjectShareclass(Id projectId, String fieldsToModify) {
        return new ProjectShareclass__c(ProjectProduct__c = projectId, TECH_FieldsToModify__c = fieldsToModify, Type__c = 'A', CurrencyIsoCode = 'EUR', DividendPolicy__c = 'Accumulating', CurrencyHedging__c = 'False');
    }
}