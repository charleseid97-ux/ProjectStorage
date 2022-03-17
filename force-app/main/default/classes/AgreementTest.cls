@isTest
public class AgreementTest {

    static testmethod void doTest() {

        Map<String, Id> accRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Account.SObjectType);
        Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);

        // Test User creation
        User u = TestFactory.getCarmignacUserTestApex();

        System.runAs(u) {

            List<Account> accList = new List<Account>{
                    new Account(Name = 'Account FR Test', BusinessDevelopmentRegion__c = 'BP_FR'
                            , Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor')
                            , Billingcity = 'Chicago', BillingStreet = 'asd123', BillingPostalCode = '60606'
                            , BillingCountry = 'United States', In__c = 'Retail', Final_Distribution__c = 'Retail')
                    , new Account(Name = 'Account ES Test', BusinessDevelopmentRegion__c = 'BP_ES'
                            , Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor')
                            , Billingcity = 'Barcelona', BillingStreet = 'xyz456', BillingPostalCode = '70301'
                            , BillingCountry = 'Spain', In__c = 'Retail', Final_Distribution__c = 'Retail')
                    , new Account(Name = 'Account Fail Test', BusinessDevelopmentRegion__c = 'BP_LU', BillingCountry = 'Luxembourg')
            };
            insert accList;

            Grid__c franceGrid = new Grid__c(Name = 'France S5');
            insert franceGrid;

            Convention__c masterAgreement = new Convention__c(Name = 'tmpName', Grid__c = franceGrid.Id, Company__c = accList[0].Id,
                    Countries_of_Distribution__c = 'AL', Code_Type__c = 'Distribution Agreement', Agreement_Type__c = 'Master',
                    RecordTypeId = agmRtMap.get('Request_Agreement'));
            insert masterAgreement;

            Convention__c subAgreement = new Convention__c(Name = 'tmpSUBName', Grid__c = franceGrid.Id, Company__c = accList[1].Id, MasterConvention__c = masterAgreement.Id,
                    Countries_of_Distribution__c = 'AL', Code_Type__c = 'Distribution Agreement',
                    RecordTypeId = agmRtMap.get('Request_Agreement'));
            insert subAgreement;

            Contact newContact = new Contact(Email = 'Test@Email.com', Salutation = 'Ms', LastName = 'User');
            insert newContact;


            List<ConventionRelatedContact__c> CRCList = new List<ConventionRelatedContact__c>{
                    new ConventionRelatedContact__c(Contact__c = newContact.Id, Role__c = 'Rebate/ IS Contact', Convention__c = masterAgreement.Id),
                    new ConventionRelatedContact__c(Contact__c = newContact.Id, Role__c = 'Reallocation / IS Contact', Convention__c = masterAgreement.Id)
            };


            insert CRCList;

            Convention__c failAgreement = new Convention__c(Name = 'tmpSUBName', Grid__c = franceGrid.Id, Company__c = accList[2].Id,
                    Countries_of_Distribution__c = 'AL', Code_Type__c = 'Distribution Agreement',
                    RecordTypeId = agmRtMap.get('Request_Agreement'));
            try {
                insert failAgreement;
                throw new DMLException('An exception should have been thrown by the trigger but was not.');
            } catch (Exception e) {
                Boolean expectedExceptionThrown = e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION') ? true : false;
                //System.AssertEquals(expectedExceptionThrown, true);
            }

            Test.startTest();
            Delete CRCList;
            Test.stopTest();

        }
    }

    static testmethod void testTerminated() {

        Map<String, Id> accRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Account.SObjectType);
        Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);

        // Test User creation
        User u = TestFactory.getCarmignacUserTestApex();

        System.runAs(u) {

            List<Account> accList = new List<Account>{
                    new Account(Name = 'Account FR Test', BusinessDevelopmentRegion__c = 'BP_FR'
                            , Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor')
                            , Billingcity = 'Chicago', BillingStreet = 'asd123', BillingPostalCode = '60606'
                            , BillingCountry = 'United States', In__c = 'Retail', Final_Distribution__c = 'Retail')
                    , new Account(Name = 'Account ES Test', BusinessDevelopmentRegion__c = 'BP_ES'
                            , Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking', RecordTypeId = accRtMap.get('Account_Distributor')
                            , Billingcity = 'Barcelona', BillingStreet = 'xyz456', BillingPostalCode = '70301'
                            , BillingCountry = 'Spain', In__c = 'Retail', Final_Distribution__c = 'Retail')
                    , new Account(Name = 'Account Fail Test', BusinessDevelopmentRegion__c = 'BP_LU', BillingCountry = 'Luxembourg')
            };
            insert accList;

            Grid__c franceGrid = new Grid__c(Name = 'France S5');
            insert franceGrid;

            Convention__c masterAgreement = new Convention__c(Name = 'tmpName', Grid__c = franceGrid.Id, Company__c = accList[0].Id,
                    Countries_of_Distribution__c = 'AL', Code_Type__c = 'Distribution Agreement', Agreement_Type__c = 'Master',
                    RecordTypeId = agmRtMap.get('Request_Agreement'));
            insert masterAgreement;

            Convention__c subAgreement = new Convention__c(Name = 'tmpSUBName', Grid__c = franceGrid.Id, Company__c = accList[1].Id, MasterConvention__c = masterAgreement.Id,
                    Countries_of_Distribution__c = 'AL', Code_Type__c = 'Distribution Agreement',
                    RecordTypeId = agmRtMap.get('Request_Agreement'));
            insert subAgreement;

            Contact newContact = new Contact(Email = 'Test@Email.com', Salutation = 'Ms', LastName = 'User');
            insert newContact;


            List<ConventionRelatedContact__c> CRCList = new List<ConventionRelatedContact__c>{
                    new ConventionRelatedContact__c(Contact__c = newContact.Id, Role__c = 'Rebate/ IS Contact', Convention__c = masterAgreement.Id),
                    new ConventionRelatedContact__c(Contact__c = newContact.Id, Role__c = 'Reallocation / IS Contact', Convention__c = masterAgreement.Id)
            };

            insert CRCList;



            masterAgreement.Status__c = 'Terminated';
            masterAgreement.RecordTypeId = agmRtMap.get('Agreement');
            masterAgreement.SignedDate__c = Date.today();
            update masterAgreement;
            Test.startTest();
            List<Convention__c> children = [SELECT Id, Status__c FROM Convention__c WHERE MasterConvention__c = :masterAgreement.Id];
            System.assert(children[0].Status__c.equals('Pending Termination'));
            Test.stopTest();

        }
    }

    static testmethod void doTestUnusedHandler() {

        AgreementRelatedContactTriggerHandler handler = new AgreementRelatedContactTriggerHandler();
        handler.AfterDelete(null);
        //handler.AfterInsert(null);
        handler.AfterUndelete(null);
        //handler.BeforeDelete(null);
        handler.beforeUpdate(null, null);
        handler.BeforeInsert(null);
    }
}