/*************************************************************************************************************************
Class Name      :   DigitalInteractionTest
Class Desc.     :   Class used for Digital Interaction  
Author          :   Alpha FMC
Description     :   Test class for DigitalInteractionTriggers. 

History
-------
//1.0 - Initial build of class on 07/04/2020
***************************************************************************************************************************/

@isTest
public with sharing class DigitalInteractionTest {
    
	public static void insertData() {
        Product__c p0 = new Product__c(Name='Equity', Product_Name__c='Equity', Record_Type_Name__c = 'Asset Class', Asset_Class_Code__c = 'EQTY');
        insert p0;
        Contact testContact = CommonTestData.AccContact;
        testContact.Bypass_Apex__c = true;
        update testContact;
        
        Digital_Interaction__c di0 = new Digital_Interaction__c(Contact__c = testContact.Id, MDS_ID__c = '1', URL__c='www.test.com/funds/Equity/somepath');
        insert di0;
    }
    
    @isTest static void testDI(){
        PAD.byPassUserTriggerHandler = true;
        CommonTestData.getData();
        insertData();
        Test.startTest();

        Test.stopTest();
    }
    

}