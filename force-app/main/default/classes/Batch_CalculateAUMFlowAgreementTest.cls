/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 11-07-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
@isTest
private class Batch_CalculateAUMFlowAgreementTest {
    private static final Id recTypeId = Schema.SObjectType.Convention__c.getRecordTypeInfosByName().get('Sub-distributor via Platforms').getRecordTypeId();
    private static final Id masterRecTypeId = Schema.SObjectType.Convention__c.getRecordTypeInfosByName().get('Intermediary Agreement').getRecordTypeId();
    
    @TestSetup
    static void setupTestData() {
        Account testAcc = TestFactory.getSimpleAccount();
        testAcc.Client_Tier__c = 'Titanium (Tier 0)';
        testAcc.BusinessDevelopmentRegion__c = 'BP_FR';
        testAcc.Distributor_Type__c = 'Bank';
        testAcc.Sub_Type__c = 'Retail Banking';
        testAcc.Billingcity='Paris';
        testAcc.BillingStreet='12 rue test';
        testAcc.BillingPostalCode='75001';
        testAcc.BillingCountry='France';
        testAcc.In__c = 'Retail';
        testAcc.Final_Distribution__c = 'Retail';
        insert testAcc;
        
        Grid__c grid = new Grid__c(Name='France grid', ActiveGrid__c=true);
        insert grid;
        
        Convention__c master = new Convention__c( RecordTypeId=masterRecTypeId, Grid__c = grid.Id, Company__c=testAcc.Id, Name='L198', Agreement_Type__c='Master', Code_Type__c = 'Platform Master Agreement', Countries_of_Distribution__c='FR');
        insert master;
        
        Convention__c convention = new Convention__c(
            MasterConvention__c=master.Id, 
            RecordTypeId=recTypeId, 
            Grid__c = grid.Id, 
            Company__c=testAcc.Id, 
            Name='L198_IT131', 
            Agreement_Type__c='Standard', 
            Code_Type__c = 'Sub-distributor via Platforms', 
            Countries_of_Distribution__c='FR'
        );
        insert convention;
        
        AUM__c aum = new AUM__c(
            Company__c=testAcc.Id, 
            AUMExternalId__c='5678'+convention.Name, 
            Convention__c = convention.Id, 
            AmountEUR__c = 1000, 
            Last_AUM__c = true
        );
        insert aum;
        
        Flow__c flow = new Flow__c(
            Company__c=testAcc.Id, 
            FlowExternalId__c='1234'+convention.Name, 
            Agreement__c = convention.Id, 
            AmountEUR__c = 500, 
            ValueDate__c = Date.today()
        );
        insert flow;
    }
    
    @isTest
    static void testBatchExecution() {
        Test.startTest();
        Batch_CalculateAUMFlowAgreement batchJob = new Batch_CalculateAUMFlowAgreement();
        Database.executeBatch(batchJob);
        Test.stopTest();
        
        Convention__c updatedConvention = [SELECT Id, AUM_To_Date__c, YTDNetFlows__c FROM Convention__c WHERE  Agreement_Type__c='Standard'];
        
        System.assertEquals(1000, updatedConvention.AUM_To_Date__c, 'AUM incorrect pour la convention L198_IT131');
        System.assertEquals(500, updatedConvention.YTDNetFlows__c, 'Flow incorrect pour la convention L198_IT131');
    }
    
    @isTest
    static void testBatchWithNoData() {
        delete [SELECT Id FROM Convention__c];
        delete [SELECT Id FROM AUM__c];
        delete [SELECT Id FROM Flow__c];
        
        Test.startTest();
        Batch_CalculateAUMFlowAgreement batchJob = new Batch_CalculateAUMFlowAgreement();
        Database.executeBatch(batchJob);
        Test.stopTest();
        
        List<Convention__c> updatedConventions = [SELECT Id FROM Convention__c];
        System.assertEquals(0, updatedConventions.size(), 'Il ne devrait pas y avoir de conventions');
    }
    
    @isTest
    static void testScheduler() {
        Test.startTest();
        
        String jobName = 'Test AUM Flow Agreement Calculation';
        String cronExp = '0 0 0 * * ?';
        Batch_CalculateAUMFlowAgreementScheduler scheduler = new Batch_CalculateAUMFlowAgreementScheduler();
        String jobId = System.schedule(jobName, cronExp, scheduler);
        
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime 
                          FROM CronTrigger 
                          WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression);
        System.assertEquals(0, ct.TimesTriggered);
        System.assertNotEquals(null, ct.NextFireTime);
        
        Test.stopTest();
        
       
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors 
                            FROM AsyncApexJob 
                            WHERE JobType = 'BatchApex' 
                            ORDER BY CreatedDate DESC 
                            LIMIT 1];
        System.assertEquals(0, job.NumberOfErrors);
    }
}