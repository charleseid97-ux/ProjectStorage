/** ──────────────────────────────────────
 * @description Tests of the ProjectShareclass__c and ProjectShareclassChild__c triggers: share class names, the 4 Project Shareclass Children of a share class, the selection
 *                  of fields to modify on a modification project (teams left to validate on the project phases, fields goal of the children, selected fields blanked
 *                  on the children and copied back to the share class), and the Tax Transparency requests (TaxData__c created then canceled, Tax team email).
 *              US-20194: a field selected on the project first stays to validate when a share class field is selected afterwards.
 * @covers ProjectShareclassHandler   99%   [21-10-26]
 * @covers ProjectShareclassChildHandler   93%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
public class Test_ProjectShareclassTrigger {

    private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();
    private static final Id fundModificationRtId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();

    @testSetup
    static void setup() {
        insert new List<ProjectProduct__c>{
            newProject('OEIC', fundCreationRtId, 'OEIC'),
            newProject('SICAV', fundCreationRtId, 'SICAV'),
            newProject('Modification - Fund - 19/10/2026', fundModificationRtId, 'SICAV')
        };
    }

    @isTest
    static void test_shareclassLifecycle() {
        // Creation projects are renamed by the trigger: found by record type and legal form
        Id oeicId = [SELECT Id FROM ProjectProduct__c WHERE RecordTypeId = :fundCreationRtId AND LegalForm__c = 'OEIC' LIMIT 1].Id;
        Id sicavId = [SELECT Id FROM ProjectProduct__c WHERE RecordTypeId = :fundCreationRtId AND LegalForm__c = 'SICAV' LIMIT 1].Id;
        Id modificationId = [SELECT Id FROM ProjectProduct__c WHERE RecordTypeId = :fundModificationRtId LIMIT 1].Id;
        Map<String, Id> phaseIdByName = new Map<String, Id>();
        for (ProjectProductChild__c phase : [SELECT Id, Name FROM ProjectProductChild__c WHERE ProjectProductParent__c = :modificationId]) {
            phaseIdByName.put(phase.Name, phase.Id);
        }

        // Share class names (US-19137): expected name of each share class
        List<ProjectShareclass__c> namedShareclasses = new List<ProjectShareclass__c>{
            newShareclass(oeicId, 'Accumulating', 'A', 'EUR', 'True', null),
            newShareclass(oeicId, 'Income', 'B', 'USD', 'False', null),
            newShareclass(sicavId, 'Accumulating', 'I', 'GBP', 'False', null),
            newShareclass(sicavId, 'Distributing', 'F', 'CHF', 'True', 'Monthly'),
            newShareclass(sicavId, 'Income', 'X', 'JPY', 'False', 'Quarterly'),
            newShareclass(sicavId, 'Accumulating', 'MyInvestor', 'EUR', 'True', null)
        };
        List<String> expectedNames = new List<String>{ 'A EUR Acc Hdg', 'B USD Inc', 'I GBP Acc', 'F CHF Mdis Hdg', 'X JPY Qinc', 'MyInvestor' };

        // Share class created from the project screen (linked to every phase), then a Fund field selected on the project: NAVFrequency__c (Proposal)
        ShareclassNavigatorController.createAndLinkShareclass(phaseIdByName.get('Engineering'), 'A', 'EUR', 'Accumulating', 'Annually', 'False');
        update new ProjectProduct__c(Id = modificationId, TECH_FieldsToModify__c = 'NAVFrequency__c');

        Test.startTest();

        insert namedShareclasses;

        // Then 2 share class fields selected for modification: DividendFrequency__c (Engineering) and LegalType__c (Proposal)
        ProjectShareclass__c modifiedShareclass = [SELECT Id FROM ProjectShareclass__c WHERE ProjectProduct__c = :modificationId LIMIT 1];
        modifiedShareclass.TECH_FieldsToModify__c = 'DividendFrequency__c;LegalType__c';
        update modifiedShareclass;

        Test.stopTest();

        List<ProjectShareclass__c> savedShareclasses = [SELECT Name__c FROM ProjectShareclass__c WHERE Id IN :namedShareclasses];
        Map<Id, ProjectShareclass__c> savedById = new Map<Id, ProjectShareclass__c>(savedShareclasses);
        for (Integer i = 0; i < namedShareclasses.size(); i++) {
            System.assertEquals(expectedNames[i], savedById.get(namedShareclasses[i].Id).Name__c);
        }

        Set<String> childNames = new Set<String>();
        for (ProjectShareclassChild__c child : [SELECT Name FROM ProjectShareclassChild__c WHERE ProjectShareclasses__c = :namedShareclasses[0].Id]) {
            childNames.add(child.Name);
        }
        System.assertEquals(new Set<String>{ 'Design & Proposal', 'Engineering', 'Filing', 'SetUp' }, childNames, 'One Project Shareclass Child per stage, Design and Proposal sharing one');

        // Teams left to validate: the team owning each selected field, on the phase of its stage only
        ProjectProduct__c modification = [SELECT Scope__c FROM ProjectProduct__c WHERE Id = :modificationId];
        String scope = ProjectProductSetupHandlerUtilities.normalizeScope(modification.Scope__c);
        PMTMatrix matrix = PMTMatrix.get();
        PMTMatrix scopedMatrix = matrix.forScope(scope);
        Map<String, String> teamByField = scopedMatrix.getTeamByField();
        Map<String, Set<String>> teamsByPhase = new Map<String, Set<String>>();
        for (ProjectProductChild__c phase : [SELECT Name, TECH_TeamValidation__c
                                             FROM ProjectProductChild__c
                                             WHERE ProjectProductParent__c = :modificationId]) {
            teamsByPhase.put(phase.Name, ProjectProductSetupHandlerUtilities.splitMultiPicklist(phase.TECH_TeamValidation__c));
        }
        System.assert(!teamsByPhase.get('Engineering').contains(teamByField.get('DividendFrequency__c').replaceAll(' ', '')), 'The team owning DividendFrequency__c validates Engineering again');
        System.assert(!teamsByPhase.get('Proposal').contains(teamByField.get('LegalType__c').replaceAll(' ', '')), 'The team owning LegalType__c validates Proposal again');
        System.assertEquals('Proposal', scopedMatrix.getStageByField().get('NAVFrequency__c'), 'NAVFrequency__c is a Proposal field');
        System.assert(!teamsByPhase.get('Proposal').contains(teamByField.get('NAVFrequency__c').replaceAll(' ', '')), 'US-20194: the project field selected first still has to be validated after the share class save');
        System.assertEquals(matrix.getValidationTeamKeys(), teamsByPhase.get('Filing'), 'No selected field at Filing: every team stays validated');

        // Fields goal of the children: the selected fields required at their stage
        Map<String, List<String>> requiredByStage = matrix.getRequiredFieldsByStage(false);
        for (ProjectShareclassChild__c child : [SELECT TECH_Childtype__c, NbOfFieldsGoal__c
                                                FROM ProjectShareclassChild__c
                                                WHERE ProjectShareclasses__c = :modifiedShareclass.Id]) {
            String stage = child.TECH_Childtype__c == 'DesignAndProposal' ? 'Proposal' : child.TECH_Childtype__c;
            Set<String> selected = new Set<String>{ 'DividendFrequency__c', 'LegalType__c' };
            selected.retainAll(new Set<String>(requiredByStage.get(stage)));
            System.assertEquals(selected.size(), child.NbOfFieldsGoal__c, 'Fields goal of the ' + stage + ' child');
        }

        // The selected fields are blanked on the children, and the blank value is copied back to the share class
        ProjectShareclass__c savedModifiedShareclass = [SELECT DividendFrequency__c FROM ProjectShareclass__c WHERE Id = :modifiedShareclass.Id];
        System.assertEquals(null, savedModifiedShareclass.DividendFrequency__c);
    }

    @isTest
    static void test_taxTransparency() {
        Id projectId = [SELECT Id FROM ProjectProduct__c WHERE RecordTypeId = :fundCreationRtId AND LegalForm__c = 'SICAV' LIMIT 1].Id;
        ProjectShareclass__c shareclass = PMTTestFactoryData.createProjectShareclass(projectId, null);

        Test.startTest();

        // Empty -> 2 selections: 2 TaxData__c requested and the Tax team notified
        shareclass.TaxTransparency__c = 'AT;BE TIS';
        update shareclass;
        Integer emailInvocations = Limits.getEmailInvocations();
        List<TaxData__c> createdTaxData = [SELECT Country__c, Type__c, Status__c, Source__c, ProjectProduct__c
                                           FROM TaxData__c
                                           WHERE ProjectShareclass__c = :shareclass.Id];

        // AT removed: its TaxData__c is canceled
        shareclass.TaxTransparency__c = 'BE TIS';
        update shareclass;

        Test.stopTest();

        Set<String> keys = new Set<String>();
        for (TaxData__c td : createdTaxData) {
            keys.add(td.Country__c + '|' + td.Type__c + '|' + td.Status__c);
            System.assertEquals(projectId, td.ProjectProduct__c);
            System.assertEquals('PMT', td.Source__c);
        }
        System.assertEquals(new Set<String>{ 'AT|Transparency|Requested', 'BE|BE TIS|Requested' }, keys);
        Map<String, String> statusByCountry = new Map<String, String>();
        for (TaxData__c td : [SELECT Country__c, Status__c FROM TaxData__c WHERE ProjectShareclass__c = :shareclass.Id]) {
            statusByCountry.put(td.Country__c, td.Status__c);
        }
        System.assertEquals('Canceled', statusByCountry.get('AT'));
        System.assertEquals('Requested', statusByCountry.get('BE'));

        Integer activeConfigCount = [SELECT COUNT()
                                     FROM TaxEmailConfiguration__mdt
                                     WHERE Country__c = 'ALL' AND Scenario__c = 'InternalTaxTransparencyNotification' AND IsActive__c = true];
        if (activeConfigCount > 0) System.assert(emailInvocations > 0, 'The Tax team is notified of the new requests');
    }

    private static ProjectProduct__c newProject(String name, Id recordTypeId, String legalForm) {
        return new ProjectProduct__c(
            Name = name,
            RecordTypeId = recordTypeId,
            VehicleType__c = 'Funds',
            ProjectStartDate__c = Date.today().addDays(-20),
            EndDate__c = Date.today(),
            RiskAssociated__c = 'Equity;Interest rates;Credit;Currency',
            InvestmentObjective__c = 'Sample Objective',
            InvestmentStrategy__c = 'Sample Strategy',
            DomiciledIn__c = 'FR',
            ProjectStatus__c = 'Closed',
            ProductName__c = 'toto',
            SFDRCategory__c = '0',
            LegalForm__c = legalForm,
            LettreRequise__c = 'No'
        );
    }

    private static ProjectShareclass__c newShareclass(Id projectId, String dividendPolicy, String type, String currencyCode, String hedging, String frequency) {
        return new ProjectShareclass__c(
            ProjectProduct__c = projectId,
            DividendPolicy__c = dividendPolicy,
            Type__c = type,
            Currency__c = currencyCode,
            CurrencyHedging__c = hedging,
            DividendFrequency__c = frequency
        );
    }
}