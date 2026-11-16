@IsTest
public with sharing class AccountPlanPDFControllerTest {

    /**
     * Verifies the PDF controller initialization, related data and getters.
     */
    @IsTest
    static void testAccountPlanPDFController() {
        Account testAcc = TestFactory.getSimpleAccount();
        insert testAcc;

        Account_Plan__c testAccPlan = new Account_Plan__c(
            Name = 'Test Account Plan',
            Executive_Summary__c = 'Line 1\nLine 2',
            Third_Party_Fund_Architecture__c = 'Architecture 1\nArchitecture 2',
            Company__c = testAcc.Id
        );
        insert testAccPlan;

        Account_Plan_Objective__c objective = new Account_Plan_Objective__c(
            Name = 'Test Objective',
            Account_Plan__c = testAccPlan.Id,
            Priority__c = 'High',
            Objective_Type__c = 'Financial'
        );
        insert objective;

        Test.setCurrentPage(new PageReference('/apex/AccountPlanPDF'));
        ApexPages.currentPage().getParameters().put('id', testAccPlan.Id);

        Test.startTest();

        AccountPlanPDFController controller = new AccountPlanPDFController();

        Test.stopTest();

        System.assertEquals(testAccPlan.Id, controller.getAccountPlan().Id);
        System.assertEquals(1, controller.getObjectives().size());
        System.assertEquals(0, controller.getPrevious_objectives().size());
        System.assertNotEquals(null, controller.getOpenOpportunities());
        System.assertNotEquals(null, controller.getMyDomainName());
        System.assertEquals(
            'Test Account Plan',
            AccountPlanPDFController.accPlanFileName(testAccPlan.Id)
        );
        System.assertEquals(
            'Line 1<br/>Line 2',
            controller.getAccountPlan().Executive_Summary__c
        );
    }


}