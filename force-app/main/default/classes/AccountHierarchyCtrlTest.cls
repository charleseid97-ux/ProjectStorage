/*************************************************************************************************************************
Class Name      :   AccountHierarchyCtrlTest
Class Desc.     :   Class used for Account Hierarchy Viewer widget  
Author          :   Alpha FMC
Description     :   Test class for AccountHierarchyCtrl. Testing that return structure is as expected. 

History
-------
//1.0 - Initial build of class on 9/29/2016
***************************************************************************************************************************/

@isTest
private class AccountHierarchyCtrlTest 
{

  static testmethod void doTest()
  {

    /** Testing Account, children and external organization relationships **/
    Map<String, Id> accRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Account.SObjectType);

    Account accA = new Account(Name='Ultimate Parent Test', BusinessDevelopmentRegion__c = 'BP_FR', RecordTypeId = accRtMap.get('Account_GlobalAccount'));
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
      
    Account accB = new Account(Name = 'Consultant Test', BusinessDevelopmentRegion__c = 'BP_FR'
                      	,Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Prospect') 
        			,Billingcity='New York',BillingStreet='abc123',BillingPostalCode='10402'
        			,BillingCountry='United States',Billingstate='New York');
      insert accB;

    Account accNeg = new Account(Name = 'Negative Test', BusinessDevelopmentRegion__c = 'BP_FR'
                      	,Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_ThirdParty') 
        				,Billingcity='Los Angeles',BillingStreet='las123',BillingPostalCode='35062'
        				,BillingCountry='United States',Billingstate='California');
      insert accNeg;


    /** Testing External Organization Relationships **/
    RelatedCompany__c orgRel = new RelatedCompany__c (Company__c = accList[1].Id,
    								ThirdParty__c = accB.Id,
    								Role__c = 'External FSU');
    insert orgRel;


    /** Testing Opportunity **/
    Map<String, Id> oppRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Opportunity.SObjectType);

    Opportunity opp = new Opportunity(AccountId = accList[2].Id, // RecordTypeId = oppRtMap.get('Institutional_Opportunity'), 
        StageName = '1. Internally Identified', Name = 'Test Opportunity', CloseDate = System.today());
      insert opp;
  
    /** Start Test
    * Testing that all properties of account hierarchy exist in structure
     **/
    Test.startTest();
    
    AccountHierarchyCtrl ahs = new AccountHierarchyCtrl();
    
    ahs.setcurrentId('' + accList[0].Id);

    List<Account> accListTest = [SELECT Id, Name FROM Account WHERE ParentId = :accA.Id];
    //Testing by passing one of the account Ids
    String testStructure = AccountHierarchyCtrl.getStructureAsJSON(accListTest[0].Id);
    System.assertEquals(3, accListTest.size(), 'Account with that ParentId does not exist');

    System.assertEquals(true, testStructure.contains(accA.Id), 'Account Hierarchy is incomplete');
    System.assertEquals(true, testStructure.contains(accList[0].Id), 'Child A Test is not in hierarchy');    
    System.assertEquals(true, testStructure.contains(accList[1].Id), 'Child B Test is not in hierarchy');
    System.assertEquals(true, testStructure.contains(accList[2].Id), 'Child C Test is not in hierarchy');    
    System.assertEquals(true, testStructure.contains(opp.Id), 'Opportunity is not in hierarchy');    

    System.assertEquals(false, testStructure.contains(accNeg.Id), 'Negative Test is in hierarchy but should not be');
    
    Test.stopTest();
  }

}