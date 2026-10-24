/** ──────────────────────────────────────
 * @description Controller of the PMT Matrix Explorer (pmtMatrixExplorer LWC): global view of the PMT configuration for the admins.
 *              Reads PMTStage__mdt, PMTTeam__mdt, PMTFieldRule__mdt, PMTFieldRuleLine__mdt, PMTField__mdt and PMTOwnerRule__mdt as stored,
 *                  not the runtime PMTMatrix (which drops lines by scope and condition), so nothing is hidden.
 *              Each field gets a sharing status telling whether its teams can fill it on the same project: SINGLE (one team), SCOPE_SPLIT
 *                  (teams of different PMTTeam__mdt.Scope__c, only one applies per project), CONDITION_SPLIT (every line of the teams has a
 *                  condition, to check that they exclude each other), SHARED (several teams on the same project), UNUSED (no line).
 *              Each condition (Condition__c, and RequiredCondition__c of a Conditional line) is compiled with PMTCondition: its error is shown
 *                  on its line instead of breaking the view.
 *              Fields are described on the stage objects (ProjectProductChild__c, ProjectShareclassChild__c), like PMTMatrix: a field missing
 *                  there is flagged, since PMTMatrix skips its lines. They also show IsModifiable__c and their DependentFields__c (fieldSelector).
 *              US-20194 V1.5: inactive lines (IsActive__c unticked) are shown and flagged, and left out of the sharing status.
 *              US-20194 V1.6: creates and edits rule lines (pmtRuleLineEditor: previewLine, checkCondition, saveLine). A line reuses the PMTField of
 *                  its Object + FieldApiName and the PMTFieldRule of its Team + Stage, or creates them; a Rule + Field already used by another line
 *                  is refused. An existing line keeps its object and field but can move to another team or stage. The records are deployed
 *                  together by Metadata.Operations, whose result is published as PMTConfigurationDeploy__e (DeployCallback) for the explorer.
 *                  A line is named {FUND|SC}_{field}_{index} (e.g. SC_ISIN_2), after its field only, so its name stays true when it moves; its
 *                  label "Team - Stage - Field" is rewritten on every save.
 * @author Charles EID
 * @lastModifiedBy Charles EID   [24-10-26]
 * @testClass PMTMatrixExplorerControllerTest
 * @coverage 99%   [24-10-26]
 ────────────────────────────────────── */
public with sharing class PMTMatrixExplorerController {

    private static final String FUND_OBJECT = 'Product__c';
    private static final String SHARE_CLASS_OBJECT = 'Share_Class__c';
    private static final String FUND_LEVEL = 'Fund';
    private static final String SHARE_CLASS_LEVEL = 'Share class';
    private static final String REQUIRED = 'Required';
    private static final String CONDITIONAL = 'Conditional';
    private static final Integer NAME_MAX_LENGTH = 40;
    // A rule line DeveloperName is {FUND|SC}_{field}_{index}: the base is cut to 37 characters so that _1 to _99 always fit in 40
    private static final Integer LINE_NAME_BASE_MAX_LENGTH = 37;
    private static final Integer DEPENDENT_FIELDS_MAX_LENGTH = 255;
    @TestVisible
    private static final String PROJECT_ONLY_ERROR = 'This condition can only read ProjectProduct__c fields';
    @TestVisible
    private static final String MISSING_REQUIRED_CONDITION_ERROR = 'A Conditional line needs a RequiredCondition__c';
    @TestVisible
    private static final String IGNORED_REQUIRED_CONDITION_ERROR = 'RequiredCondition__c is ignored unless Requirement is Conditional';
    @TestVisible
    private static final String NO_EDIT_ACCESS_ERROR = 'You need the Customize Application permission to change the PMT configuration';
    @TestVisible
    private static final String INCOMPLETE_LINE_ERROR = 'Team, stage, level, field and requirement are required';
    @TestVisible
    private static final String INVALID_VALUE_ERROR = 'Unknown team, stage, level or requirement';
    @TestVisible
    private static final String MISSING_FIELD_ERROR = '{0} is not a field of {1}';
    @TestVisible
    private static final String DEPENDENT_FIELDS_TOO_LONG_ERROR = 'The dependent fields exceed 255 characters';
    @TestVisible
    private static final String DUPLICATE_LINE_ERROR = 'This team already uses this field at this stage: edit the existing line instead';
    @TestVisible
    private static final String IDENTITY_LOCKED_ERROR = 'The object and field of an existing line cannot change: deactivate it and create a new line';
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

    // US-20194 V1.6: Metadata.Operations cannot deploy in a test, which reads the container built and the event published instead
    @TestVisible
    private static Metadata.DeployContainer lastContainer;
    @TestVisible
    private static PMTConfigurationDeploy__e lastDeployEvent;

    @AuraEnabled(cacheable=true)
    public static Model getModel() {
        List<PMTTeam__mdt> teamRecords = [SELECT Id, DeveloperName, MasterLabel, Order__c, IsValidationTeam__c, Scope__c, OwnerFederationId__c FROM PMTTeam__mdt ORDER BY Order__c];
        List<PMTOwnerRule__mdt> ownerRuleRecords = [SELECT Id, DeveloperName, Team__r.MasterLabel, Condition__c, OwnerFederationId__c FROM PMTOwnerRule__mdt ORDER BY DeveloperName];
        Set<String> federationIds = new Set<String>();
        for (PMTTeam__mdt record : teamRecords) federationIds.add(record.OwnerFederationId__c);
        for (PMTOwnerRule__mdt record : ownerRuleRecords) federationIds.add(record.OwnerFederationId__c);
        Map<String, String> userNameByFederationId = getUserNameByFederationId(federationIds);

        Model model = new Model();
        for (PMTStage__mdt record : [SELECT Id, DeveloperName, MasterLabel, Order__c, DurationDays__c FROM PMTStage__mdt ORDER BY Order__c]) {
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

        // US-20194 V1.6: what the rule line editor offers
        model.canEdit = canEdit();
        model.levelOptions = getPicklistOptions(Schema.SObjectType.PMTField__mdt.fields.Object__c);
        model.requirementOptions = getPicklistOptions(Schema.SObjectType.PMTFieldRuleLine__mdt.fields.Requirement__c);
        model.fieldOptionsByLevel = new Map<String, List<Option>>{ FUND_OBJECT => getFieldOptions(true), SHARE_CLASS_OBJECT => getFieldOptions(false) };
        model.helpTextByField = getHelpTexts();
        return model;
    }

    // US-20194 V1.6: what saving the line would reuse or create, and why it would be refused (shown by the editor while the admin fills it)
    @AuraEnabled
    public static LinePreview previewLine(String requestJson) {
        LineRequest request = (LineRequest) JSON.deserialize(requestJson, LineRequest.class);
        LineContext context = getLineContext(request);
        return new LinePreview(context);
    }

    // US-20194 V1.6: "Check condition" button of the editor: the error of a condition, or the fields it reads (a ProjectShareclass__c field means one evaluation per share class)
    @AuraEnabled
    public static ConditionCheck checkCondition(String condition, String objectName, Boolean isRequired) {
        ConditionCheck check = new ConditionCheck();
        check.error = isRequired == true && String.isBlank(condition) ? MISSING_REQUIRED_CONDITION_ERROR : getConditionError(condition, objectName == FUND_OBJECT);
        if (check.error == null && String.isNotBlank(condition)) {
            PMTCondition compiled = PMTCondition.compile(condition);
            check.projectFields = new List<String>(compiled.projectFields);
            check.shareClassFields = new List<String>(compiled.shareClassFields);
        }
        return check;
    }

    // US-20194 V1.6: deploys the line with the PMTField and PMTFieldRule it needs, in one deployment (all saved or none); its result arrives as PMTConfigurationDeploy__e
    @AuraEnabled
    public static Id saveLine(String requestJson) {
        if (!canEdit()) throw newAuraException(NO_EDIT_ACCESS_ERROR);
        LineRequest request = (LineRequest) JSON.deserialize(requestJson, LineRequest.class);
        LineContext context = getLineContext(request);
        if (!context.errors.isEmpty()) throw newAuraException(String.join(context.errors, '\n'));

        lastContainer = buildContainer(request, context);
        if (Test.isRunningTest()) return null;
        return Metadata.Operations.enqueueDeployment(lastContainer, new DeployCallback());
    }

    // PMT fields with their lines (team and stage of their rule) and sharing status, described on the stage object of their level (same maps as PMTMatrix.get())
    private static List<Field> getFields(Map<String, Team> teamByName) {
        Map<String, Schema.SObjectField> fundStageFields = getStageObject(true).fields.getMap();
        Map<String, Schema.SObjectField> shareClassStageFields = getStageObject(false).fields.getMap();
        Map<String, Field> fieldByDeveloperName = new Map<String, Field>();
        for (PMTField__mdt record : [SELECT Id, DeveloperName, Object__c, FieldApiName__c, IsModifiable__c, DependentFields__c FROM PMTField__mdt ORDER BY FieldApiName__c]) {
            Boolean isFund = record.Object__c == FUND_OBJECT;
            fieldByDeveloperName.put(record.DeveloperName, new Field(record, isFund, isFund ? fundStageFields : shareClassStageFields));
        }

        Map<String, PMTFieldRule__mdt> ruleByDeveloperName = new Map<String, PMTFieldRule__mdt>();
        for (PMTFieldRule__mdt record : [SELECT DeveloperName, Team__r.DeveloperName, Team__r.MasterLabel, Stage__r.DeveloperName, Stage__r.MasterLabel FROM PMTFieldRule__mdt]) {
            ruleByDeveloperName.put(record.DeveloperName, record);
        }
        for (PMTFieldRuleLine__mdt record : [SELECT Id, DeveloperName, FieldRule__r.DeveloperName, Field__r.DeveloperName, Requirement__c, Condition__c, RequiredCondition__c, IsActive__c
                                             FROM PMTFieldRuleLine__mdt ORDER BY DeveloperName]) {
            PMTFieldRule__mdt rule = ruleByDeveloperName.get(record.FieldRule__r.DeveloperName);
            Field field = fieldByDeveloperName.get(record.Field__r.DeveloperName);
            Line line = new Line(record, rule.Team__r.MasterLabel, rule.Stage__r.MasterLabel, field.isFund);
            line.teamDeveloperName = rule.Team__r.DeveloperName;
            line.stageDeveloperName = rule.Stage__r.DeveloperName;
            field.lines.add(line);
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
            if (!line.isActive) continue; // US-20194 V1.5: an inactive line is not used by the PMT
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
    private static String getRequiredConditionError(String requirement, String requiredCondition, Boolean isFund) {
        Boolean conditional = requirement == CONDITIONAL;
        Boolean hasRequiredCondition = String.isNotBlank(requiredCondition);
        if (conditional && !hasRequiredCondition) return MISSING_REQUIRED_CONDITION_ERROR;
        if (!conditional && hasRequiredCondition) return IGNORED_REQUIRED_CONDITION_ERROR;
        return getConditionError(requiredCondition, isFund);
    }

    // US-20194 V1.6: rule 1 (one PMTField per Object + FieldApiName) and rule 2 (one PMTFieldRule per Team + Stage) find the records to reuse, rule 3 (one line per Rule + Field) the line the request would duplicate; then the fields and conditions are checked
    private static LineContext getLineContext(LineRequest request) {
        LineContext context = new LineContext();
        if (String.isBlank(request.team) || String.isBlank(request.stage) || String.isBlank(request.objectName) || String.isBlank(request.fieldApiName) || String.isBlank(request.requirement)) {
            context.errors.add(INCOMPLETE_LINE_ERROR);
            return context;
        }
        context.isFund = request.objectName == FUND_OBJECT;
        List<PMTTeam__mdt> teams = [SELECT DeveloperName, MasterLabel FROM PMTTeam__mdt WHERE DeveloperName = :request.team];
        List<PMTStage__mdt> stages = [SELECT DeveloperName, MasterLabel FROM PMTStage__mdt WHERE DeveloperName = :request.stage];
        Set<String> requirements = new Set<String>();
        for (Option option : getPicklistOptions(Schema.SObjectType.PMTFieldRuleLine__mdt.fields.Requirement__c)) requirements.add(option.value);
        if (teams.isEmpty() || stages.isEmpty() || (!context.isFund && request.objectName != SHARE_CLASS_OBJECT) || !requirements.contains(request.requirement)) {
            context.errors.add(INVALID_VALUE_ERROR);
            return context;
        }
        context.team = teams[0];
        context.stage = stages[0];

        Schema.DescribeSObjectResult stageObject = getStageObject(context.isFund);
        Map<String, Schema.SObjectField> stageFields = stageObject.fields.getMap();
        context.stageField = stageFields.get(request.fieldApiName);
        if (context.stageField == null) context.errors.add(String.format(MISSING_FIELD_ERROR, new List<Object>{ request.fieldApiName, stageObject.getName() }));
        for (String dependentField : request.dependentFields != null ? request.dependentFields : new List<String>()) {
            Schema.SObjectField stageDependentField = stageFields.get(dependentField);
            if (stageDependentField == null) {
                context.errors.add(String.format(MISSING_FIELD_ERROR, new List<Object>{ dependentField, stageObject.getName() }));
            }
            else {
                context.dependentFields.add(stageDependentField.getDescribe().getName());
            }
        }
        if (String.join(context.dependentFields, ';').length() > DEPENDENT_FIELDS_MAX_LENGTH) context.errors.add(DEPENDENT_FIELDS_TOO_LONG_ERROR);

        for (PMTField__mdt record : [SELECT DeveloperName, MasterLabel, FieldApiName__c, IsModifiable__c, DependentFields__c FROM PMTField__mdt WHERE Object__c = :request.objectName]) {
            if (record.FieldApiName__c.equalsIgnoreCase(request.fieldApiName)) context.field = record;
        }
        for (PMTFieldRule__mdt record : [SELECT DeveloperName, Team__r.DeveloperName, Stage__r.DeveloperName FROM PMTFieldRule__mdt]) {
            if (record.Team__r.DeveloperName == request.team && record.Stage__r.DeveloperName == request.stage) context.rule = record;
        }
        for (PMTFieldRuleLine__mdt record : [SELECT Id, DeveloperName, MasterLabel, FieldRule__r.DeveloperName, Field__r.DeveloperName FROM PMTFieldRuleLine__mdt]) {
            if (record.Id == request.lineId) context.line = record;
            if (context.field == null || record.Field__r.DeveloperName != context.field.DeveloperName) continue;
            context.fieldLineCount++;
            if (context.rule != null && record.FieldRule__r.DeveloperName == context.rule.DeveloperName && record.Id != request.lineId) context.conflictLineId = record.Id;
        }
        if (context.conflictLineId != null) context.errors.add(DUPLICATE_LINE_ERROR);
        // An existing line can move to another team or stage (another or a new PMTFieldRule), never to another field
        if (request.lineId != null && (context.line == null || context.line.Field__r.DeveloperName != context.field?.DeveloperName)) context.errors.add(IDENTITY_LOCKED_ERROR);

        String conditionError = getConditionError(request.condition, context.isFund);
        if (conditionError != null) context.errors.add('Condition: ' + conditionError);
        String requiredConditionError = getRequiredConditionError(request.requirement, request.requiredCondition, context.isFund);
        if (requiredConditionError != null) context.errors.add('Required when: ' + requiredConditionError);
        return context;
    }

    // US-20194 V1.6: the PMTField when new or when its field-wide values change, the PMTFieldRule when new, and the line. A deployed record is replaced as a whole, so every value is sent; relationships point to DeveloperNames
    private static Metadata.DeployContainer buildContainer(LineRequest request, LineContext context) {
        Metadata.DeployContainer container = new Metadata.DeployContainer();
        String fieldApiName = context.field != null ? context.field.FieldApiName__c : context.stageField.getDescribe().getName();
        String fieldName = fieldApiName.removeEndIgnoreCase('__c');
        String dependentFields = context.dependentFields.isEmpty() ? null : String.join(context.dependentFields, ';');
        Boolean isModifiable = request.isModifiable == true;
        String fieldDeveloperName = context.field?.DeveloperName;
        if (context.field == null || context.field.IsModifiable__c != isModifiable || context.field.DependentFields__c != dependentFields) {
            String levelSuffix = context.isFund ? 'Fund' : 'SC';
            if (fieldDeveloperName == null) fieldDeveloperName = getUniqueName(levelSuffix + fieldName, PMTField__mdt.getAll().keySet());
            String fieldLabel = context.field != null ? context.field.MasterLabel : (fieldName + ' (' + levelSuffix + ')').left(NAME_MAX_LENGTH);
            container.addMetadata(buildRecord('PMTField', fieldDeveloperName, fieldLabel, new Map<String, Object>{
                'Object__c' => request.objectName,
                'FieldApiName__c' => fieldApiName,
                'IsModifiable__c' => isModifiable,
                'DependentFields__c' => dependentFields
            }));
        }

        String ruleDeveloperName = context.rule?.DeveloperName;
        if (ruleDeveloperName == null) {
            ruleDeveloperName = getUniqueName(context.team.DeveloperName + context.stage.DeveloperName, PMTFieldRule__mdt.getAll().keySet());
            container.addMetadata(buildRecord('PMTFieldRule', ruleDeveloperName, (context.team.MasterLabel + ' - ' + context.stage.MasterLabel).left(NAME_MAX_LENGTH), new Map<String, Object>{
                'Team__c' => context.team.DeveloperName,
                'Stage__c' => context.stage.DeveloperName
            }));
        }

        // The DeveloperName only names the field, which never changes; the label follows the team and stage, so it is rewritten on every save
        String lineDeveloperName = context.line != null ? context.line.DeveloperName : getLineName(context.isFund, fieldName, PMTFieldRuleLine__mdt.getAll().keySet());
        String lineLabel = (context.team.MasterLabel + ' - ' + context.stage.MasterLabel + ' - ' + fieldName).left(NAME_MAX_LENGTH);
        container.addMetadata(buildRecord('PMTFieldRuleLine', lineDeveloperName, lineLabel, new Map<String, Object>{
            'FieldRule__c' => ruleDeveloperName,
            'Field__c' => fieldDeveloperName,
            'Requirement__c' => request.requirement,
            'Condition__c' => String.isBlank(request.condition) ? null : request.condition,
            'RequiredCondition__c' => String.isBlank(request.requiredCondition) ? null : request.requiredCondition,
            'IsActive__c' => request.isActive != false
        }));
        return container;
    }

    private static Metadata.CustomMetadata buildRecord(String type, String developerName, String label, Map<String, Object> valueByField) {
        Metadata.CustomMetadata record = new Metadata.CustomMetadata();
        record.fullName = type + '.' + developerName;
        record.label = label;
        for (String field : valueByField.keySet()) {
            Metadata.CustomMetadataValue value = new Metadata.CustomMetadataValue();
            value.field = field;
            value.value = valueByField.get(field);
            record.values.add(value);
        }
        return record;
    }

    // DeveloperName: letters and digits only, 40 characters at most, with a number at the end when it is already taken
    @TestVisible
    private static String getUniqueName(String base, Set<String> takenNames) {
        Set<String> taken = new Set<String>();
        for (String takenName : takenNames) taken.add(takenName.toLowerCase());
        String cleanBase = base.replaceAll('[^A-Za-z0-9]', '');
        String name = cleanBase.left(NAME_MAX_LENGTH);
        for (Integer suffix = 2; taken.contains(name.toLowerCase()); suffix++) {
            name = cleanBase.left(NAME_MAX_LENGTH - String.valueOf(suffix).length()) + suffix;
        }
        return name;
    }

    // US-20194 V1.6: {FUND|SC}_{field}_{first free index}, e.g. SC_ISIN_2; the base is cut to 37 characters (without a trailing _, a DeveloperName cannot hold __)
    @TestVisible
    private static String getLineName(Boolean isFund, String fieldName, Set<String> takenNames) {
        Set<String> taken = new Set<String>();
        for (String takenName : takenNames) taken.add(takenName.toLowerCase());
        String base = ((isFund ? 'FUND_' : 'SC_') + fieldName).left(LINE_NAME_BASE_MAX_LENGTH).removeEnd('_');
        Integer index = 1;
        while (taken.contains((base + '_' + index).toLowerCase())) index++;
        return base + '_' + index;
    }

    // US-20194 V1.6: saving deploys metadata, so only the users who can customize the application edit the configuration
    private static Boolean canEdit() {
        List<UserPermissionAccess> permissions = [SELECT PermissionsCustomizeApplication FROM UserPermissionAccess LIMIT 1];
        return !permissions.isEmpty() && permissions[0].PermissionsCustomizeApplication;
    }

    // Stage object of a level, where the PMT reads its fields (as PMTMatrix.get())
    private static Schema.DescribeSObjectResult getStageObject(Boolean isFund) {
        return isFund ? Schema.SObjectType.ProjectProductChild__c : Schema.SObjectType.ProjectShareclassChild__c;
    }

    // Custom fields of a stage object, the choices of the editor's field and dependent field pickers, sorted by label
    private static List<Option> getFieldOptions(Boolean isFund) {
        List<Option> options = new List<Option>();
        for (Schema.SObjectField stageField : getStageObject(isFund).fields.getMap().values()) {
            Schema.DescribeFieldResult describedField = stageField.getDescribe();
            if (describedField.isCustom()) options.add(new Option(describedField.getLabel() + ' (' + describedField.getName() + ')', describedField.getName()));
        }
        options.sort();
        return options;
    }

    // Inline help of the fields the editor shows, by 'Object.Field' (e.g. PMTFieldRuleLine__mdt.Condition__c): edited in Setup, the editor follows
    private static Map<String, String> getHelpTexts() {
        Map<String, String> helpTextByField = new Map<String, String>();
        for (Schema.SObjectType type : new List<Schema.SObjectType>{ PMTField__mdt.SObjectType, PMTFieldRule__mdt.SObjectType, PMTFieldRuleLine__mdt.SObjectType }) {
            String objectName = type.getDescribe().getName();
            for (Schema.SObjectField field : type.getDescribe().fields.getMap().values()) {
                Schema.DescribeFieldResult describedField = field.getDescribe();
                if (String.isNotBlank(describedField.getInlineHelpText())) helpTextByField.put(objectName + '.' + describedField.getName(), describedField.getInlineHelpText());
            }
        }
        return helpTextByField;
    }

    private static List<Option> getPicklistOptions(Schema.DescribeFieldResult picklistField) {
        List<Option> options = new List<Option>();
        for (Schema.PicklistEntry entry : picklistField.getPicklistValues()) {
            if (entry.isActive()) options.add(new Option(entry.getLabel(), entry.getValue()));
        }
        return options;
    }

    // DependentFields__c values: API names separated by ;
    private static List<String> splitFieldNames(String fieldNames) {
        List<String> names = new List<String>();
        for (String name : String.isBlank(fieldNames) ? new List<String>() : fieldNames.split(';')) {
            if (String.isNotBlank(name)) names.add(name.trim());
        }
        return names;
    }

    private static Map<String, String> getUserNameByFederationId(Set<String> federationIds) {
        Map<String, String> userNameByFederationId = new Map<String, String>();
        for (User user : [SELECT Name, FederationIdentifier FROM User WHERE FederationIdentifier IN :federationIds]) {
            userNameByFederationId.put(user.FederationIdentifier, user.Name);
        }
        return userNameByFederationId;
    }

    private static AuraHandledException newAuraException(String message) {
        AuraHandledException auraException = new AuraHandledException(message);
        auraException.setMessage(message);
        return auraException;
    }

    // US-20194 V1.6: tells the explorer how its deployment ended (it waits for the job Id returned by saveLine)
    public class DeployCallback implements Metadata.DeployCallback {
        public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
            List<String> problems = new List<String>();
            for (Metadata.DeployMessage failure : result.details?.componentFailures != null ? result.details.componentFailures : new List<Metadata.DeployMessage>()) {
                problems.add(failure.fullName + ': ' + failure.problem);
            }
            if (String.isNotBlank(result.errorMessage)) problems.add(result.errorMessage);
            lastDeployEvent = new PMTConfigurationDeploy__e(JobId__c = result.id, IsSuccess__c = result.status == Metadata.DeployStatus.Succeeded, Message__c = String.join(problems, '\n'));
            EventBus.publish(lastDeployEvent);
        }
    }

    public class Model {
        @AuraEnabled public List<Stage> stages = new List<Stage>();
        @AuraEnabled public List<Team> teams = new List<Team>();
        @AuraEnabled public List<Field> fields = new List<Field>();
        @AuraEnabled public List<OwnerRule> ownerRules = new List<OwnerRule>();
        @AuraEnabled public Boolean canEdit;
        @AuraEnabled public List<Option> levelOptions;
        @AuraEnabled public List<Option> requirementOptions;
        @AuraEnabled public Map<String, List<Option>> fieldOptionsByLevel;
        @AuraEnabled public Map<String, String> helpTextByField;
    }

    public class Option implements Comparable {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public Option(String label, String value) {
            this.label = label;
            this.value = value;
        }

        public Integer compareTo(Object other) {
            return label.compareTo(((Option) other).label);
        }
    }

    public class Stage {
        @AuraEnabled public Id id;
        @AuraEnabled public String developerName;
        @AuraEnabled public String name;
        @AuraEnabled public Integer sortOrder;
        @AuraEnabled public Integer durationDays;

        public Stage(PMTStage__mdt record) {
            id = record.Id;
            developerName = record.DeveloperName;
            name = record.MasterLabel;
            sortOrder = record.Order__c?.intValue();
            durationDays = record.DurationDays__c?.intValue();
        }
    }

    public class Team {
        @AuraEnabled public Id id;
        @AuraEnabled public String developerName;
        @AuraEnabled public String name;
        @AuraEnabled public Integer sortOrder;
        @AuraEnabled public Boolean isValidationTeam;
        @AuraEnabled public String scope;
        @AuraEnabled public String ownerFederationId;
        @AuraEnabled public String ownerName;

        public Team(PMTTeam__mdt record, String ownerName) {
            id = record.Id;
            developerName = record.DeveloperName;
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
        @AuraEnabled public String objectName;
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
            objectName = record.Object__c;
            this.isFund = isFund;
            level = isFund ? FUND_LEVEL : SHARE_CLASS_LEVEL;
            isModifiable = record.IsModifiable__c == true;
            for (String dependentField : splitFieldNames(record.DependentFields__c)) {
                dependentFields.add(new DescribedField(dependentField, stageFields));
            }
        }
    }

    public class Line {
        @AuraEnabled public Id id;
        @AuraEnabled public String developerName;
        @AuraEnabled public String team;
        @AuraEnabled public String stage;
        @AuraEnabled public String teamDeveloperName;
        @AuraEnabled public String stageDeveloperName;
        @AuraEnabled public String requirement;
        @AuraEnabled public Boolean isRequired;
        @AuraEnabled public Boolean isConditional;
        @AuraEnabled public String condition;
        @AuraEnabled public String conditionError;
        @AuraEnabled public String requiredCondition;
        @AuraEnabled public String requiredConditionError;
        @AuraEnabled public Boolean isActive;

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
            requiredConditionError = getRequiredConditionError(record.Requirement__c, record.RequiredCondition__c, isFund);
            isActive = record.IsActive__c;
        }
    }

    // US-20194 V1.6: a line to create (lineId empty) or edit, as filled in the editor; team and stage are DeveloperNames, objectName a PMTField__mdt.Object__c value
    public class LineRequest {
        public Id lineId;
        public String team;
        public String stage;
        public String objectName;
        public String fieldApiName;
        public Boolean isModifiable;
        public List<String> dependentFields;
        public String requirement;
        public String condition;
        public String requiredCondition;
        public Boolean isActive;
    }

    // The records a request reuses (null = created), the line it edits or would duplicate, and its errors
    private class LineContext {
        Boolean isFund;
        PMTTeam__mdt team;
        PMTStage__mdt stage;
        Schema.SObjectField stageField;
        List<String> dependentFields = new List<String>();
        PMTField__mdt field;
        PMTFieldRule__mdt rule;
        PMTFieldRuleLine__mdt line;
        Integer fieldLineCount = 0;
        Id conflictLineId;
        List<String> errors = new List<String>();
    }

    public class LinePreview {
        @AuraEnabled public String fieldDeveloperName;
        @AuraEnabled public Integer fieldLineCount;
        @AuraEnabled public Boolean fieldIsModifiable;
        @AuraEnabled public List<String> fieldDependentFields;
        @AuraEnabled public String ruleDeveloperName;
        @AuraEnabled public Id conflictLineId;
        @AuraEnabled public List<String> errors;

        private LinePreview(LineContext context) {
            fieldDeveloperName = context.field?.DeveloperName;
            fieldLineCount = context.fieldLineCount;
            fieldIsModifiable = context.field?.IsModifiable__c == true;
            fieldDependentFields = splitFieldNames(context.field?.DependentFields__c);
            ruleDeveloperName = context.rule?.DeveloperName;
            conflictLineId = context.conflictLineId;
            errors = context.errors;
        }
    }

    public class ConditionCheck {
        @AuraEnabled public String error;
        @AuraEnabled public List<String> projectFields = new List<String>();
        @AuraEnabled public List<String> shareClassFields = new List<String>();
    }
}
