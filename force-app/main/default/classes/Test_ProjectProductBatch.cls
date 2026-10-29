@isTest
private class Test_ProjectProductBatch {
 
    private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c
        .getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();
    private static final Id fundModificationRtId = Schema.SObjectType.ProjectProduct__c
        .getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();
    private static final Id shareclassCreationRtId = Schema.SObjectType.ProjectProduct__c
        .getRecordTypeInfosByDeveloperName().get('ShareclassCreation').getRecordTypeId();
    private static final Id fundRecordTypeId = Schema.SObjectType.Product__c
        .getRecordTypeInfosByName().get('Fund').getRecordTypeId();

    static final Id fundShareClassModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();
    static final Id fundCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();
    static final Id shareclassCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('ShareclassCreation').getRecordTypeId();

    @TestSetup
    static void setupData() {
        PMTTestFactoryData.createMatrice(
            'Proposal',
            'Risk',
            'InvestmentObjective__c;InvestmentStrategy__c',
            'CurrencyIsoCode;Type__c'
        );
    }

    @isTest
    static void test_batch_fundCreation2() {
        System.debug('[DEBUG TEST BATCH] test_batch_fundCreation');

        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);

        proj.EndDate__c = Date.today();
        update proj;
        PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode;Type__c');
        PMTTestFactoryData.createMilestone(proj.Id, 'Launch Date', proj.EndDate__c);
        FundManager__c manager = PMTTestFactoryData.createFundManager('Test Manager');
        PMTTestFactoryData.createFundManagerAssignment(proj.Id, manager.Id);

       Test.startTest();
        // Créer une instance du scheduler
        ProjectProductBatchScheduler scheduler = new ProjectProductBatchScheduler();
        // Planifier l’exécution (date fictive mais syntaxe obligatoire)
        String jobId = System.schedule('Test Job','0 0 12 * * ?', scheduler);
        Test.stopTest();

        List<Product__c> product2 = [SELECT Id FROM Product__c LIMIT 1];
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        Id narrativeRtId = Schema.SObjectType.Narrative__c.getRecordTypeInfosByDeveloperName().get('Narrative').getRecordTypeId();

        List<Narrative__c> narratives = ProjectProductBatchUtilities.createNarratives(
            proj,
            narrativeRtId,
            'EN',
            product.Id,
            'Product'
        );

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
        //Share_Class__c modifiedShareclass = [SELECT ESMAApplicationStartDate__c FROM Share_Class__c WHERE Name = 'SC To Modify'];
        //System.assertEquals(Date.today(), modifiedShareclass.ESMAApplicationStartDate__c);

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
        List<String> debugInformation = new List<String>();
        List<Id> createdRecords = new List<Id>();
        Integer[] recordsFailedWrapper = new Integer[] { 0 };

        ProjectProductBatchController.createFundShareclass(new List<ProjectProduct__c>{proj}, debugInformation, errorMessages, recordsFailedWrapper, createdRecords, new List<Id>());
    }

    @isTest
    static void test_batch_fundCreation() {
        System.debug('[DEBUG TEST BATCH] test_batch_fundCreation');

        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);
        proj.EndDate__c = Date.today();
        update proj;
        PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode;Type__c');
        Milestone__c currentMilestone = PMTTestFactoryData.createMilestone(proj.Id, 'Launch Date', proj.EndDate__c);
        currentMilestone.Status__c = 'Completed';
        update currentMilestone;
        FundManager__c manager = PMTTestFactoryData.createFundManager('Test Manager');
        PMTTestFactoryData.createFundManagerAssignment(proj.Id, manager.Id);

        Test.startTest();
        ProjectProductBatch testBatch = new ProjectProductBatch();
        Database.executeBatch(testBatch);
        Test.stopTest();

        List<Product__c> product2 = [SELECT Id FROM Product__c LIMIT 1];
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        Id narrativeRtId = Schema.SObjectType.Narrative__c.getRecordTypeInfosByDeveloperName().get('Narrative').getRecordTypeId();
 
        List<Narrative__c> narratives = ProjectProductBatchUtilities.createNarratives(
            proj,
            narrativeRtId,
            'EN',
            product.Id,
            'Product'
        );

        List<String> errorMessages = new List<String>();
        List<String> debugInformation = new List<String>();
        List<Id> createdRecords = new List<Id>();
        Integer[] recordsFailedWrapper = new Integer[] { 0 };
        
        ProjectProductBatchController.createFundShareclass(new List<ProjectProduct__c>{proj}, debugInformation, errorMessages, recordsFailedWrapper,createdRecords, new List<Id>());
    }
 
    @isTest
    static void test_batch_fundShareClassModification() {
        System.debug('[DEBUG TEST BATCH] test_batch_fundShareClassModification');
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundModificationRtId);
        proj.EndDate__c = Date.today();
        proj.Product__c = product.Id;
        proj.InvestmentObjective__c = 'Test Content';
        proj.RiskAssociated__c = 'Equity;Interest rate;Credit;Currency';
        proj.IntentedRetailInvestor__c = 'Test Retail';
        proj.ReasonForRHP__c = 'Test Reason';
        proj.TECH_FieldsToModify__c = 'InvestmentObjective__c;RiskAssociated__c;IntentedRetailInvestor__c;ReasonForRHP__c';
        
        update proj;
 
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'Name');
        Share_Class__c sc = new Share_Class__c(Name = 'SC To Modify', Fund__c = product.Id, Validity__c = true);
        insert sc;
        shc.TECH_ShareClass__c = sc.Id;
        shc.ShareclassInvestmentObjective__c = 'Test';
        shc.PerformanceFeeUCITSKIID__c = 'Test';
        shc.PerformanceFeeEPTKID__c = 'Test';
        shc.TECH_FieldsToModify__c = 'ShareclassInvestmentObjective__c;PerformanceFeeUCITSKIID__c;PerformanceFeeEPTKID__c';
        upsert shc;

        Milestone__c currentMilestone = PMTTestFactoryData.createMilestone(proj.Id, 'Launch Date', proj.EndDate__c);
        currentMilestone.Status__c = 'Completed';
        update currentMilestone;

        Test.startTest();
            // Créer une instance du scheduler
            ProjectProductBatchScheduler scheduler = new ProjectProductBatchScheduler();
            // Planifier l’exécution (date fictive mais syntaxe obligatoire)
            String jobId = System.schedule('Test Job','0 0 12 * * ?',scheduler);
        Test.stopTest();
        }
 
    @isTest
    static void test_batch_shareclassCreation() {
        System.debug('[DEBUG TEST BATCH] test_batch_shareclassCreation');
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'ShareClsProd', 'Fund For Shareclass', true);
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(shareclassCreationRtId);
                Milestone__c currentMilestone = PMTTestFactoryData.createMilestone(proj.Id, 'Launch Date', proj.EndDate__c);
        currentMilestone.Status__c = 'Completed';
        update currentMilestone;
        
        proj.EndDate__c = Date.today();
        proj.Product__c = product.Id;
        update proj;
 
        ProjectShareclass__c projectSc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode;Type__c');
        
        TaxData__c taxData = new TaxData__c(
            ProjectProduct__c = proj.Id,
            ProjectShareclass__c = projectSc.Id,
            Country__c = 'AT',
            Type__c = 'Transparency',
            Status__c = 'Requested',
            Source__c = 'PMT'
        );
        insert taxData;

        Test.startTest();
        // Créer une instance du scheduler
        ProjectProductBatchScheduler scheduler = new ProjectProductBatchScheduler();
        // Planifier l’exécution (date fictive mais syntaxe obligatoire)
        String jobId = System.schedule('Test Job','0 0 12 * * ?',scheduler);
        Test.stopTest();
    }

    @isTest
    static void test_batch_shareclassCreation_throwsException() {
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(shareclassCreationRtId);
        proj.EndDate__c = Date.today();
        proj.Product__c = null; // pas de produit associé = erreur
        update proj;

        Test.startTest();
            Database.executeBatch(new ProjectProductBatch());
        Test.stopTest();

        List<PMTBatchLog__c> logs = [SELECT Status__c, ErrorMessages__c FROM PMTBatchLog__c ORDER BY CreatedDate DESC LIMIT 1];
        System.assertEquals('ERROR', logs[0].Status__c);
        System.debug('logs[0].ErrorMessages__c:' + logs[0].ErrorMessages__c);
        System.assert(logs[0].ErrorMessages__c.containsIgnoreCase('[ERROR]'));
    }

    @isTest
    static void test_batch_fundShareclassModification_throwsException() {
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundModificationRtId);
        proj.EndDate__c = Date.today();
        proj.Product__c = null; // volontairement vide pour forcer une NullPointerException
        update proj;

        Test.startTest();
            Database.executeBatch(new ProjectProductBatch());
        Test.stopTest();

        List<PMTBatchLog__c> logs = [SELECT Status__c, ErrorMessages__c FROM PMTBatchLog__c ORDER BY CreatedDate DESC LIMIT 1];
        System.assertEquals('ERROR', logs[0].Status__c);
         System.debug('logs[0].ErrorMessages__c:' + logs[0].ErrorMessages__c);
        System.assert(logs[0].ErrorMessages__c.containsIgnoreCase('[ERROR]'));
    }

    @isTest
    static void test_batch_fundCreation_throwsException() {
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);
        proj.EndDate__c = Date.today();
        update proj;

        // Ne pas créer de shareclass ni de milestone, ce qui causera une erreur de dépendance
        Test.startTest();
            Database.executeBatch(new ProjectProductBatch());
        Test.stopTest();

        List<PMTBatchLog__c> logs = [SELECT Status__c, ErrorMessages__c FROM PMTBatchLog__c ORDER BY CreatedDate DESC LIMIT 1];
        System.assertEquals('ERROR', logs[0].Status__c);
       // System.assert(logs[0].ErrorMessages__c.containsIgnoreCase('FundCreation'));
    }

}