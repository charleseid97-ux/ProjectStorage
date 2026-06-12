/**
 * @description       :
 * @author            : Thanina YAYA
 * @last modified on  : 08-06-2026
 * @last modified by  : Charles EID
**/
@isTest
public class AgreementTest {

    // ─── Record type developer names ──────────────────────────────────────────
    private static final String RT_ACC_DISTRIBUTOR       = 'Account_Distributor';
    private static final String RT_REQUEST_AGREEMENT     = 'Request_Agreement';
    private static final String RT_INV_WITHOUT_AGREEMENT = 'Investor_without_Agreement_Request';
    private static final String RT_SUB_DIST_REQUEST      = 'Sub_distributor_Agreement_Request';
    private static final String RT_AGREEMENT             = 'Agreement';

    // ─── Record type labels / Code_Type__c values ─────────────────────────────
    private static final String SUB_DISTRIBUTOR_LABEL    = 'Sub-distributor via Platforms';
    private static final String INTERMEDIARY_LABEL       = 'Intermediary Agreement';
    private static final String CODE_DISTRIBUTION        = 'Distribution Agreement';
    private static final String CODE_DIRECT_INVESTOR     = 'Direct Investor';
    private static final String CODE_PLATFORM_MASTER     = 'Platform Master Agreement';

    // ─── Agreement_Type__c values ─────────────────────────────────────────────
    private static final String AGR_TYPE_MASTER          = 'Master';
    private static final String AGR_TYPE_STANDARD        = 'Standard';

    // ─── Status / picklist values ─────────────────────────────────────────────
    private static final String AMDMT_STATUS_APPROVED    = 'Approved';
    private static final String AGR_STATUS_TERMINATED    = 'Terminated';
    private static final String COUNTRIES_AL             = 'AL';
    private static final String COUNTRIES_FR             = 'FR';
    private static final String BDR_BP_FR                = 'BP_FR';
    private static final String DISTRIBUTOR_BANK         = 'Bank';
    private static final String SUB_TYPE_RETAIL_BANKING  = 'Retail Banking';
    private static final String DISTRIBUTION_RETAIL      = 'Retail';

    // ─── Test data stable keys ────────────────────────────────────────────────
    private static final String LE_NAME                  = 'Legal Entity Test';
    private static final String CONTACT_EMAIL            = 'agr.test@carmignac.com';
    private static final String ROLE_REBATE_IS           = 'Rebate/ IS Contact';
    private static final String ROLE_REALLOC_IS          = 'Reallocation / IS Contact';

    // ─── Record type IDs ──────────────────────────────────────────────────────
    private static final Id recTypeId       = Schema.SObjectType.Convention__c.getRecordTypeInfosByName().get(SUB_DISTRIBUTOR_LABEL).getRecordTypeId();
    private static final Id masterRecTypeId = Schema.SObjectType.Convention__c.getRecordTypeInfosByName().get(INTERMEDIARY_LABEL).getRecordTypeId();

    private static final String agreementQuery =
        'SELECT Id, Status__c, Company__c, RecordTypeId, Grid__c, Grid__r.Name, Agreement_Type__c, Code_Type__c, MasterConvention__c, Primary_Rebate_Contact__c, Carmignac_Legal_Entity__c, ' +
        'SignedDate__c, Amendment_Approval_Status__c, Agreement_Termination_Status__c, Approval_Status__c, MasterConvention__r.Company__c, NumberOfUnvalidatedAgreementRole__c, ' +
        'KYD_DD_Oversight_Status__c, KYD_Due_Diligence_Oversight__c, KYD_Responsible__c, Preliminary_Risk_Assesment__c, Compliance_Clearing__c, Grid_Request_Approved__c ' +
        'FROM Convention__c';

    // ─── @TestSetup ───────────────────────────────────────────────────────────
    @TestSetup
    static void setupTestData() {
        Map<String, Id> accRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Account.SObjectType);
        Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);

        List<Account> accList = new List<Account>{
            new Account(
                Name = 'Account FR Test', BusinessDevelopmentRegion__c = BDR_BP_FR,
                Distributor_Type__c = DISTRIBUTOR_BANK, Sub_Type__c = SUB_TYPE_RETAIL_BANKING,
                RecordTypeId = accRtMap.get(RT_ACC_DISTRIBUTOR),
                Billingcity = 'Chicago', BillingStreet = 'asd123', BillingPostalCode = '60606',
                BillingCountry = 'United States', In__c = DISTRIBUTION_RETAIL, Final_Distribution__c = DISTRIBUTION_RETAIL
            ),
            new Account(
                Name = 'Account ES Test', BusinessDevelopmentRegion__c = 'BP_ES',
                Distributor_Type__c = DISTRIBUTOR_BANK, Sub_Type__c = SUB_TYPE_RETAIL_BANKING,
                RecordTypeId = accRtMap.get(RT_ACC_DISTRIBUTOR),
                Billingcity = 'Barcelona', BillingStreet = 'xyz456', BillingPostalCode = '70301',
                BillingCountry = 'Spain', In__c = DISTRIBUTION_RETAIL, Final_Distribution__c = DISTRIBUTION_RETAIL
            )
        };
        insert accList;

        Grid__c franceGrid = new Grid__c(Name = 'France S5', ActiveGrid__c = true);
        insert franceGrid;

        Convention__c masterAgreement = new Convention__c(
            Grid__c = franceGrid.Id, Company__c = accList[0].Id, RecordTypeId = agmRtMap.get(RT_REQUEST_AGREEMENT),
            Countries_of_Distribution__c = COUNTRIES_AL, Code_Type__c = CODE_DISTRIBUTION, Agreement_Type__c = AGR_TYPE_MASTER
        );
        insert masterAgreement;

        List<SObject> aggList = new List<SObject>{
            new Convention__c(
                Grid__c = franceGrid.Id, Company__c = accList[0].Id, RecordTypeId = agmRtMap.get(RT_INV_WITHOUT_AGREEMENT),
                Countries_of_Distribution__c = COUNTRIES_AL, Code_Type__c = CODE_DIRECT_INVESTOR, Agreement_Type__c = AGR_TYPE_STANDARD
            ),
            new Convention__c(
                Grid__c = franceGrid.Id, Company__c = accList[1].Id, MasterConvention__c = masterAgreement.Id,
                Countries_of_Distribution__c = COUNTRIES_AL, Code_Type__c = SUB_DISTRIBUTOR_LABEL,
                Amendment_Approval_Status__c = AMDMT_STATUS_APPROVED, Grid_Request_Approved__c = true,
                RecordTypeId = agmRtMap.get(RT_SUB_DIST_REQUEST)
            ),
            new Legal_Entity__c(Name = LE_NAME)
        };
        insert aggList;

        Contact newContact = new Contact(
            Email = CONTACT_EMAIL, Salutation = 'Ms', LastName = 'User', Source__c = 'Event'
        );
        insert newContact;

        insert new List<ConventionRelatedContact__c>{
            new ConventionRelatedContact__c(Contact__c = newContact.Id, Role__c = ROLE_REBATE_IS,  Convention__c = masterAgreement.Id),
            new ConventionRelatedContact__c(Contact__c = newContact.Id, Role__c = ROLE_REALLOC_IS, Convention__c = masterAgreement.Id)
        };
    }

    // ─── Query helpers ────────────────────────────────────────────────────────
    private static Convention__c getMasterAgreement() {
        return Database.query(agreementQuery + ' WHERE Code_Type__c = :CODE_DISTRIBUTION AND Agreement_Type__c = :AGR_TYPE_MASTER LIMIT 1');
    }

    private static Convention__c getSubAgreement() {
        return Database.query(agreementQuery + ' WHERE Code_Type__c = :SUB_DISTRIBUTOR_LABEL AND MasterConvention__c != null LIMIT 1');
    }

    private static Convention__c getSecondAgreement() {
        return Database.query(agreementQuery + ' WHERE Code_Type__c = :CODE_DIRECT_INVESTOR LIMIT 1');
    }

    private static Legal_Entity__c getLegalEntity() {
        return [SELECT Id FROM Legal_Entity__c WHERE Name = :LE_NAME LIMIT 1];
    }

    // ─── testRollupAccount ────────────────────────────────────────────────────
    @isTest
    static void testRollupAccount() {
        Account testAcc = [SELECT Id FROM Account WHERE BusinessDevelopmentRegion__c = :BDR_BP_FR LIMIT 1];

        Grid__c grid = new Grid__c(Name = 'France grid', ActiveGrid__c = true);
        insert grid;

        Test.startTest();

        Convention__c master = new Convention__c(
            RecordTypeId = masterRecTypeId, Grid__c = grid.Id, Company__c = testAcc.Id,
            Name = 'L198', Agreement_Type__c = AGR_TYPE_MASTER, Code_Type__c = CODE_PLATFORM_MASTER,
            Countries_of_Distribution__c = COUNTRIES_FR
        );
        insert master;

        Convention__c convention = new Convention__c(
            MasterConvention__c = master.Id, RecordTypeId = recTypeId, Grid__c = grid.Id, Company__c = testAcc.Id,
            Name = 'L198_IT131', Agreement_Type__c = AGR_TYPE_STANDARD, Code_Type__c = SUB_DISTRIBUTOR_LABEL,
            Countries_of_Distribution__c = COUNTRIES_FR, AUM_To_Date__c = 1200, YTDNetFlows__c = 800
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
        Convention__c subAgreement = getSubAgreement();

        Test.startTest();
        SM034_AgreementService.handleBeforeUpdate(new List<Convention__c>{ subAgreement }, new Map<Id, Convention__c>{ subAgreement.Id => subAgreement });
        Test.stopTest();
    }

    // ─── testServiceValidations ───────────────────────────────────────────────
    @isTest
    static void testServiceValidations() {
        Convention__c masterAgreement = getMasterAgreement();
        Convention__c subAgreement    = getSubAgreement();

        Test.startTest();
        SM034_AgreementService.isAgreementRoleValidated(masterAgreement, subAgreement);
        SM034_AgreementService.validateRequestISApprovalKYD(masterAgreement, subAgreement);
        SM034_AgreementService.validateRequestISApprovalRiskLevel(masterAgreement);
        SM034_AgreementService.validateRequestComplianceApproval(masterAgreement);
        Test.stopTest();
    }

    // ─── testApprovedAction ───────────────────────────────────────────────────
    @isTest
    static void testApprovedAction() {
        Convention__c masterAgreement = getMasterAgreement();
        Convention__c subAgreement    = getSubAgreement();

        Test.startTest();
        SM034_AgreementService.approvedAction(masterAgreement, subAgreement, 'Status 1', 'Status 2');
        Test.stopTest();
    }

    // ─── testCreateRoles ──────────────────────────────────────────────────────
    @isTest
    static void testCreateRoles() {
        Convention__c masterAgreement = getMasterAgreement();
        Convention__c secondAgreement = getSecondAgreement();
        Convention__c subAgreement    = getSubAgreement();
        Legal_Entity__c le            = getLegalEntity();

        Test.startTest();
        SM034_AgreementService.createRole(secondAgreement, le.Id);
        SM034_AgreementService.createDefaultLegalEntityAgreementRole(new List<Convention__c>{ masterAgreement, secondAgreement, subAgreement });
        Test.stopTest();
    }

    // ─── testDeleteRelatedContacts ────────────────────────────────────────────
    @isTest
    static void testDeleteRelatedContacts() {
        List<ConventionRelatedContact__c> CRCList = [SELECT Id FROM ConventionRelatedContact__c];

        Test.startTest();
        delete CRCList;
        Test.stopTest();
    }

    // ─── testTerminated ───────────────────────────────────────────────────────
    @isTest
    static void testTerminated() {
        Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);
        Convention__c masterAgreement = getMasterAgreement();

        masterAgreement.Status__c                  = AGR_STATUS_TERMINATED;
        masterAgreement.RecordTypeId               = agmRtMap.get(RT_AGREEMENT);
        masterAgreement.SignedDate__c              = Date.today().addDays(-5);
        masterAgreement.ExpirationDate__c          = Date.today();
        masterAgreement.Cancellation_Date__c       = Date.today();
        masterAgreement.Termination_Description__c = 'Test';

        Test.startTest();
        update masterAgreement;
        Test.stopTest();
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