/** ──────────────────────────────────────
 * @description Test data factory of the PMT: projects, stages, share classes, junctions, milestones, users, and the PMT matrix of the
 *                  running test (createMatrice, createMatrixLine, createOwnerRule, clearMatrix): custom metadata records cannot be
 *                  inserted in a test, so these replace the matrix of the transaction (PMTMatrix internals visible to tests only).
 * @lastModifiedBy Charles EID   [22-10-26]
 ────────────────────────────────────── */
@isTest
public class PMTTestFactoryData {
    public static FundManager__c createFundManager(String name) {
        FundManager__c manager = new FundManager__c(Name = name, EmpId__c = 123);

        insert manager;
        return manager;
    }

    // Création complète d’un ProjectProduct prêt pour batch
    public static ProjectProduct__c createProjectProductWithAllFields(Id recordTypeId) {
        ProjectProduct__c p = new ProjectProduct__c(
            Name = 'Test Project',
            RecordTypeId = recordTypeId,
            VehicleType__c = 'Funds',
            ProjectStartDate__c = Date.today() - 20,
            EndDate__c = Date.today(),
            RiskAssociated__c = 'Equity;Interest rates;Credit;Currency',
            InvestmentObjective__c = 'Sample Objective',
            InvestmentStrategy__c = 'Sample Strategy',
            DomiciledIn__c = 'FR',
            ProjectStatus__c = 'Closed',
            ProductName__c = 'toto',
            SFDRCategory__c = '0',
            LegalForm__c = 'Other',
        // US-18299: SPC Final can only be completed once the Notice to Shareholders decision is recorded
        LettreRequise__c = 'No'
    );
        System.debug('createProjectProductWithAllFields: ' + p.recordTypeId);
        insert p;
        return p;
    }

    public static ProjectProduct__c createProjectProduct(Id recordTypeId) {
        ProjectProduct__c p = new ProjectProduct__c(
            Name = 'Test Project',
            EndDate__c = Date.today(),
            VehicleType__c = 'Funds', // requis pour le trigger
            ProjectStartDate__c = Date.today(),// ✅ Ajout nécessaire pour éviter l'erreur
            RiskAssociated__c = 'Equity;Interest rates;Credit;Currency',
            RecordTypeId = recordTypeId
        );
        insert p;
        return p;
    }

    public static FundManagerAssignment__c createFundManagerAssignment(Id projId, Id fundManagerId) {
        FundManagerAssignment__c fma = new FundManagerAssignment__c(
            ProductManagementTool__c = projId,
            FundManager__c = fundManagerId,
            RepOrder__c = '1'
        );
        insert fma;
        return fma;
    }

    public static Milestone__c createMilestone(Id projectProductId, String name, Date startDate) {
        Milestone__c milestone = new Milestone__c(
            Name = name,
            Project_product__c = projectProductId,
            StartDate__c = startDate
        );
        insert milestone;
        return milestone;
    }

    public static Id getRecordTypeId(String objectName, String developerName) {
        return Schema.getGlobalDescribe()
            .get(objectName)
            .getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get(developerName)
            .getRecordTypeId();
    }

    public static User createTestUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = alias,
            Email = alias + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Europe/Paris',
            Username = alias + '@test.com'
        );
        insert u;
        return u;
    }

    // FIX-20178: adds required fields of a team at a stage to the PMT matrix of the running test (custom metadata records can't be inserted). Fields are ';' separated; they are merged with the existing fields of the same team and stage.
    public static void createMatrice(String stage, String team, String requiredFields, String requiredSHCFields) {
        List<PMTMatrix.Line> lines = new List<PMTMatrix.Line>();
        for (String field : splitFields(requiredFields)) lines.add(new PMTMatrix.Line(team, stage, true, field, true, null));
        for (String field : splitFields(requiredSHCFields)) lines.add(new PMTMatrix.Line(team, stage, false, field, true, null));
        addMatrixLines(stage, team, lines);
    }

    // US-20194: adds one line to the PMT matrix of the running test (object Product__c or Share_Class__c, Required or Optional, optional condition).
    public static void createMatrixLine(String stage, String team, String objectName, String field, String requirement, String condition) {
        createMatrixLine(stage, team, objectName, field, requirement, condition, null);
    }

    // US-20194 V1.2: same, with the RequiredCondition__c of a Conditional line.
    public static void createMatrixLine(String stage, String team, String objectName, String field, String requirement, String condition, String requiredCondition) {
        PMTMatrix.Line line = new PMTMatrix.Line(team, stage, objectName == 'Product__c', field, requirement == 'Required', PMTCondition.compile(condition));
        if (requirement == 'Conditional') line.requiredCondition = PMTCondition.compile(requiredCondition);
        addMatrixLines(stage, team, new List<PMTMatrix.Line>{ line });
    }

    // US-20194: adds an owner rule to the PMT matrix of the running test, evaluated before the configured ones (it wins when its condition is true).
    public static void createOwnerRule(String team, String condition, String ownerFederationId) {
        PMTMatrix matrix = PMTMatrix.get();
        List<PMTMatrix.OwnerRule> ownerRules = new List<PMTMatrix.OwnerRule>{ new PMTMatrix.OwnerRule(team, PMTCondition.compile(condition), ownerFederationId) };
        ownerRules.addAll(matrix.ownerRules);
        PMTMatrix.instance = new PMTMatrix(matrix.stages, matrix.teams, matrix.lines, ownerRules);
        PMTMatrix.userIdByFederationId = null;
    }

    // FIX-20178: empty PMT matrix for the running test (no stage, team, line or owner rule).
    public static void clearMatrix() {
        PMTMatrix.instance = new PMTMatrix(new List<PMTMatrix.Stage>(), new List<PMTMatrix.Team>(), new List<PMTMatrix.Line>(), new List<PMTMatrix.OwnerRule>());
        PMTMatrix.userIdByFederationId = null;
    }

    // The stage and the team are added to the matrix when missing (the team as a validation team).
    private static void addMatrixLines(String stage, String team, List<PMTMatrix.Line> newLines) {
        PMTMatrix matrix = PMTMatrix.get();
        List<PMTMatrix.Stage> stages = new List<PMTMatrix.Stage>(matrix.stages);
        List<PMTMatrix.Team> teams = new List<PMTMatrix.Team>(matrix.teams);
        if (matrix.getStage(stage) == null) stages.add(new PMTMatrix.Stage(stage, stages.size() + 1, null));
        if (matrix.getTeam(team) == null) teams.add(new PMTMatrix.Team(team, teams.size() + 1, true, null, null));

        List<PMTMatrix.Line> lines = new List<PMTMatrix.Line>(matrix.lines);
        lines.addAll(newLines);
        PMTMatrix.instance = new PMTMatrix(stages, teams, lines, matrix.ownerRules);
    }

    private static List<String> splitFields(String fields) {
        return String.isBlank(fields) ? new List<String>() : fields.split(';');
    }

    public static ProjectProductChild__c createProjectProductChild(Id parentId, String stage, String teamValues) {
        String rtDevName = (stage == 'Design' || stage == 'Proposal') ? 'DesignAndProposal' : stage;
        Id recordTypeId = getRecordTypeId('ProjectProductChild__c', rtDevName);

        ProjectProductChild__c c = new ProjectProductChild__c(
            Name = stage,
            RecordTypeId = recordTypeId,
            ProjectProductParent__c = parentId,
            Status__c = 'Not Started',
            StartDate__c = Date.today(),
            EndDate__c = Date.today().addDays(10),
            TECH_Childtype__c = rtDevName,
            TECH_TeamValidation__c = teamValues
        );
        insert c;
        return c;
    }

    public static ProjectShareclass__c createProjectShareclass(Id parentId, String fieldsToModify) {
        ProjectShareclass__c shc = new ProjectShareclass__c(
            ProjectProduct__c = parentId,
            TECH_FieldsToModify__c = fieldsToModify,
            Type__c = 'A',
            CurrencyIsoCode = 'EUR',
            DividendPolicy__c = 'Accumulating',
            CurrencyHedging__c = 'False'
        );
        insert shc;
        return shc;
    }

    public static Product__c getProduct(Id recId, String code, String name, Boolean isActive) {
        Product__c prod = new Product__c (RecordTypeId = recId,
                                   Name = code,
                                   ProductName__c = name,
                                   Validity__c = isActive);
        insert prod;
        return prod;
    }

    public static ProjectShareclassChild__c createShareclassChild(Id parentId, String stage) {
        String rtDevName = (stage == 'Design' || stage == 'Proposal') ? 'DesignAndProposal' : stage;
        Id recordTypeId = getRecordTypeId('ProjectShareclassChild__c', rtDevName);

        ProjectShareclassChild__c child = new ProjectShareclassChild__c(
            ProjectShareclasses__c = parentId,
            RecordTypeId = recordTypeId,
            TECH_Childtype__c = rtDevName,
            Name = stage,
            Type__c = 'A',
            CurrencyIsoCode = 'EUR',
            DividendPolicy__c = 'Accumulating',
            CurrencyHedging__c = 'False'
        );
        insert child;
        return child;
    }

    public static ProjectChildJunction__c createJunction(Id childId, Id shcId) {
        ProjectChildJunction__c junction = new ProjectChildJunction__c(
            ProjectProductChild__c = childId,
            ProjectShareclass__c = shcId
        );
        insert junction;
        return junction;
    }
}