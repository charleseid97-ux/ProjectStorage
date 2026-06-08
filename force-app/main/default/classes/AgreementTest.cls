/**
 * @description       :
 * @author            : Thanina YAYA
 * @last modified on  : 11-07-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
@isTest
public class AgreementTest {

    private static final Id recTypeId       = Schema.SObjectType.Convention__c.getRecordTypeInfosByName().get('Sub-distributor via Platforms').getRecordTypeId();
    private static final Id masterRecTypeId = Schema.SObjectType.Convention__c.getRecordTypeInfosByName().get('Intermediary Agreement').getRecordTypeId();

    // ─── Keys used to retrieve @TestSetup records ─────────────────────────────
    private static final String MASTER_AGR_NAME = 'TestMasterAgreement';
    private static final String SUB_AGR_NAME    = 'TestSubAgreement';
    private static final String SECOND_AGR_NAME = 'TestSecondAgreement';
    private static final String LE_NAME         = 'Legal Entity Test';
    private static final String CONTACT_EMAIL   = 'agr.test@carmignac.com';

    // ─── @TestSetup ───────────────────────────────────────────────────────────
    @TestSetup
    static void setupTestData() {
        Map<String, Id> accRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Account.SObjectType);
        Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);
        User u = TestFactory.getCarmignacUserTestApex();

        System.runAs(u) {
            List<Account> accList = new List<Account>{
                new Account(Name = 'Account FR Test',
                    BusinessDevelopmentRegion__c = 'BP_FR', Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking',
                    RecordTypeId = accRtMap.get('Account_Distributor'),
                    Billingcity = 'Chicago', BillingStreet = 'asd123', BillingPostalCode = '60606',
                    BillingCountry = 'United States', In__c = 'Retail', Final_Distribution__c = 'Retail'),
                new Account(Name = 'Account ES Test',
                    BusinessDevelopmentRegion__c = 'BP_ES', Distributor_Type__c = 'Bank', Sub_Type__c = 'Retail Banking',
                    RecordTypeId = accRtMap.get('Account_Distributor'),
                    Billingcity = 'Barcelona', BillingStreet = 'xyz456', BillingPostalCode = '70301',
                    BillingCountry = 'Spain', In__c = 'Retail', Final_Distribution__c = 'Retail')
            };
            insert accList;

            Grid__c franceGrid = new Grid__c(Name = 'France S5');
            insert franceGrid;

            Convention__c masterAgreement = new Convention__c(
                Name = MASTER_AGR_NAME, Grid__c = franceGrid.Id, Company__c = accList[0].Id,
                Countries_of_Distribution__c = 'AL', Code_Type__c = 'Distribution Agreement', Agreement_Type__c = 'Master',
                RecordTypeId = agmRtMap.get('Request_Agreement')
            );
            insert masterAgreement;

            List<SObject> aggList = new List<SObject>{
                new Convention__c(
                    Name = SECOND_AGR_NAME, Grid__c = franceGrid.Id, Company__c = accList[0].Id,
                    Countries_of_Distribution__c = 'AL', Code_Type__c = 'Direct Investor', Agreement_Type__c = 'Standard',
                    RecordTypeId = agmRtMap.get('Investor_without_Agreement_Request')
                ),
                new Convention__c(
                    Name = SUB_AGR_NAME, Grid__c = franceGrid.Id, Company__c = accList[1].Id,
                    MasterConvention__c = masterAgreement.Id,
                    Countries_of_Distribution__c = 'AL', Code_Type__c = 'Distribution Agreement',
                    Amendment_Approval_Status__c = 'Approved', Grid_Request_Approved__c = true,
                    RecordTypeId = agmRtMap.get('Request_Agreement')
                ),
                new Legal_Entity__c(Name = LE_NAME)
            };
            insert aggList;

            Contact newContact = new Contact(
                Email = CONTACT_EMAIL, Salutation = 'Ms', LastName = 'User', MOIS_Default_Contact__c = true
            );
            insert newContact;

            Convention__c masterRef = [SELECT Id FROM Convention__c WHERE Name = :MASTER_AGR_NAME LIMIT 1];
            insert new List<ConventionRelatedContact__c>{
                new ConventionRelatedContact__c(Contact__c = newContact.Id, Role__c = 'Rebate/ IS Contact',        Convention__c = masterRef.Id),
                new ConventionRelatedContact__c(Contact__c = newContact.Id, Role__c = 'Reallocation / IS Contact', Convention__c = masterRef.Id)
            };
        }
    }

    // ─── Query helpers ────────────────────────────────────────────────────────
    private static Convention__c getMasterAgreement() {
        return [SELECT Id, Status__c, Company__c, RecordTypeId, Grid__c, Grid__r.Name, Agreement_Type__c, Code_Type__c,
                       MasterConvention__c, Primary_Rebate_Contact__c, Carmignac_Legal_Entity__c,
                       SignedDate__c, Amendment_Approval_Status__c, Agreement_Termination_Status__c
                FROM Convention__c WHERE Name = :MASTER_AGR_NAME LIMIT 1];
    }

    private static Convention__c getSubAgreement() {
        return [SELECT Id, Status__c, Company__c, RecordTypeId, Grid__c, Agreement_Type__c, Code_Type__c,
                       MasterConvention__c, Primary_Rebate_Contact__c,
                       Amendment_Approval_Status__c, Grid_Request_Approved__c, Agreement_Termination_Status__c
                FROM Convention__c WHERE Name = :SUB_AGR_NAME LIMIT 1];
    }

    private static Convention__c getSecondAgreement() {
        return [SELECT Id, Status__c, Company__c, RecordTypeId, Grid__c, Agreement_Type__c, Code_Type__c
                FROM Convention__c WHERE Name = :SECOND_AGR_NAME LIMIT 1];
    }

    private static Legal_Entity__c getLegalEntity() {
        return [SELECT Id FROM Legal_Entity__c WHERE Name = :LE_NAME LIMIT 1];
    }

    // ─── testRollupAccount ────────────────────────────────────────────────────
    @isTest
    static void testRollupAccount() {
        Account testAcc = TestFactory.getSimpleAccount();
        testAcc.Client_Tier__c          = 'Titanium (Tier 0)';
        testAcc.BusinessDevelopmentRegion__c = 'BP_FR';
        testAcc.Distributor_Type__c     = 'Bank';
        testAcc.Sub_Type__c             = 'Retail Banking';
        testAcc.Billingcity             = 'Paris';
        testAcc.BillingStreet           = '12 rue test';
        testAcc.BillingPostalCode       = '75001';
        testAcc.BillingCountry          = 'France';
        testAcc.In__c                   = 'Retail';
        testAcc.Final_Distribution__c   = 'Retail';
        insert testAcc;

        Grid__c grid = new Grid__c(Name = 'France grid', ActiveGrid__c = true);
        insert grid;

        Convention__c master = new Convention__c(
            RecordTypeId = masterRecTypeId, Grid__c = grid.Id, Company__c = testAcc.Id,
            Name = 'L198', Agreement_Type__c = 'Master', Code_Type__c = 'Platform Master Agreement',
            Countries_of_Distribution__c = 'FR'
        );
        insert master;

        Test.startTest();

        Convention__c convention = new Convention__c(
            MasterConvention__c = master.Id, RecordTypeId = recTypeId, Grid__c = grid.Id, Company__c = testAcc.Id,
            Name = 'L198_IT131', Agreement_Type__c = 'Standard', Code_Type__c = 'Sub-distributor via Platforms',
            Countries_of_Distribution__c = 'FR', AUM_To_Date__c = 1200, YTDNetFlows__c = 800
        );
        insert convention;

        convention.AUM_To_Date__c = 2000;
        convention.YTDNetFlows__c = 3000;
        update convention;

        Test.stopTest();
    }

    // ─── testHandleBeforeUpdate ───────────────────────────────────────────────
    @isTest
    static void testHandleBeforeUpdate() {
        User u = TestFactory.getCarmignacUserTestApex();
        Convention__c subAgreement = getSubAgreement();

        System.runAs(u) {
            Test.startTest();
            SM034_AgreementService.handleBeforeUpdate(
                new List<Convention__c>{ subAgreement },
                new Map<Id, Convention__c>{ subAgreement.Id => subAgreement }
            );
            Test.stopTest();
        }
    }

    // ─── testServiceValidations ───────────────────────────────────────────────
    @isTest
    static void testServiceValidations() {
        User u = TestFactory.getCarmignacUserTestApex();
        Convention__c masterAgreement = getMasterAgreement();
        Convention__c subAgreement    = getSubAgreement();

        System.runAs(u) {
            Test.startTest();
            SM034_AgreementService.isAgreementRoleValidated(masterAgreement, subAgreement);
            SM034_AgreementService.validateRequestISApprovalKYD(masterAgreement, subAgreement);
            SM034_AgreementService.validateRequestISApprovalRiskLevel(masterAgreement);
            SM034_AgreementService.validateRequestComplianceApproval(masterAgreement);
            Test.stopTest();
        }
    }

    // ─── testApprovedAction ───────────────────────────────────────────────────
    @isTest
    static void testApprovedAction() {
        User u = TestFactory.getCarmignacUserTestApex();
        Convention__c masterAgreement = getMasterAgreement();
        Convention__c subAgreement    = getSubAgreement();

        System.runAs(u) {
            Test.startTest();
            SM034_AgreementService.approvedAction(masterAgreement, subAgreement, 'Status 1', 'Status 2');
            Test.stopTest();
        }
    }

    // ─── testCreateRoles ──────────────────────────────────────────────────────
    @isTest
    static void testCreateRoles() {
        User u = TestFactory.getCarmignacUserTestApex();
        Convention__c masterAgreement = getMasterAgreement();
        Convention__c secondAgreement = getSecondAgreement();
        Convention__c subAgreement    = getSubAgreement();
        Legal_Entity__c le            = getLegalEntity();

        System.runAs(u) {
            Test.startTest();
            SM034_AgreementService.createRole(secondAgreement, le.Id);
            SM034_AgreementService.createDefaultLegalEntityAgreementRole(
                new List<Convention__c>{ masterAgreement, secondAgreement, subAgreement }
            );
            Test.stopTest();
        }
    }

    // ─── testDeleteRelatedContacts ────────────────────────────────────────────
    @isTest
    static void testDeleteRelatedContacts() {
        User u = TestFactory.getCarmignacUserTestApex();
        List<ConventionRelatedContact__c> CRCList = [SELECT Id FROM ConventionRelatedContact__c];

        System.runAs(u) {
            Test.startTest();
            delete CRCList;
            Test.stopTest();
        }
    }

    // ─── testTerminated ───────────────────────────────────────────────────────
    @isTest
    static void testTerminated() {
        Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);
        User u = TestFactory.getCarmignacUserTestApex();
        Convention__c masterAgreement = getMasterAgreement();

        System.runAs(u) {
            masterAgreement.Status__c    = 'Terminated';
            masterAgreement.RecordTypeId = agmRtMap.get('Agreement');
            masterAgreement.SignedDate__c = Date.today();

            Test.startTest();
            update masterAgreement;
            Test.stopTest();
        }
    }

    // ─── doTestUnusedHandler ──────────────────────────────────────────────────
    @isTest
    static void doTestUnusedHandler() {
        AgreementRelatedContactTriggerHandler handler = new AgreementRelatedContactTriggerHandler();
        handler.AfterDelete(null);
        handler.AfterUndelete(null);
        handler.beforeUpdate(null, null);
        handler.BeforeInsert(null);
    }
}