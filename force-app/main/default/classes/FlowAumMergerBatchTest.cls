/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 11-29-2024
 * @last modified by  : SILA Nicolas
**/

@IsTest
private class FlowAumMergerBatchTest {

    @TestSetup
    static void setupTestData() {
        // Création des Platforms (Accounts)
        Account platform1 = TestFactory.getSimpleAccount();
        platform1.Name = 'Platform1';
         platform1.BusinessDevelopmentRegion__c = 'BP_FR';
         platform1.distributor_Type__c = 'Bank';
         platform1.Sub_Type__c = 'Retail Banking';
         platform1.Billingcity='Chicago';
         platform1.BillingStreet='asd123';
         platform1.BillingPostalCode='60606';
         platform1.BillingCountry='United States';
         platform1.Billingstate='Illinois';
        insert platform1;

        Account platform2 = TestFactory.getSimpleAccount();
        platform2.Name = 'Platform2';
        
         platform2.BusinessDevelopmentRegion__c = 'BP_FR';
         platform2.distributor_Type__c = 'Bank';
         platform2.Sub_Type__c = 'Retail Banking';
         platform2.Billingcity='Chicago';
         platform2.BillingStreet='asd123';
         platform2.BillingPostalCode='60606';
         platform2.BillingCountry='United States';
         platform2.Billingstate='Illinois';
        insert platform2;

        // Création des Companies (Accounts)
        Account company1 = TestFactory.getSimpleAccount();
        company1.Name = 'Company1';
        
         company1.BusinessDevelopmentRegion__c = 'BP_FR';
         company1.distributor_Type__c = 'Bank';
         company1.Sub_Type__c = 'Retail Banking';
         company1.Billingcity='Chicago';
         company1.BillingStreet='asd123';
         company1.BillingPostalCode='60606';
         company1.BillingCountry='United States';
         company1.Billingstate='Illinois';
        insert company1;

        Account company2 = TestFactory.getSimpleAccount();
        company2.Name = 'Company2';
        
         company2.BusinessDevelopmentRegion__c = 'BP_FR';
         company2.distributor_Type__c = 'Bank';
         company2.Sub_Type__c = 'Retail Banking';
         company2.Billingcity='Chicago';
         company2.BillingStreet='asd123';
         company2.BillingPostalCode='60606';
         company2.BillingCountry='United States';
         company2.Billingstate='Illinois';
        insert company2;
		
        Grid__c franceGrid = new Grid__c(Name = 'France S5');
        insert franceGrid;
        // Création des Agreements (Conventions__c)
        Convention__c agreement1 = TestFactory.getAgreement(company1.Id,franceGrid.Id);
        agreement1.Name = 'Agreement1';
        agreement1.Platform__c = platform1.Id; // Lien au Platform
        insert agreement1;

        Convention__c agreement2 = TestFactory.getAgreement(company2.Id,franceGrid.Id);
        agreement2.Name = 'Agreement2';
        agreement2.Platform__c = platform2.Id; // Lien au Platform
        insert agreement2;

        // Création des Flows avec ValueDate__c
        List<Flow__c> flows = new List<Flow__c>{
            new Flow__c(Company__c = company1.Id,FlowExternalId__c='qsdqsdsqddqs', Agreement__c = agreement1.Id, AmountEUR__c = 100, ValueDate__c = Date.today()),
            new Flow__c(Company__c = company2.Id,FlowExternalId__c='qsdqsdsqdqsdsqddqs', Agreement__c = agreement2.Id, AmountEUR__c = -50, ValueDate__c = Date.today())
        };
        insert flows;

        // Création des AUM
        List<AUM__c> aums = new List<AUM__c>{
            new AUM__c(Company__c = company1.Id,AUMExternalId__c='qsdqsdsqsdqddqs', Convention__c = agreement1.Id, AmountEUR__c = 500, Last_AUM__c = true),
            new AUM__c(Company__c = company2.Id,AUMExternalId__c='qsdqsdsqdsfdsfddqs', Convention__c = agreement2.Id, AmountEUR__c = 200, Last_AUM__c = true)
        };
        insert aums;
    }

    @IsTest
    static void testFlowAumMergerBatch() {
        Test.startTest();
        FlowAumMergerBatch batch = new FlowAumMergerBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Vérifier les résultats
        List<Platform_Flow_AUM__c> results = [SELECT Platform__r.Name, Agreement__c, Company__c, YTDFlowTot__c, LastAUMTot__c
                                               FROM Platform_Flow_AUM__c];

        System.assert(!results.isEmpty(), 'Aucun résultat trouvé.');
        System.assertEquals(2, results.size(), 'Nombre incorrect de résultats.');

        for (Platform_Flow_AUM__c result : results) {
            if (result.Platform__r.Name == 'Platform1') {
                System.assertEquals(150.00, result.YTDFlowTot__c, 'Somme incorrecte pour Platform1.');
                System.assertEquals(700.00, result.LastAUMTot__c, 'AUM incorrect pour Platform1.');
            }
        }
    }
}