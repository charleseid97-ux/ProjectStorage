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
            product.Id
        );

        List<String> errorMessages = new List<String>();
        List<String> debugInformation = new List<String>();
        List<Id> createdRecords = new List<Id>();
        Integer[] recordsFailedWrapper = new Integer[] { 0 };

        ProjectProductBatchController.createFundShareclass(new List<ProjectProduct__c>{proj}, debugInformation, errorMessages, recordsFailedWrapper, createdRecords);
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
            product.Id
        );

        List<String> errorMessages = new List<String>();
        List<String> debugInformation = new List<String>();
        List<Id> createdRecords = new List<Id>();
        Integer[] recordsFailedWrapper = new Integer[] { 0 };
        
        ProjectProductBatchController.createFundShareclass(new List<ProjectProduct__c>{proj}, debugInformation, errorMessages, recordsFailedWrapper,createdRecords);
    }
 
    @isTest
    static void test_batch_fundShareClassModification() {
        System.debug('[DEBUG TEST BATCH] test_batch_fundShareClassModification');
        Product__c product = PMTTestFactoryData.getProduct(fundRecordTypeId, 'FundModCode', 'Fund To Modify', true);
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundModificationRtId);
        proj.EndDate__c = Date.today();
        proj.Product__c = product.Id;
        proj.TECH_FieldsToModify__c = 'Name';
        update proj;
 
        ProjectShareclass__c shc = PMTTestFactoryData.createProjectShareclass(proj.Id, 'Name');
        shc.TECH_ShareClass__c = new Share_Class__c(Name = 'SC To Modify', Fund__c = product.Id, Validity__c = true).Id;
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
 
        PMTTestFactoryData.createProjectShareclass(proj.Id, 'CurrencyIsoCode;Type__c');

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