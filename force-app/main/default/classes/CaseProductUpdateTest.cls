@isTest
public class CaseProductUpdateTest {
    
	static testMethod void doTest() {
        PAD.byPassUserTriggerHandler = true;
        PAD.byPassContactTriggerHandler = true;
		
        test.startTest();
        
        User usr = TestFactory.getStandardCarmignacUser();
      	
        system.runAs(usr) {
            
            Case newCase = TestFactory.getSimpleCase();
            insert newCase;
            
            Id FundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
            List<Product__c> pList = new List<Product__c>{
                new Product__c(Name='PFund', Product_Name__c='Product Fund', Record_Type_Name__c = 'Fund', RecordTypeId=FundRecordTypeId)
            };
                        
            insert pList;
            
            Share_Class__c sc = new Share_Class__c(Name='ShareClass', Fund_Code__c='PFund',ISIN_Code__c='1234abcd', Fund__c=pList[0].Id, Validity__c = true);
            insert sc;
            
            CarmignacProduct__c  cp = new CarmignacProduct__c (Name='ShareClass',ISIN__c ='1234abcd');
            insert cp;
            
            Case_Product__c newCP = new Case_Product__c(Work_Together_Process__c = newCase.Id, Share_Class__c = sc.Id);
            insert newCP;
            
        }
        
        test.stopTest();
    }
}