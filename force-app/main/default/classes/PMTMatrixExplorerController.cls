/** ──────────────────────────────────────
 * @description Controller of the PMT Matrix Explorer (pmtMatrixExplorer LWC): read-only global view of the PMT configuration for the admins.
 *              Reads PMTStage__mdt, PMTTeam__mdt, PMTFieldRule__mdt, PMTFieldRuleLine__mdt, PMTField__mdt and PMTOwnerRule__mdt as stored,
 *                  not the runtime PMTMatrix (which drops lines by scope and condition), so nothing is hidden.
 *              Each field gets a sharing status telling whether its teams can fill it on the same project: SINGLE (one team), SCOPE_SPLIT
 *                  (teams of different PMTTeam__mdt.Scope__c, only one applies per project), CONDITION_SPLIT (every line of the teams has a
 *                  condition, to check that they exclude each other), SHARED (several teams on the same project), UNUSED (no line).
 *              Each condition (Condition__c, and RequiredCondition__c of a Conditional line) is compiled with PMTCondition: its error is shown
 *                  on its line instead of breaking the view.
 *              Fields are described on the stage objects (ProjectProductChild__c, ProjectShareclassChild__c), like PMTMatrix: a field missing
 *                  there is flagged, since PMTMatrix skips its lines. They also show IsModifiable__c and their DependentFields__c (fieldSelector).
 * @author Charles EID
 * @testClass PMTMatrixExplorerControllerTest
 * @coverage 99%   [23-10-26]
 ────────────────────────────────────── */
public with sharing class PMTMatrixExplorerController {

    private static final String FUND_OBJECT = 'Product__c';
    private static final String FUND_LEVEL = 'Fund';
    private static final String SHARE_CLASS_LEVEL = 'Share class';
    private static final String REQUIRED = 'Required';
    private static final String CONDITIONAL = 'Conditional';
    @TestVisible
    private static final String PROJECT_ONLY_ERROR = 'This condition can only read ProjectProduct__c fields';
    @TestVisible
    private static final String MISSING_REQUIRED_CONDITION_ERROR = 'A Conditional line needs a RequiredCondition__c';
    @TestVisible
    private static final String IGNORED_REQUIRED_CONDITION_ERROR = 'RequiredCondition__c is ignored unless Requirement is Conditional';
    @TestVisible
    private static final String UNUSED = 'UNUSED';
    @TestVisible
    private static final String SINGLE = 'SINGLE';
    @TestVisible
    private static final String SCOPE_SPLIT = 'SCOPE_SPLIT';
    @TestVisible
    private static final String CONDITION_SPLIT = 'CONDITION_SPLIT';
    @TestVisible
    private static final String SHARED = 'SHARED';
    // From the least to the most constraining: a field takes the most constraining status among its pairs of teams
    private static final List<String> SHARING_STATUSES = new List<String>{ UNUSED, SINGLE, SCOPE_SPLIT, CONDITION_SPLIT, SHARED };

    @AuraEnabled(cacheable=true)
    public static Model getModel() {
        List<PMTTeam__mdt> teamRecords = [SELECT Id, MasterLabel, Order__c, IsValidationTeam__c, Scope__c, OwnerFederationId__c FROM PMTTeam__mdt ORDER BY Order__c];
        List<PMTOwnerRule__mdt> ownerRuleRecords = [SELECT Id, DeveloperName, Team__r.MasterLabel, Condition__c, OwnerFederationId__c FROM PMTOwnerRule__mdt ORDER BY DeveloperName];
        Set<String> federationIds = new Set<String>();
        for (PMTTeam__mdt record : teamRecords) federationIds.add(record.OwnerFederationId__c);
        for (PMTOwnerRule__mdt record : ownerRuleRecords) federationIds.add(record.OwnerFederationId__c);
        Map<String, String> userNameByFederationId = getUserNameByFederationId(federationIds);

        Model model = new Model();
        for (PMTStage__mdt record : [SELECT Id, MasterLabel, Order__c, DurationDays__c FROM PMTStage__mdt ORDER BY Order__c]) {
            model.stages.add(new Stage(record));
        }
        Map<String, Team> teamByName = new Map<String, Team>();
        for (PMTTeam__mdt record : teamRecords) {
            Team team = new Team(record, userNameByFederationId.get(record.OwnerFederationId__c));
            model.teams.add(team);
            teamByName.put(team.name, team);
        }
        for (PMTOwnerRule__mdt record : ownerRuleRecords) {
            model.ownerRules.add(new OwnerRule(record, userNameByFederationId.get(record.OwnerFederationId__c), getConditionError(record.Condition__c, true)));
        }
        model.fields = getFields(teamByName);
        return model;
    }

    // PMT fields with their lines (team and stage of their rule) and sharing status, described on the stage object of their level (same maps as PMTMatrix.get())
    private static List<Field> getFields(Map<String, Team> teamByName) {
        Map<String, Schema.SObjectField> fundStageFields = Schema.SObjectType.ProjectProductChild__c.fields.getMap();
        Map<String, Schema.SObjectField> shareClassStageFields = Schema.SObjectType.ProjectShareclassChild__c.fields.getMap();
        Map<String, Field> fieldByDeveloperName = new Map<String, Field>();
        for (PMTField__mdt record : [SELECT Id, DeveloperName, Object__c, FieldApiName__c, IsModifiable__c, DependentFields__c FROM PMTField__mdt ORDER BY FieldApiName__c]) {
            Boolean isFund = record.Object__c == FUND_OBJECT;
            fieldByDeveloperName.put(record.DeveloperName, new Field(record, isFund, isFund ? fundStageFields : shareClassStageFields));
        }

        Map<String, PMTFieldRule__mdt> ruleByDeveloperName = new Map<String, PMTFieldRule__mdt>();
        for (PMTFieldRule__mdt record : [SELECT DeveloperName, Team__r.MasterLabel, Stage__r.MasterLabel FROM PMTFieldRule__mdt]) {
            ruleByDeveloperName.put(record.DeveloperName, record);
        }
        for (PMTFieldRuleLine__mdt record : [SELECT Id, DeveloperName, FieldRule__r.DeveloperName, Field__r.DeveloperName, Requirement__c, Condition__c, RequiredCondition__c
                                             FROM PMTFieldRuleLine__mdt ORDER BY DeveloperName]) {
            PMTFieldRule__mdt rule = ruleByDeveloperName.get(record.FieldRule__r.DeveloperName);
            Field field = fieldByDeveloperName.get(record.Field__r.DeveloperName);
            field.lines.add(new Line(record, rule.Team__r.MasterLabel, rule.Stage__r.MasterLabel, field.isFund));
        }
        for (Field field : fieldByDeveloperName.values()) {
            field.sharingStatus = getSharingStatus(field.lines, teamByName);
        }
        return fieldByDeveloperName.values();
    }

    // Two teams of different scopes never apply to the same project; two teams whose lines all have a condition may exclude each other (the admin checks the formulas)
    @TestVisible
    private static String getSharingStatus(List<Line> lines, Map<String, Team> teamByName) {
        Map<String, Boolean> allConditionalByTeam = new Map<String, Boolean>();
        for (Line line : lines) {
            Boolean allConditional = !allConditionalByTeam.containsKey(line.team) || allConditionalByTeam.get(line.team);
            allConditionalByTeam.put(line.team, allConditional && String.isNotBlank(line.condition));
        }
        if (allConditionalByTeam.isEmpty()) return UNUSED;
        if (allConditionalByTeam.size() == 1) return SINGLE;

        List<String> teams = new List<String>(allConditionalByTeam.keySet());
        Integer statusIndex = SHARING_STATUSES.indexOf(SCOPE_SPLIT);
        for (Integer i = 0; i < teams.size(); i++) {
            for (Integer j = i + 1; j < teams.size(); j++) {
                String scope = teamByName.get(teams[i])?.scope;
                String otherScope = teamByName.get(teams[j])?.scope;
                String status = SHARED;
                if (String.isNotBlank(scope) && String.isNotBlank(otherScope) && scope != otherScope) {
                    status = SCOPE_SPLIT;
                }
                else if (allConditionalByTeam.get(teams[i]) && allConditionalByTeam.get(teams[j])) {
                    status = CONDITION_SPLIT;
                }
                statusIndex = Math.max(statusIndex, SHARING_STATUSES.indexOf(status));
            }
        }
        return SHARING_STATUSES[statusIndex];
    }

    // Null for a valid or empty condition; otherwise its compilation error, or the error of a project-level condition (Fund field, owner rule) reading a share class field
    @TestVisible
    private static String getConditionError(String condition, Boolean projectOnly) {
        try {
            PMTCondition compiled = PMTCondition.compile(condition);
            if (projectOnly && compiled != null && compiled.readsShareClass()) return PROJECT_ONLY_ERROR;
            return null;
        }
        catch (PMTCondition.PMTConditionException e) {
            return e.getMessage();
        }
    }

    // Null when valid: RequiredCondition__c is set exactly on the Conditional lines (as PMTMatrixTest checks), then checked like a condition of the line's level
    @TestVisible
    private static String getRequiredConditionError(PMTFieldRuleLine__mdt record, Boolean isFund) {
        Boolean conditional = record.Requirement__c == CONDITIONAL;
        Boolean hasRequiredCondition = String.isNotBlank(record.RequiredCondition__c);
        if (conditional && !hasRequiredCondition) return MISSING_REQUIRED_CONDITION_ERROR;
        if (!conditional && hasRequiredCondition) return IGNORED_REQUIRED_CONDITION_ERROR;
        return getConditionError(record.RequiredCondition__c, isFund);
    }

    private static Map<String, String> getUserNameByFederationId(Set<String> federationIds) {
        Map<String, String> userNameByFederationId = new Map<String, String>();
        for (User user : [SELECT Name, FederationIdentifier FROM User WHERE FederationIdentifier IN :federationIds]) {
            userNameByFederationId.put(user.FederationIdentifier, user.Name);
        }
        return userNameByFederationId;
    }

    public class Model {
        @AuraEnabled public List<Stage> stages = new List<Stage>();
        @AuraEnabled public List<Team> teams = new List<Team>();
        @AuraEnabled public List<Field> fields = new List<Field>();
        @AuraEnabled public List<OwnerRule> ownerRules = new List<OwnerRule>();
    }

    public class Stage {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Integer sortOrder;
        @AuraEnabled public Integer durationDays;

        public Stage(PMTStage__mdt record) {
            id = record.Id;
            name = record.MasterLabel;
            sortOrder = record.Order__c?.intValue();
            durationDays = record.DurationDays__c?.intValue();
        }
    }

    public class Team {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Integer sortOrder;
        @AuraEnabled public Boolean isValidationTeam;
        @AuraEnabled public String scope;
        @AuraEnabled public String ownerFederationId;
        @AuraEnabled public String ownerName;

        public Team(PMTTeam__mdt record, String ownerName) {
            id = record.Id;
            name = record.MasterLabel;
            sortOrder = record.Order__c?.intValue();
            isValidationTeam = record.IsValidationTeam__c == true;
            scope = record.Scope__c;
            ownerFederationId = record.OwnerFederationId__c;
            this.ownerName = ownerName;
        }
    }

    public class OwnerRule {
        @AuraEnabled public Id id;
        @AuraEnabled public String developerName;
        @AuraEnabled public String team;
        @AuraEnabled public String condition;
        @AuraEnabled public String conditionError;
        @AuraEnabled public String ownerFederationId;
        @AuraEnabled public String ownerName;

        public OwnerRule(PMTOwnerRule__mdt record, String ownerName, String conditionError) {
            id = record.Id;
            developerName = record.DeveloperName;
            team = record.Team__r.MasterLabel;
            condition = record.Condition__c;
            this.conditionError = conditionError;
            ownerFederationId = record.OwnerFederationId__c;
            this.ownerName = ownerName;
        }
    }

    // A field API name described on the stage object of its level
    public virtual class DescribedField {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        // False when the API name isn't a field of the stage object (or isn't visible to the user): PMTMatrix skips its lines
        @AuraEnabled public Boolean existsOnObject;

        public DescribedField(String apiName, Map<String, Schema.SObjectField> stageFields) {
            this.apiName = apiName;
            Schema.SObjectField describedField = stageFields.get(apiName);
            existsOnObject = describedField != null;
            label = existsOnObject ? describedField.getDescribe().getLabel() : apiName;
        }
    }

    public class Field extends DescribedField {
        @AuraEnabled public Id id;
        @AuraEnabled public String developerName;
        @AuraEnabled public Boolean isFund;
        @AuraEnabled public String level;
        @AuraEnabled public Boolean isModifiable;
        @AuraEnabled public List<DescribedField> dependentFields = new List<DescribedField>();
        @AuraEnabled public String sharingStatus;
        @AuraEnabled public List<Line> lines = new List<Line>();

        public Field(PMTField__mdt record, Boolean isFund, Map<String, Schema.SObjectField> stageFields) {
            super(record.FieldApiName__c, stageFields);
            id = record.Id;
            developerName = record.DeveloperName;
            this.isFund = isFund;
            level = isFund ? FUND_LEVEL : SHARE_CLASS_LEVEL;
            isModifiable = record.IsModifiable__c == true;
            for (String dependentField : String.isBlank(record.DependentFields__c) ? new List<String>() : record.DependentFields__c.split(';')) {
                if (String.isNotBlank(dependentField)) dependentFields.add(new DescribedField(dependentField.trim(), stageFields));
            }
        }
    }

    public class Line {
        @AuraEnabled public Id id;
        @AuraEnabled public String developerName;
        @AuraEnabled public String team;
        @AuraEnabled public String stage;
        @AuraEnabled public String requirement;
        @AuraEnabled public Boolean isRequired;
        @AuraEnabled public Boolean isConditional;
        @AuraEnabled public String condition;
        @AuraEnabled public String conditionError;
        @AuraEnabled public String requiredCondition;
        @AuraEnabled public String requiredConditionError;

        public Line(PMTFieldRuleLine__mdt record, String team, String stage, Boolean isFund) {
            id = record.Id;
            developerName = record.DeveloperName;
            this.team = team;
            this.stage = stage;
            requirement = record.Requirement__c;
            isRequired = record.Requirement__c == REQUIRED;
            isConditional = record.Requirement__c == CONDITIONAL;
            condition = record.Condition__c;
            conditionError = getConditionError(record.Condition__c, isFund);
            requiredCondition = record.RequiredCondition__c;
            requiredConditionError = getRequiredConditionError(record, isFund);
        }
    }
}
