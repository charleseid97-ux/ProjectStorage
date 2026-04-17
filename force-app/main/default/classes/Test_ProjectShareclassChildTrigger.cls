@IsTest
public class Test_ProjectShareclassChildTrigger {

    private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c
        .getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();
    

    
    
    @IsTest(SeeAllData=true)
    static void test_ShareClassChildCreation() {
        System.debug('[DEBUG TEST Share Class Trigger]');

        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);
        List<ProjectProductChild__c> childs = [SELECT Id,ProjectProductParent__c FROM ProjectProductChild__c where ProjectProductParent__c=:proj.Id];
        system.debug(proj.ProjectStartDate__c);
        Test.startTest();
        ProjectShareclass__c shareClass = PMTTestFactoryData.createProjectShareclass(proj.Id, 'DividendFrequency__c;Type__c;DividendPolicy__c;InvestmentStatusInvestors__c');
        List<ProjectChildJunction__c> junctionsToInsert = new List<ProjectChildJunction__c>();
            for (ProjectProductChild__c sibling : childs) {
                        junctionsToInsert.add(new ProjectChildJunction__c(
                            ProjectProductChild__c = sibling.Id,
                            ProjectShareclass__c = shareClass.Id
                        ));
                
            }
        insert junctionsToInsert;
        List<ProjectShareclassChild__c> scchilds = [Select Id From ProjectShareclassChild__c where ProjectShareclasses__c = :shareClass.Id];
        
        List<ProjectChildJunction__c> junctions = [SELECT Id FROM ProjectChildJunction__c WHERE ProjectShareclass__c =:shareClass.Id ];
        
        Milestone__c milestone = [SELECT Id FROM Milestone__c WHERE Project_product__c = :proj.Id AND Name = 'SPC Final' LIMIT 1];
        milestone.Status__c='Completed';
        update milestone;
        shareClass.TECH_FieldsToModify__c = 'DividendFrequency__c';
        update shareClass;
        system.assertNotEquals(0, scchilds.size());
        Test.stopTest();
        
    }
    
}