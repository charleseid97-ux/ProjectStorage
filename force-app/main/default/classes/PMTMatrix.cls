/** ──────────────────────────────────────
 * @description Single entry point to the PMT matrix (FIX-20178, replaces ProductProjectSettings__c): stages, teams,
 *                  the fields each team uses at each stage, and the team owners.
 *              Read from PMTStage__mdt, PMTTeam__mdt, PMTFieldRule__mdt (team x stage), PMTFieldRuleLine__mdt (one field of a team at a
 *                  stage, Required or Optional, with an optional condition, US-20194) and PMTOwnerRule__mdt, once per transaction:
 *                  PMTMatrix matrix = PMTMatrix.get();
 *              forScope(scope) restricts the matrix to the teams of a project scope (PMTTeam__mdt.Scope__c empty or equal to the scope);
 *                  the caller passes an already normalized scope.
 *              forConditions(project) drops the lines whose condition (PMTCondition) is false for the project, forProject(project) = forScope
 *                  + forConditions, and forShareClass(id) then drops the lines whose share class condition is false for one share class.
 *                  loadProjects(ids) reads the projects with the fields their conditions read (callers holding only Ids).
 *              A team and stage without an applicable line has no fields there: getRule() then returns an empty rule, never null.
 * @author Charles EID
 * @lastModifiedBy Charles EID   [21-10-26]
 * @testClass PMTMatrixTest
 * @coverage 99%   [21-10-26]
 ────────────────────────────────────── */
public without sharing class PMTMatrix {

    private static final String FUND_OBJECT = 'Product__c';
    private static final String REQUIRED = 'Required';

    // Test classes (PMTTestFactoryData) replace the matrix of the transaction: custom metadata records cannot be inserted in a test
    @TestVisible
    private static PMTMatrix instance;
    @TestVisible
    private static Map<String, Id> userIdByFederationId;
    private static Map<Id, ProjectProduct__c> loadedProjectById = new Map<Id, ProjectProduct__c>();
    private static Map<Id, ProjectShareclass__c> loadedShareClassById = new Map<Id, ProjectShareclass__c>();

    public List<Stage> stages { get; private set; }
    public List<Team> teams { get; private set; }
    public List<FieldRule> rules { get; private set; }
    @TestVisible
    private List<Line> lines = new List<Line>();
    @TestVisible
    private List<OwnerRule> ownerRules;
    private Map<String, FieldRule> ruleByKey = new Map<String, FieldRule>();
    private Map<String, PMTMatrix> matrixByScope = new Map<String, PMTMatrix>();
    private Map<String, PMTMatrix> matrixByConditionResults = new Map<String, PMTMatrix>();

    // Loads the configuration once per transaction. SOQL rather than getAll(): getAll() truncates Long Text Areas (conditions) to 255 characters.
    public static PMTMatrix get() {
        if (instance != null) return instance;

        List<Stage> stages = new List<Stage>();
        for (PMTStage__mdt record : [SELECT MasterLabel, Order__c, DurationDays__c FROM PMTStage__mdt ORDER BY Order__c]) {
            stages.add(new Stage(record.MasterLabel, record.Order__c?.intValue(), record.DurationDays__c?.intValue()));
        }

        List<Team> teams = new List<Team>();
        for (PMTTeam__mdt record : [SELECT MasterLabel, Order__c, IsValidationTeam__c, Scope__c, OwnerFederationId__c
                                    FROM PMTTeam__mdt ORDER BY Order__c]) {
            teams.add(new Team(record.MasterLabel, record.Order__c?.intValue(), record.IsValidationTeam__c, record.Scope__c, record.OwnerFederationId__c));
        }

        Map<String, PMTFieldRule__mdt> ruleByDeveloperName = new Map<String, PMTFieldRule__mdt>();
        for (PMTFieldRule__mdt record : [SELECT DeveloperName, Team__r.MasterLabel, Stage__r.MasterLabel FROM PMTFieldRule__mdt]) {
            ruleByDeveloperName.put(record.DeveloperName, record);
        }

        List<Line> lines = new List<Line>();
        for (PMTFieldRuleLine__mdt record : [SELECT DeveloperName, FieldRule__r.DeveloperName, Field__r.Object__c, Field__r.FieldApiName__c, Requirement__c, Condition__c
                                             FROM PMTFieldRuleLine__mdt ORDER BY DeveloperName]) {
            PMTFieldRule__mdt rule = ruleByDeveloperName.get(record.FieldRule__r.DeveloperName);
            lines.add(new Line(rule.Team__r.MasterLabel, rule.Stage__r.MasterLabel, record.Field__r.Object__c == FUND_OBJECT, record.Field__r.FieldApiName__c,
                               record.Requirement__c == REQUIRED, compileCondition(PMTFieldRuleLine__mdt.SObjectType, record.DeveloperName, record.Condition__c)));
        }

        List<OwnerRule> ownerRules = new List<OwnerRule>();
        for (PMTOwnerRule__mdt record : [SELECT DeveloperName, Team__r.MasterLabel, Condition__c, OwnerFederationId__c
                                         FROM PMTOwnerRule__mdt ORDER BY DeveloperName]) {
            ownerRules.add(new OwnerRule(record.Team__r.MasterLabel, compileCondition(PMTOwnerRule__mdt.SObjectType, record.DeveloperName, record.Condition__c), record.OwnerFederationId__c));
        }

        instance = new PMTMatrix(stages, teams, lines, ownerRules);
        return instance;
    }

    // Entry point of the PMT screens' Apex controllers (LWCs): the matrix, or its configuration error as an AuraHandledException the LWC can show.
    public static PMTMatrix getForScreen() {
        try {
            return get();
        }
        catch (PMTCondition.PMTConditionException e) {
            AuraHandledException auraException = new AuraHandledException(e.getMessage());
            auraException.setMessage(e.getMessage());
            throw auraException;
        }
    }

    // US-20194: a condition that doesn't compile stops the PMT, so its error names the record to fix (custom label PMT_InvalidCondition).
    @TestVisible
    private static PMTCondition compileCondition(Schema.SObjectType recordType, String developerName, String text) {
        try {
            return PMTCondition.compile(text);
        }
        catch (PMTCondition.PMTConditionException e) {
            throw new PMTCondition.PMTConditionException(String.format(System.Label.PMT_InvalidCondition, new List<Object>{ recordType.getDescribe().getLabel(), developerName, e.getMessage() }));
        }
    }

    // Keeps the lines of the given teams, grouped in rules sorted by stage then team order (same order as the former ORDER BY Order__c, OrderTeam__c).
    @TestVisible
    private PMTMatrix(List<Stage> stages, List<Team> teams, List<Line> lines, List<OwnerRule> ownerRules) {
        this.stages = stages;
        this.teams = teams;
        this.ownerRules = ownerRules;

        Set<String> teamNames = new Set<String>();
        for (Team team : teams) teamNames.add(team.name);

        Map<String, FieldRule> allRulesByKey = new Map<String, FieldRule>();
        for (Line line : lines) {
            if (!teamNames.contains(line.team)) continue;
            this.lines.add(line);
            String key = line.team + '|' + line.stage;
            if (!allRulesByKey.containsKey(key)) allRulesByKey.put(key, new FieldRule(line.team, line.stage, null, null, null, null));
            allRulesByKey.get(key).add(line);
        }

        this.rules = new List<FieldRule>();
        for (Stage stage : stages) {
            for (Team team : teams) {
                FieldRule rule = allRulesByKey.get(team.name + '|' + stage.name);
                if (rule == null) continue;
                this.rules.add(rule);
                ruleByKey.put(team.name + '|' + stage.name, rule);
            }
        }
    }

    // Matrix restricted to the teams of a project scope: PMTTeam__mdt.Scope__c empty (every scope) or equal to the scope.
    public PMTMatrix forScope(String scope) {
        if (!matrixByScope.containsKey(scope)) {
            List<Team> scopedTeams = new List<Team>();
            for (Team team : teams) {
                if (String.isBlank(team.scope) || team.scope == scope) scopedTeams.add(team);
            }
            matrixByScope.put(scope, new PMTMatrix(stages, scopedTeams, lines, ownerRules));
        }
        return matrixByScope.get(scope);
    }

    // Matrix of a project: the teams of its Scope, without the lines whose condition is false for the project (forConditions). The project must hold Scope__c and the fields read by the conditions (getConditionFields()): a Trigger.new record or loadProjects().
    public static PMTMatrix forProject(ProjectProduct__c project) {
        return get().forScope(ProjectProductSetupHandlerUtilities.normalizeScope(project.Scope__c)).forConditions(project);
    }

    public static PMTMatrix forProjectId(Id projectId) {
        ProjectProduct__c project = loadProjects(new Set<Id>{ projectId }).get(projectId);
        return project != null ? forProject(project) : get();
    }

    // This matrix without the lines whose condition is false for the project. A line whose condition reads a share class field is kept (it may apply to one of the project's share classes, see forShareClass).
    public PMTMatrix forConditions(ProjectProduct__c project) {
        return filter(project, null);
    }

    // Projects with their Scope and the fields read by the conditions, and their share classes (for forShareClass): one query.
    public static Map<Id, ProjectProduct__c> loadProjects(Set<Id> projectIds) {
        PMTMatrix matrix = get();
        Set<Id> ids = new Set<Id>(projectIds);
        ids.remove(null);
        if (ids.isEmpty()) return new Map<Id, ProjectProduct__c>();

        List<ProjectProduct__c> projects = PMTCondition.queryProjects(ids, matrix.getConditionFields(), matrix.getShareClassConditionFields());
        Map<Id, ProjectProduct__c> projectById = new Map<Id, ProjectProduct__c>(projects);
        loadedProjectById.putAll(projectById);
        for (ProjectProduct__c project : projectById.values()) {
            for (ProjectShareclass__c shareClass : project.ProjectShareclasses__r) loadedShareClassById.put(shareClass.Id, shareClass);
        }
        return projectById;
    }

    // Matrix of one share class of a project matrix: also without the lines whose share class condition is false for it. Its project must have been read by loadProjects(); otherwise (e.g. a share class created in the same transaction) the matrix is unchanged.
    public PMTMatrix forShareClass(Id shareClassId) {
        ProjectShareclass__c shareClass = loadedShareClassById.get(shareClassId);
        if (shareClass == null) return this;
        return filter(loadedProjectById.get(shareClass.ProjectProduct__c), shareClass);
    }

    // Project level (shareClass null): evaluates the conditions that read only the project. Share class level: evaluates the conditions that read the share class. Matrices are cached by condition results, so the projects (or share classes) answering the same share one matrix.
    private PMTMatrix filter(ProjectProduct__c project, ProjectShareclass__c shareClass) {
        Boolean shareClassLevel = shareClass != null;
        List<Line> applicableLines = new List<Line>();
        String conditionResults = shareClassLevel ? 'S' : 'P';
        for (Line line : lines) {
            if (line.condition == null || line.condition.readsShareClass() != shareClassLevel) {
                applicableLines.add(line);
                continue;
            }
            Boolean applies = line.condition.evaluate(project, shareClass);
            conditionResults += applies ? '1' : '0';
            if (applies) applicableLines.add(line);
        }

        if (!matrixByConditionResults.containsKey(conditionResults)) matrixByConditionResults.put(conditionResults, new PMTMatrix(stages, teams, applicableLines, ownerRules));
        return matrixByConditionResults.get(conditionResults);
    }

    public Stage getStage(String name) {
        for (Stage stage : stages) {
            if (stage.name == name) return stage;
        }
        return null;
    }

    public Team getTeam(String name) {
        for (Team team : teams) {
            if (team.name == name) return team;
        }
        return null;
    }

    // Teams that validate the project stages (the former OrderTeam__c NOT IN (15..20)).
    public List<Team> getValidationTeams() {
        List<Team> validationTeams = new List<Team>();
        for (Team team : teams) {
            if (team.isValidationTeam) validationTeams.add(team);
        }
        return validationTeams;
    }

    // Keys of the validation teams (values of TECH_TeamValidation__c), in team order.
    public Set<String> getValidationTeamKeys() {
        Set<String> keys = new Set<String>();
        for (Team team : getValidationTeams()) keys.add(team.key);
        return keys;
    }

    // Fields of a team at a stage. Never null: a team without fields at that stage gets an empty rule.
    public FieldRule getRule(String teamName, String stageName) {
        FieldRule rule = ruleByKey.get(teamName + '|' + stageName);
        return rule != null ? rule : new FieldRule(teamName, stageName, null, null, null, null);
    }

    // Owning team of each field (last rule wins). Fund fields win over Share Class fields of the same name.
    public Map<String, String> getTeamByField() {
        return getFieldMap(true);
    }

    // Stage of each field (last rule wins). Fund fields win over Share Class fields of the same name.
    public Map<String, String> getStageByField() {
        return getFieldMap(false);
    }

    // Stage of each field used by one team (last stage wins).
    public Map<String, String> getStageByField(String teamName) {
        Map<String, String> stageByField = new Map<String, String>();
        for (FieldRule rule : rules) {
            if (rule.team != teamName) continue;
            for (String field : rule.getAllFields()) stageByField.put(field, rule.stage);
        }
        return stageByField;
    }

    // Required fields of every rule (Fund or Share Class), without duplicates.
    public List<String> getRequiredFields(Boolean fund) {
        List<String> requiredFields = new List<String>();
        for (FieldRule rule : rules) {
            for (String field : fund ? rule.requiredFund : rule.requiredShareClass) {
                if (!requiredFields.contains(field)) requiredFields.add(field);
            }
        }
        return requiredFields;
    }

    // Required fields (Fund or Share Class) of the validation teams, per stage. Every stage is a key, possibly with an empty list.
    public Map<String, List<String>> getRequiredFieldsByStage(Boolean fund) {
        Map<String, List<String>> fieldsByStage = new Map<String, List<String>>();
        for (Stage stage : stages) fieldsByStage.put(stage.name, new List<String>());

        for (FieldRule rule : rules) {
            if (!getTeam(rule.team).isValidationTeam) continue;
            List<String> fields = fieldsByStage.get(rule.stage);
            for (String field : fund ? rule.requiredFund : rule.requiredShareClass) {
                if (!fields.contains(field)) fields.add(field);
            }
        }
        return fieldsByStage;
    }

    // Validation teams with no field at each stage (they are validated automatically). Every stage is a key.
    public Map<String, List<String>> getTeamsWithoutFieldsByStage() {
        Map<String, List<String>> teamsByStage = new Map<String, List<String>>();
        for (Stage stage : stages) {
            List<String> teamNames = new List<String>();
            for (Team team : getValidationTeams()) {
                if (getRule(team.name, stage.name).isEmpty()) teamNames.add(team.name);
            }
            teamsByStage.put(stage.name, teamNames);
        }
        return teamsByStage;
    }

    // ProjectProduct__c fields read by the conditions of the lines and owner rules: a project passed to forProject() must hold them, and a change of one of them changes the project's matrix.
    public Set<String> getConditionFields() {
        Set<String> fields = getOwnerRuleFields();
        for (Line line : lines) {
            if (line.condition != null) fields.addAll(line.condition.projectFields);
        }
        return fields;
    }

    // ProjectShareclass__c fields read by the conditions of the lines.
    public Set<String> getShareClassConditionFields() {
        Set<String> fields = new Set<String>();
        for (Line line : lines) {
            if (line.condition != null) fields.addAll(line.condition.shareClassFields);
        }
        return fields;
    }

    // ProjectProduct__c fields read by the owner rules (to reapply them when one changes).
    public Set<String> getOwnerRuleFields() {
        Set<String> fields = new Set<String>();
        for (OwnerRule rule : ownerRules) {
            if (rule.condition != null) fields.addAll(rule.condition.projectFields);
        }
        return fields;
    }

    // ProjectProduct__c fields read by the owner rules of one team.
    public Set<String> getOwnerRuleFields(String teamName) {
        Set<String> fields = new Set<String>();
        for (OwnerRule rule : ownerRules) {
            if (rule.team == teamName && rule.condition != null) fields.addAll(rule.condition.projectFields);
        }
        return fields;
    }

    // Owner of each team of this matrix for a project: the team's default owner, then the owner rules. The project must hold the fields read by the owner rules (getOwnerRuleFields()).
    public Map<String, Id> getOwnerIdByTeam(ProjectProduct__c project) {
        Map<String, Id> userIds = getUserIdByFederationId();
        Map<String, Id> ownerIdByTeam = new Map<String, Id>();
        for (Team team : teams) {
            ownerIdByTeam.put(team.name, String.isBlank(team.ownerFederationId) ? null : userIds.get(team.ownerFederationId.toLowerCase()));
        }
        ownerIdByTeam.putAll(getRuleOwnerIdByTeam(project));
        return ownerIdByTeam;
    }

    // Owner of the teams of this matrix for which an owner rule applies to the project (teams without an applicable rule are absent).
    public Map<String, Id> getRuleOwnerIdByTeam(ProjectProduct__c project) {
        Map<String, Id> userIds = getUserIdByFederationId();
        Map<String, Id> ownerIdByTeam = new Map<String, Id>();
        for (Team team : teams) {
            OwnerRule ownerRule = getOwnerRule(team.name, project);
            if (ownerRule != null) ownerIdByTeam.put(team.name, userIds.get(ownerRule.ownerFederationId.toLowerCase()));
        }
        return ownerIdByTeam;
    }

    // First rule of the team (DeveloperName order) whose condition is true for the project; an empty condition always applies. Null when none applies.
    private OwnerRule getOwnerRule(String teamName, ProjectProduct__c project) {
        for (OwnerRule rule : ownerRules) {
            if (rule.team == teamName && (rule.condition == null || rule.condition.evaluate(project, null))) return rule;
        }
        return null;
    }

    // Active users of every configured owner, by lowercase FederationIdentifier (one SOQL per transaction).
    private static Map<String, Id> getUserIdByFederationId() {
        if (userIdByFederationId != null) return userIdByFederationId;

        PMTMatrix matrix = get();
        Set<String> federationIds = new Set<String>();
        for (Team team : matrix.teams) {
            if (String.isNotBlank(team.ownerFederationId)) federationIds.add(team.ownerFederationId);
        }
        for (OwnerRule rule : matrix.ownerRules) {
            if (String.isNotBlank(rule.ownerFederationId)) federationIds.add(rule.ownerFederationId);
        }

        userIdByFederationId = new Map<String, Id>();
        for (User user : [SELECT Id, FederationIdentifier FROM User WHERE IsActive = true AND FederationIdentifier IN :federationIds]) {
            userIdByFederationId.put(user.FederationIdentifier.toLowerCase(), user.Id);
        }
        return userIdByFederationId;
    }

    private Map<String, String> getFieldMap(Boolean byTeam) {
        Map<String, String> shareClassMap = new Map<String, String>();
        Map<String, String> fundMap = new Map<String, String>();
        for (FieldRule rule : rules) {
            String value = byTeam ? rule.team : rule.stage;
            for (String field : rule.getAllShareClass()) shareClassMap.put(field, value);
            for (String field : rule.getAllFund()) fundMap.put(field, value);
        }
        shareClassMap.putAll(fundMap);
        return shareClassMap;
    }

    public class Stage {
        public String name { get; private set; }
        public Integer sortOrder { get; private set; }
        public Integer durationDays { get; private set; }

        public Stage(String name, Integer sortOrder, Integer durationDays) {
            this.name = name;
            this.sortOrder = sortOrder;
            this.durationDays = durationDays;
        }
    }

    public class Team {
        public String name { get; private set; }
        // Name without spaces: value in TECH_TeamValidation__c, suffix of the PRP permission sets, owner field on ProjectProduct__c (key + '__c').
        public String key { get; private set; }
        public Integer sortOrder { get; private set; }
        public Boolean isValidationTeam { get; private set; }
        public String scope { get; private set; }
        private String ownerFederationId;

        public Team(String name, Integer sortOrder, Boolean isValidationTeam, String scope, String ownerFederationId) {
            this.name = name;
            this.key = name.replaceAll('\\s', '');
            this.sortOrder = sortOrder;
            this.isValidationTeam = isValidationTeam == true;
            this.scope = scope;
            this.ownerFederationId = ownerFederationId;
        }
    }

    // Fields of a team at a stage, built from its applicable lines.
    public class FieldRule {
        public String team { get; private set; }
        public String stage { get; private set; }
        public List<String> requiredFund { get; private set; }
        public List<String> optionalFund { get; private set; }
        public List<String> requiredShareClass { get; private set; }
        public List<String> optionalShareClass { get; private set; }

        public FieldRule(String team, String stage, List<String> requiredFund, List<String> optionalFund, List<String> requiredShareClass, List<String> optionalShareClass) {
            this.team = team;
            this.stage = stage;
            this.requiredFund = requiredFund != null ? requiredFund : new List<String>();
            this.optionalFund = optionalFund != null ? optionalFund : new List<String>();
            this.requiredShareClass = requiredShareClass != null ? requiredShareClass : new List<String>();
            this.optionalShareClass = optionalShareClass != null ? optionalShareClass : new List<String>();
        }

        public List<String> getAllFund() {
            List<String> fields = new List<String>(requiredFund);
            fields.addAll(optionalFund);
            return fields;
        }

        public List<String> getAllShareClass() {
            List<String> fields = new List<String>(requiredShareClass);
            fields.addAll(optionalShareClass);
            return fields;
        }

        public List<String> getAllFields() {
            List<String> fields = getAllFund();
            fields.addAll(getAllShareClass());
            return fields;
        }

        public Boolean isEmpty() {
            return getAllFields().isEmpty();
        }

        private void add(Line line) {
            List<String> fields = line.fund ? (line.required ? requiredFund : optionalFund) : (line.required ? requiredShareClass : optionalShareClass);
            if (!fields.contains(line.field)) fields.add(line.field);
        }
    }

    // One PMTFieldRuleLine__mdt record: a field (Fund or Share Class level) used by a team at a stage.
    @TestVisible
    private class Line {
        private String team;
        private String stage;
        private Boolean fund;
        private String field;
        private Boolean required;
        private PMTCondition condition;

        @TestVisible
        private Line(String team, String stage, Boolean fund, String field, Boolean required, PMTCondition condition) {
            this.team = team;
            this.stage = stage;
            this.fund = fund;
            this.field = field;
            this.required = required;
            this.condition = condition;
        }
    }

    @TestVisible
    private class OwnerRule {
        private String team;
        private PMTCondition condition;
        private String ownerFederationId;

        @TestVisible
        private OwnerRule(String team, PMTCondition condition, String ownerFederationId) {
            this.team = team;
            this.condition = condition;
            this.ownerFederationId = ownerFederationId;
        }
    }
}