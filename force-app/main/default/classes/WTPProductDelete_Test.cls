@IsTest
public class WTPProductDelete_Test
{
    @IsTest
    static void testBehavior()
    {

        // Test User creation
        User u = TestFactory.getCarmignacUserTestApex();

        System.runAs(u)
        {
            // Test Begin
            TestFactory.createCustomSettings();
            //Data preparation.

            Account testAcc = TestFactory.getSimpleAccount();
            testAcc.Client_Tier__c = 'Titanium (Tier 0)';
            testAcc.BusinessDevelopmentRegion__c = 'BP_FR';
            testAcc.Distributor_Type__c = 'Bank';
            testAcc.Sub_Type__c = 'Retail Banking';
            testAcc.BillingCity='Chicago';
            testAcc.BillingStreet='asd123';
            testAcc.BillingPostalCode='60606';
            testAcc.BillingCountry='United States';
            testAcc.In__c = 'Retail';
            testAcc.Final_Distribution__c = 'Retail';
            insert testAcc;

            Case caseToCreate = new Case(AccountId = testAcc.Id,  Type = 'Follow-up', Status = 'New', Origin = 'Email', Report_frequency__c = 'Weekly',
                    Due_date__c= Date.newInstance(2021, 04, 30));

            insert caseToCreate;


            Product__c product = new Product__c(Name = '123452', Product_Name__c = 'TestProduct');
            insert product;

            List<Id> shareClassList = new List<Id>();

            Share_Class__c shareClass = new Share_Class__c(
                    Name = 'TestShareclass1',
                    Validity__c = true,
                    Fund__c = product.Id
            );
            insert shareClass;

            Share_Class__c shareClass2 = new Share_Class__c(
                    Name = 'TestShareclass2',
                    Validity__c = true,
                    Fund__c = product.Id
            );
            insert shareClass2;

            Case_Product__c CaseProduct = new Case_Product__c(
                    Share_Class__c = shareClass.Id,
                    Work_Together_Process__c = caseToCreate.Id
            );
            insert CaseProduct;

            Case_Product__c CaseProduct2 = new Case_Product__c(
                    Share_Class__c = shareClass2.Id,
                    Work_Together_Process__c = caseToCreate.Id
            );
            insert CaseProduct2;
            
            System.Test.startTest();
            
            shareClass.Validity__c = false;
            update shareClass;


            shareClassList.add(shareClass.Id);

            WTPProductDelete.WTPProductDeletion(shareClassList);

            WTPProductNotify.WTPProductNotify(shareClassList);

            Case_Product__c deletedCaseProduct = [SELECT Id, IsDeleted FROM Case_Product__c WHERE Id = :CaseProduct.Id ALL ROWS];
            System.assertEquals(deletedCaseProduct.IsDeleted, true);

            System.Test.stopTest();
        }
    }
}