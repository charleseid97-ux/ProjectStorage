/**
 * Created by noorgoolamnabee on 05/07/2022.
 */

@IsTest
private class NDA_CtrlTest {

    @testSetup
    static void testSetup() {

        User usr = TestFactory.getStandardCarmignacUser();

        system.runAs(usr) {

            NDA__c nda =  TestFactory.getNDA();
            nda.Name = 'Morning star NDA';
            insert nda;

            Case newCase = TestFactory.getSimpleCase();
            newCase.NDA__c = nda.Id;
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

            NDA_Product__c np = new NDA_Product__c(NDA__c = nda.Id, Share_Class__c = sc.Id);
            insert np;

            Case_Product__c newCP = new Case_Product__c(Work_Together_Process__c = newCase.Id, Share_Class__c = sc.Id);
            insert newCP;



        }

    }

    @IsTest
    static void testBehavior() {

        User u = [SELECT Id FROM User WHERE LastName = 'Tecg'];

        system.runAs(u) {

            NDA__c nda = [SELECT Id FROM NDA__c];

            nda.Stage__c = 'In progress';

            update nda;
        }

    }

    @IsTest
    static void testBehaviorPlatform() {

        User u = [SELECT Id FROM User WHERE LastName = 'Tecg'];

        system.runAs(u) {

            NDA__c parentNDA = [SELECT Id FROM NDA__c where Name LIKE '%Morning%' LIMIT 1];

            NDA__c nda = TestFactory.getNDA('NDA_via_Platform');
            //nda.Related_NDA__c = parentNDA.Id;
            insert nda;

            Case newCase = TestFactory.getSimpleCase();
            newCase.NDA__c = nda.Id;
            insert newCase;

            CarmignacProduct__c  cp = new CarmignacProduct__c (Name='ShareClass',ISIN__c ='239988556');
            insert cp;

            Share_Class__c sc = [SELECT Id FROM Share_Class__c LIMIT 1];

            Id FundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
            List<Product__c> pList = new List<Product__c>{
                    new Product__c(Name='PFund2', Product_Name__c='Product Fund2', Record_Type_Name__c = 'Fund', RecordTypeId=FundRecordTypeId)
            };

            insert pList;

            Share_Class__c sc2 = new Share_Class__c(Name='ShareClass2', Fund_Code__c='PFund',ISIN_Code__c='I1234569', Fund__c=pList[0].Id, Validity__c = true);
            insert sc2;

            NDA_Product__c np = new NDA_Product__c(NDA__c = parentNDA.Id, Share_Class__c = sc2.Id);
            insert np;

            Case_Product__c newCP = new Case_Product__c(Work_Together_Process__c = newCase.Id, Share_Class__c = sc.Id);
            insert newCP;

            try{
                nda.Stage__c = 'In progress';
                update nda;
            }catch (Exception e){
                System.debug('//testBehaviorPlatform'+e.getMessage());
            }
        }
    }
}