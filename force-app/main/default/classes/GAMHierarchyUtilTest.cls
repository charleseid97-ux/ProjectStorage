@isTest
public class GAMHierarchyUtilTest {

    static testmethod void doTestGAM() {
    
        
        Map<String, Id> accRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Account.SObjectType);
    
        Account accA = new Account(Name='GAM Test', BusinessDevelopmentRegion__c = 'BP_FR', RecordTypeId = accRtMap.get('Account_GlobalAccount'));
          insert accA;
    
        List<Account> accList = new List<Account>{
          new Account(Name = 'Child A Test', ParentId = accA.Id, GAM__c = accA.Id, BusinessDevelopmentRegion__c = 'BP_FR'
                      	,Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor') 
                        ,Billingcity='Chicago',BillingStreet='asd123',BillingPostalCode='60606'
                        ,BillingCountry='United States',Billingstate='Illinois')
          , new Account(Name = 'Child B Test', ParentId = accA.Id, GAM__c = accA.Id, BusinessDevelopmentRegion__c = 'BP_FR'
                      	,Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor') 
                        ,Billingcity='Boston',BillingStreet='xyz123',BillingPostalCode='70301'
                        ,BillingCountry='United States',Billingstate='Massachusetts')
          , new Account(Name = 'Child C Test', ParentId = accA.Id, GAM__c = accA.Id, BusinessDevelopmentRegion__c = 'BP_FR'
                      	,Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor') 
                        ,Billingcity='Seattle',BillingStreet='sea123',BillingPostalCode='55002'
                        ,BillingCountry='United States',Billingstate='Washington')
        };
        insert accList;
        
        Test.startTest();
    
        Account GAMAccount = GAMHierarchyUtil.returnGAMAccount('' + accA.Id);
		System.assertEquals(GAMAccount.Name, accA.Name, 'Not the same GAM account');
        
        Map<String, Id> groups = GAMHierarchyUtil.buildGroups('' + accA.Id);
        System.assertEquals(true, groups.size() > 0, 'No Grouping Accounts created');

        GAMHierarchyUtil.buildHierarchy('' + accA.Id, groups);

        GAMHierarchyUtil.deleteGroups(groups);

        GAMHierarchyUtil.overrideDeleteGroups('' + accA.Id);
        
        Test.stopTest();
    }
    
    static testmethod void doTestKAM() {
    
        
        Map<String, Id> accRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Account.SObjectType);
    
        Account accA = new Account(Name='KAM Test', BusinessDevelopmentRegion__c = 'BP_FR',BillingCountry='France', RecordTypeId = accRtMap.get('Account_Distributor'));
          insert accA;
    
        List<Account> accList = new List<Account>{
          new Account(Name = 'Child A Test', ParentId = accA.Id, BusinessDevelopmentRegion__c = 'BP_FR'
                      	,Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor') 
                        ,Billingcity='Chicago',BillingStreet='asd123',BillingPostalCode='60606'
                        ,BillingCountry='United States',Billingstate='Illinois')
          , new Account(Name = 'Child B Test', ParentId = accA.Id, BusinessDevelopmentRegion__c = 'BP_FR'
                      	,Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor') 
                        ,Billingcity='Boston',BillingStreet='xyz123',BillingPostalCode='70301'
                        ,BillingCountry='United States',Billingstate='Massachusetts')
          , new Account(Name = 'Child C Test', ParentId = accA.Id, BusinessDevelopmentRegion__c = 'BP_FR'
                      	,Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor') 
                        ,Billingcity='Seattle',BillingStreet='sea123',BillingPostalCode='55002'
                        ,BillingCountry='United States',Billingstate='Washington')
        };
        insert accList;
        
        Test.startTest();
    
        Account GAMAccount = GAMHierarchyUtil.returnGAMAccount('' + accA.Id);
		System.assertEquals(GAMAccount.Name, accA.Name, 'Not the same GAM account');
        
        Map<String, Id> groups = GAMHierarchyUtil.buildGroups('' + accA.Id);
        System.assertEquals(true, groups.size() > 0, 'No Grouping Accounts created');

        GAMHierarchyUtil.buildHierarchy('' + accA.Id, groups);

        GAMHierarchyUtil.deleteGroups(groups);

        GAMHierarchyUtil.overrideDeleteGroups('' + accA.Id);
        
        Test.stopTest();
    }
}