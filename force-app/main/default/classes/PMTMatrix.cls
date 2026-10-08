/** ──────────────────────────────────────
 * @description Single entry point to the PMT matrix (FIX-20178, replaces ProductProjectSettings__c): stages, teams,
 *                  the fields each team owns at each stage, and the team owners.
 *              Read from PMTStage__mdt, PMTTeam__mdt, PMTFieldRule__mdt and PMTOwnerRule__mdt, once per transaction:
 *                  PMTMatrix matrix = PMTMatrix.get();
 *              forScope(scope) restricts the matrix to the teams of a project scope (PMTTeam__mdt.Scope__c empty or
 *                  equal to the scope); the caller passes an already normalized scope.
 *              Field lists hold one field API name per line. A team and stage without a PMTFieldRule__mdt record has
 *                  no fields there: getRule() then returns an empty rule, never null.
 * @author Charles EID
 * @lastModifiedBy Charles EID   [08-10-26]
 * @testClass Test_PMTMatrix
 * @coverage 100%   [08-10-26]
 ────────────────────────────────────── */
public without sharing class PMTMatrix {

    private static PMTMatrix instance;
    private static Map<String, Id> userIdByFederationId;

    public List<Stage> stages { get; private set; }
    public List<Team> teams { get; private set; }
    public List<FieldRule> rules { get; private set; }
    private List<OwnerRule> ownerRules;
    private Map<String, FieldRule> ruleByKey = new Map<String, FieldRule>();
    private Map<String, PMTMatrix> matrixByScope = new Map<String, PMTMatrix>();

    // Loads the configuration once per transaction. SOQL rather than getAll(): getAll() truncates Long Text Areas to 255 characters.
    public static PMTMatrix get() {
        if (instance != null) return instance;

        List<Stage> stages = new List<Stage>();
        for (PMTStage__mdt record : [SELECT MasterLabel, Order__c, DurationDays__c FROM PMTStage__mdt ORDER BY Order__c]) {
            stages.add(new Stage(record.MasterLabel, record.Order__c?.intValue(), record.DurationDays__c?.intValue()));
        }

        List<Team> teams = new List<Team>();
        for (PMTTeam__mdt record : [SELECT MasterLabel, Order__c, IsValidationTeam__c, Scope__c, OwnerFederationId__c FROM PMTTeam__mdt ORDER BY Order__c]) {
            teams.add(new Team(record.MasterLabel, record.Order__c?.intValue(), record.IsValidationTeam__c, record.Scope__c, record.OwnerFederationId__c));
        }

        List<FieldRule> rules = new List<FieldRule>();
        for (PMTFieldRule__mdt record : [SELECT Team__r.MasterLabel, Stage__r.MasterLabel, RequiredFieldsFund__c, OptionalFieldsFund__c,
                                                RequiredFieldsShareClass__c, OptionalFieldsShareClass__c
                                         FROM PMTFieldRule__mdt]) {
            rules.add(new FieldRule(record.Team__r.MasterLabel, record.Stage__r.MasterLabel,
                                    lines(record.RequiredFieldsFund__c), lines(record.OptionalFieldsFund__c),
                                    lines(record.RequiredFieldsShareClass__c), lines(record.OptionalFieldsShareClass__c)));
        }

        List<OwnerRule> ownerRules = new List<OwnerRule>();
        for (PMTOwnerRule__mdt record : [SELECT Team__r.MasterLabel, Field__c, Values__c, OwnerFederationId__c FROM PMTOwnerRule__mdt ORDER BY DeveloperName]) {
            ownerRules.add(new OwnerRule(record.Team__r.MasterLabel, record.Field__c, lines(record.Values__c), record.OwnerFederationId__c));
        }

        instance = new PMTMatrix(stages, teams, rules, ownerRules);
        return instance;
    }

    // Keeps the rules of the given teams, sorted by stage then team order (same order as the former ORDER BY Order__c, OrderTeam__c).
    private PMTMatrix(List<Stage> stages, List<Team> teams, List<FieldRule> rules, List<OwnerRule> ownerRules) {
        this.stages = stages;
        this.teams = teams;
        this.ownerRules = ownerRules;

        Map<String, FieldRule> allRulesByKey = new Map<String, FieldRule>();
        for (FieldRule rule : rules) {
            String key = rule.team + '|' + rule.stage;
            allRulesByKey.put(key, allRulesByKey.containsKey(key) ? allRulesByKey.get(key).mergedWith(rule) : rule);
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
            matrixByScope.put(scope, new PMTMatrix(stages, scopedTeams, rules, ownerRules));
        }
        return matrixByScope.get(scope);
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

    // Fields of a team at a stage. Never null: a team without fields at that stage gets an empty rule.
    public FieldRule getRule(String teamName, String stageName) {
        FieldRule rule = ruleByKey.get(teamName + '|' + stageName);
        return rule != null ? rule : new FieldRule(teamName, stageName, null, null, null, null);
    }

    // Owning team of each field (last rule wins). Fund lists win over Share Class lists for a field present in both.
    public Map<String, String> getTeamByField() {
        return getFieldMap(true);
    }

    // Stage of each field (last rule wins). Fund lists win over Share Class lists for a field present in both.
    public Map<String, String> getStageByField() {
        return getFieldMap(false);
    }

    // Stage of each field owned by one team (last stage wins).
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

    // ProjectProduct__c fields read by the owner rules (to reapply them when one changes).
    public Set<String> getOwnerRuleFields() {
        Set<String> fields = new Set<String>();
        for (OwnerRule rule : ownerRules) fields.add(rule.field);
        return fields;
    }

    // Owner of each team of this matrix for a project: the team's default owner, then the owner rules.
    // The project must hold the fields read by the owner rules (getOwnerRuleFields()).
    public Map<String, Id> getOwnerIdByTeam(ProjectProduct__c project) {
        Map<String, Id> userIds = getUserIdByFederationId();
        Map<String, Id> ownerIdByTeam = new Map<String, Id>();
        for (Team team : teams) {
            OwnerRule ownerRule = getOwnerRule(team.name, project);
            String federationId = ownerRule != null ? ownerRule.ownerFederationId : team.ownerFederationId;
            ownerIdByTeam.put(team.name, String.isBlank(federationId) ? null : userIds.get(federationId.toLowerCase()));
        }
        return ownerIdByTeam;
    }

    // Rule whose values contain the project's value, otherwise the team's fallback rule (empty values). Null when the field is empty.
    private OwnerRule getOwnerRule(String teamName, ProjectProduct__c project) {
        OwnerRule fallback;
        for (OwnerRule rule : ownerRules) {
            if (rule.team != teamName) continue;
            String value = String.valueOf(project.get(rule.field));
            if (String.isBlank(value)) continue;
            if (rule.values.isEmpty()) {
                if (fallback == null) fallback = rule;
            }
            else if (rule.values.contains(value)) {
                return rule;
            }
        }
        return fallback;
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

    // One value per line: trimmed, blanks and duplicates removed.
    private static List<String> lines(String raw) {
        List<String> values = new List<String>();
        if (String.isBlank(raw)) return values;
        for (String line : raw.split('\\r?\\n')) {
            String value = line.trim();
            if (String.isNotBlank(value) && !values.contains(value)) values.add(value);
        }
        return values;
    }

    // Test only: adds a rule, like inserting a settings row did (merged with an existing rule of the same team and stage).
    @TestVisible
    private static void addRuleForTest(String stageName, String teamName, List<String> requiredFund, List<String> requiredShareClass) {
        PMTMatrix matrix = get();
        List<Stage> stages = new List<Stage>(matrix.stages);
        List<Team> teams = new List<Team>(matrix.teams);
        if (matrix.getStage(stageName) == null) stages.add(new Stage(stageName, stages.size() + 1, null));
        if (matrix.getTeam(teamName) == null) teams.add(new Team(teamName, teams.size() + 1, true, null, null));

        List<FieldRule> rules = new List<FieldRule>(matrix.rules);
        rules.add(new FieldRule(teamName, stageName, requiredFund, null, requiredShareClass, null));
        instance = new PMTMatrix(stages, teams, rules, matrix.ownerRules);
    }

    // Test only: adds an owner rule.
    @TestVisible
    private static void addOwnerRuleForTest(String teamName, String field, List<String> values, String ownerFederationId) {
        PMTMatrix matrix = get();
        List<OwnerRule> ownerRules = new List<OwnerRule>(matrix.ownerRules);
        ownerRules.add(new OwnerRule(teamName, field, values, ownerFederationId));
        instance = new PMTMatrix(matrix.stages, matrix.teams, matrix.rules, ownerRules);
        userIdByFederationId = null;
    }

    // Test only: empty matrix (no stage, team or rule).
    @TestVisible
    private static void clearForTest() {
        instance = new PMTMatrix(new List<Stage>(), new List<Team>(), new List<FieldRule>(), new List<OwnerRule>());
        userIdByFederationId = null;
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

        private FieldRule mergedWith(FieldRule other) {
            return new FieldRule(team, stage, union(requiredFund, other.requiredFund), union(optionalFund, other.optionalFund),
                                 union(requiredShareClass, other.requiredShareClass), union(optionalShareClass, other.optionalShareClass));
        }

        private List<String> union(List<String> first, List<String> second) {
            List<String> values = new List<String>(first);
            for (String value : second) {
                if (!values.contains(value)) values.add(value);
            }
            return values;
        }
    }

    private class OwnerRule {
        private String team;
        private String field;
        private List<String> values;
        private String ownerFederationId;

        private OwnerRule(String team, String field, List<String> values, String ownerFederationId) {
            this.team = team;
            this.field = field;
            this.values = values != null ? values : new List<String>();
            this.ownerFederationId = ownerFederationId;
        }
    }
}