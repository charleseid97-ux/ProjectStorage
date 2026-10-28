/** ──────────────────────────────────────
 * @description Tests of the PMT Matrix Explorer controller: the model read from the deployed PMT custom metadata (every stage, team,
 *                  owner rule, field and line, a sharing status per field, the sensitive fields, the editor choices), then the rules on
 *                  in-memory records: sharing status of a field by team scope and conditions, the errors of Condition__c and RequiredCondition__c,
 *                  the "Check condition" button and the generated DeveloperNames.
 *              US-20194 V1.6: the rule line editor on the deployed records: previewLine (reused or created PMTField and PMTFieldRule, duplicate
 *                  line, field locked but team and stage movable, missing fields, invalid conditions), saveLine (records deployed, a line moved
 *                  to a new rule, refusals) and the deployment event; the {FUND|SC}_{field}_{index} line names.
 * @author Charles EID
 * @lastModifiedBy Charles EID   [28-10-26]
 * @covers PMTMatrixExplorerController   99%   [28-10-26]
 ────────────────────────────────────── */
@isTest
private class PMTMatrixExplorerControllerTest {

    private static final String PROJECT_CONDITION = 'ISPICKVAL(ProjectProduct__c.LegalForm__c, \'FCP\')';
    private static final String SHARE_CLASS_CONDITION = 'ISPICKVAL(ProjectShareclass__c.HasPerfFees__c, \'True\')';
    private static final String FUND_OBJECT = 'Product__c';
    private static final String SHARE_CLASS_OBJECT = 'Share_Class__c';

    @isTest
    static void test_getModel() {

        Test.startTest();

        PMTMatrixExplorerController.Model model = PMTMatrixExplorerController.getModel();

        Test.stopTest();

        System.assertEquals(PMTStage__mdt.getAll().size(), model.stages.size(), 'Every stage is read');
        System.assertEquals(PMTTeam__mdt.getAll().size(), model.teams.size(), 'Every team is read');
        System.assertEquals(PMTOwnerRule__mdt.getAll().size(), model.ownerRules.size(), 'Every owner rule is read');
        System.assertEquals(PMTField__mdt.getAll().size(), model.fields.size(), 'Every field is read, with or without lines');

        Integer lineCount = 0;
        Integer sensitiveCount = 0;
        for (PMTMatrixExplorerController.Field field : model.fields) {
            System.assertNotEquals(null, field.sharingStatus, field.developerName + ': every field has a sharing status');
            lineCount += field.lines.size();
            if (field.isSensitive) sensitiveCount++;
            Boolean hasActiveLine = false;
            for (PMTMatrixExplorerController.Line line : field.lines) {
                if (line.isActive) hasActiveLine = true;
                System.assert(String.isNotBlank(line.teamDeveloperName) && String.isNotBlank(line.stageDeveloperName), line.developerName + ': the editor gets the DeveloperNames of its team and stage');
            }
            System.assertEquals(!hasActiveLine, field.sharingStatus == PMTMatrixExplorerController.UNUSED, field.developerName + ': only a field without active lines is unused');
        }
        Integer expectedSensitiveCount = 0;
        for (PMTField__mdt record : PMTField__mdt.getAll().values()) {
            if (record.IsSensitive__c) expectedSensitiveCount++;
        }
        System.assertEquals(PMTFieldRuleLine__mdt.getAll().size(), lineCount, 'Every line is read under its field');
        System.assertEquals(expectedSensitiveCount, sensitiveCount, 'IsSensitive__c is read on every field');

        // US-20194 V1.6: what the editor offers to an admin
        System.assert(model.canEdit, 'The running admin can customize the application, so can edit');
        System.assertEquals(2, model.levelOptions.size(), 'Fund and Share Class levels');
        System.assertEquals(3, model.requirementOptions.size(), 'Required, Optional and Conditional');
        System.assert(!model.fieldOptionsByLevel.get(FUND_OBJECT).isEmpty() && !model.fieldOptionsByLevel.get(SHARE_CLASS_OBJECT).isEmpty(), 'The custom fields of both stage objects can be picked');
        System.assertEquals(Schema.SObjectType.PMTFieldRuleLine__mdt.fields.Condition__c.getInlineHelpText(), model.helpTextByField.get('PMTFieldRuleLine__mdt.Condition__c'), 'The editor shows the inline help of the custom metadata fields');
    }

    @isTest
    static void test_rules() {
        // 1. Sharing status: teams of different scopes never apply together, teams whose lines all have a condition may exclude each other
        Map<String, PMTMatrixExplorerController.Team> teamByName = new Map<String, PMTMatrixExplorerController.Team>();
        for (PMTTeam__mdt record : new List<PMTTeam__mdt>{ new PMTTeam__mdt(MasterLabel = 'IS', Scope__c = 'IS'), new PMTTeam__mdt(MasterLabel = 'PS', Scope__c = 'PS'),
                                                           new PMTTeam__mdt(MasterLabel = 'Legal'), new PMTTeam__mdt(MasterLabel = 'OPS') }) {
            teamByName.put(record.MasterLabel, new PMTMatrixExplorerController.Team(record, null));
        }
        PMTMatrixExplorerController.Line isLine = buildLine('IS', 'Required', null, null);
        PMTMatrixExplorerController.Line psLine = buildLine('PS', 'Optional', null, null);
        PMTMatrixExplorerController.Line legalConditionalLine = buildLine('Legal', 'Required', PROJECT_CONDITION, null);
        PMTMatrixExplorerController.Line opsConditionalLine = buildLine('OPS', 'Required', 'NOT(' + PROJECT_CONDITION + ')', null);
        PMTMatrixExplorerController.Line opsLine = buildLine('OPS', 'Optional', null, null);
        System.assertEquals(PMTMatrixExplorerController.UNUSED, PMTMatrixExplorerController.getSharingStatus(new List<PMTMatrixExplorerController.Line>(), teamByName), 'No line: unused');
        System.assertEquals(PMTMatrixExplorerController.SINGLE, PMTMatrixExplorerController.getSharingStatus(new List<PMTMatrixExplorerController.Line>{ isLine }, teamByName), 'One team: single');
        System.assertEquals(PMTMatrixExplorerController.SCOPE_SPLIT, PMTMatrixExplorerController.getSharingStatus(new List<PMTMatrixExplorerController.Line>{ isLine, psLine }, teamByName), 'IS and PS never apply to the same project');
        System.assertEquals(PMTMatrixExplorerController.CONDITION_SPLIT, PMTMatrixExplorerController.getSharingStatus(new List<PMTMatrixExplorerController.Line>{ legalConditionalLine, opsConditionalLine }, teamByName), 'Every line has a condition: condition split');
        System.assertEquals(PMTMatrixExplorerController.SHARED, PMTMatrixExplorerController.getSharingStatus(new List<PMTMatrixExplorerController.Line>{ legalConditionalLine, opsLine }, teamByName), 'OPS always uses the field: shared');
        System.assertEquals(PMTMatrixExplorerController.SHARED, PMTMatrixExplorerController.getSharingStatus(new List<PMTMatrixExplorerController.Line>{ isLine, psLine, opsLine }, teamByName), 'The most constraining pair of teams wins');
        PMTMatrixExplorerController.Line inactiveOpsLine = buildLine('OPS', 'Optional', null, null);
        inactiveOpsLine.isActive = false;
        System.assertEquals(PMTMatrixExplorerController.SINGLE, PMTMatrixExplorerController.getSharingStatus(new List<PMTMatrixExplorerController.Line>{ legalConditionalLine, inactiveOpsLine }, teamByName), 'US-20194 V1.5: an inactive line is left out of the sharing status');
        System.assertEquals(PMTMatrixExplorerController.UNUSED, PMTMatrixExplorerController.getSharingStatus(new List<PMTMatrixExplorerController.Line>{ inactiveOpsLine }, teamByName), 'Only inactive lines: unused');

        // 2. Condition__c errors on a Fund line: compilation error, share class field read at project level
        System.assertEquals(null, legalConditionalLine.conditionError, 'A valid condition has no error');
        System.assertEquals(null, isLine.conditionError, 'An empty condition has no error');
        System.assertNotEquals(null, buildLine('OPS', 'Optional', 'NOT_A_FUNCTION(', null).conditionError, 'A condition that does not compile shows its error');
        System.assertEquals(PMTMatrix.PROJECT_ONLY_ERROR, buildLine('OPS', 'Optional', SHARE_CLASS_CONDITION, null).conditionError, 'A Fund line condition reads only ProjectProduct__c fields');

        // 3. RequiredCondition__c: set exactly on the Conditional lines, then checked like a condition
        PMTMatrixExplorerController.Line conditionalLine = buildLine('Legal', 'Conditional', null, PROJECT_CONDITION);
        System.assert(conditionalLine.isConditional && !conditionalLine.isRequired && conditionalLine.requiredConditionError == null, 'A Conditional line with a valid RequiredCondition__c has no error');
        System.assertEquals(PMTMatrix.MISSING_REQUIRED_CONDITION_ERROR, buildLine('Legal', 'Conditional', null, null).requiredConditionError, 'A Conditional line needs a RequiredCondition__c');
        System.assertEquals(PMTMatrix.IGNORED_REQUIRED_CONDITION_ERROR, buildLine('Legal', 'Required', null, PROJECT_CONDITION).requiredConditionError, 'RequiredCondition__c is ignored on a line that is not Conditional');
        System.assertEquals(PMTMatrix.PROJECT_ONLY_ERROR, buildLine('Legal', 'Conditional', null, SHARE_CLASS_CONDITION).requiredConditionError, 'A Fund line RequiredCondition__c reads only ProjectProduct__c fields');

        // 4. US-20194 V1.6: "Check condition" button: the fields read by a valid condition, or its error
        PMTMatrixExplorerController.ConditionCheck projectCheck = PMTMatrixExplorerController.checkCondition(PROJECT_CONDITION, FUND_OBJECT, false);
        PMTMatrixExplorerController.ConditionCheck shareClassCheck = PMTMatrixExplorerController.checkCondition(SHARE_CLASS_CONDITION, SHARE_CLASS_OBJECT, false);
        PMTMatrixExplorerController.ConditionCheck emptyCheck = PMTMatrixExplorerController.checkCondition('', FUND_OBJECT, false);
        System.assert(projectCheck.error == null && String.join(projectCheck.projectFields, ',').containsIgnoreCase('LegalForm__c') && projectCheck.shareClassFields.isEmpty(), 'A project condition reads ProjectProduct__c fields');
        System.assert(shareClassCheck.error == null && String.join(shareClassCheck.shareClassFields, ',').containsIgnoreCase('HasPerfFees__c'), 'A share class condition reads ProjectShareclass__c fields');
        System.assert(emptyCheck.error == null && emptyCheck.projectFields.isEmpty(), 'An empty condition always applies');
        System.assertEquals(PMTMatrix.PROJECT_ONLY_ERROR, PMTMatrixExplorerController.checkCondition(SHARE_CLASS_CONDITION, FUND_OBJECT, false).error, 'A Fund line condition reads only ProjectProduct__c fields');
        System.assertEquals(PMTMatrix.MISSING_REQUIRED_CONDITION_ERROR, PMTMatrixExplorerController.checkCondition(null, FUND_OBJECT, true).error, 'The Required when condition of a Conditional line cannot be empty');
        System.assertNotEquals(null, PMTMatrixExplorerController.checkCondition('NOT_A_FUNCTION(', FUND_OBJECT, false).error, 'A condition that does not compile shows its error');

        // 5. US-20194 V1.6: generated DeveloperNames: letters and digits only, 40 characters at most, a number when taken
        System.assertEquals('LegalFilingX2', PMTMatrixExplorerController.getUniqueName('Legal Filing_X', new Set<String>{ 'LEGALFILINGX' }), 'A taken name gets a number');
        System.assertEquals(40, PMTMatrixExplorerController.getUniqueName('A'.repeat(50), new Set<String>{ 'A'.repeat(40) }).length(), 'A long name stays within 40 characters, number included');

        // 6. US-20194 V1.6: a rule line is named after its field only, {FUND|SC}_{field}_{first free index}, its base cut to 37 characters
        System.assertEquals('SC_ISIN_2', PMTMatrixExplorerController.getLineName(false, 'ISIN', new Set<String>{ 'SC_ISIN_1' }), 'The next line of a field takes the next index');
        System.assertEquals('FUND_ISIN_1', PMTMatrixExplorerController.getLineName(true, 'ISIN', new Set<String>{ 'SC_ISIN_1' }), 'Fund and Share Class lines are numbered apart');
        System.assertEquals('FUND_' + 'A'.repeat(32) + '_99', PMTMatrixExplorerController.getLineName(true, 'A'.repeat(38), getLineNames('FUND_' + 'A'.repeat(32), 98)), 'A 38-character field still fits in 40 characters, up to _99');
        String cutName = PMTMatrixExplorerController.getLineName(true, 'A'.repeat(31) + '_B', new Set<String>());
        System.assert(!cutName.contains('__') && cutName.endsWith('_1'), 'A base cut on an underscore never gives a double underscore: ' + cutName);
    }

    @isTest
    static void test_previewLine() {
        PMTMatrixExplorerController.LineRequest editRequest = buildExistingLineRequest();
        PMTMatrixExplorerController.LineRequest duplicateRequest = copyRequest(editRequest);
        duplicateRequest.lineId = null;
        PMTMatrixExplorerController.LineRequest movedRequest = copyRequest(editRequest);
        for (String stage : PMTStage__mdt.getAll().keySet()) {
            if (stage != editRequest.stage) movedRequest.stage = stage;
        }
        PMTMatrixExplorerController.LineRequest invalidRequest = copyRequest(duplicateRequest);
        invalidRequest.fieldApiName = 'NotAPMTField__c';
        invalidRequest.dependentFields = new List<String>{ 'NotADependentField__c' };
        invalidRequest.condition = 'NOT_A_FUNCTION(';
        invalidRequest.requirement = 'Conditional';
        invalidRequest.requiredCondition = null;
        PMTMatrixExplorerController.LineRequest unknownTeamRequest = copyRequest(duplicateRequest);
        unknownTeamRequest.team = 'NotAPMTTeam';
        PMTMatrixExplorerController.LineRequest fieldChangedRequest = copyRequest(editRequest);
        fieldChangedRequest.fieldApiName = 'NotAPMTField__c';

        Test.startTest();

        PMTMatrixExplorerController.LinePreview editPreview = PMTMatrixExplorerController.previewLine(JSON.serialize(editRequest));
        PMTMatrixExplorerController.LinePreview duplicatePreview = PMTMatrixExplorerController.previewLine(JSON.serialize(duplicateRequest));
        PMTMatrixExplorerController.LinePreview movedPreview = PMTMatrixExplorerController.previewLine(JSON.serialize(movedRequest));
        PMTMatrixExplorerController.LinePreview invalidPreview = PMTMatrixExplorerController.previewLine(JSON.serialize(invalidRequest));
        PMTMatrixExplorerController.LinePreview unknownTeamPreview = PMTMatrixExplorerController.previewLine(JSON.serialize(unknownTeamRequest));
        PMTMatrixExplorerController.LinePreview incompletePreview = PMTMatrixExplorerController.previewLine(JSON.serialize(new PMTMatrixExplorerController.LineRequest()));
        PMTMatrixExplorerController.LinePreview fieldChangedPreview = PMTMatrixExplorerController.previewLine(JSON.serialize(fieldChangedRequest));

        Test.stopTest();

        System.assert(editPreview.errors.isEmpty(), 'An existing line saved unchanged is valid: ' + editPreview.errors);
        System.assert(editPreview.fieldDeveloperName != null && editPreview.ruleDeveloperName != null && editPreview.fieldLineCount >= 1, 'Rules 1 and 2: the line reuses its PMTField and its PMTFieldRule');
        System.assertEquals(null, editPreview.conflictLineId, 'A line does not duplicate itself');
        System.assertEquals(editRequest.lineId, duplicatePreview.conflictLineId, 'Rule 3: the same team, stage and field as an existing line is a duplicate');
        System.assert(duplicatePreview.errors.contains(PMTMatrixExplorerController.DUPLICATE_LINE_ERROR), 'A duplicate cannot be saved');
        System.assert(!movedPreview.errors.contains(PMTMatrixExplorerController.IDENTITY_LOCKED_ERROR), 'An existing line can move to another stage');
        System.assert(fieldChangedPreview.errors.contains(PMTMatrixExplorerController.IDENTITY_LOCKED_ERROR), 'An existing line keeps its object and field');
        System.assertEquals(null, invalidPreview.fieldDeveloperName, 'A field missing from the dictionary would be created');
        String invalidErrors = String.join(invalidPreview.errors, '\n');
        System.assert(invalidErrors.contains('NotAPMTField__c') && invalidErrors.contains('NotADependentField__c'), 'The field and the dependent fields must exist on the stage object: ' + invalidErrors);
        System.assert(invalidErrors.contains('Condition: ') && invalidErrors.contains('Required condition: ' + PMTMatrix.MISSING_REQUIRED_CONDITION_ERROR), 'Both conditions are checked: ' + invalidErrors);
        System.assertEquals(new List<String>{ PMTMatrixExplorerController.INVALID_VALUE_ERROR }, unknownTeamPreview.errors, 'The team must be a PMTTeam record');
        System.assertEquals(new List<String>{ PMTMatrixExplorerController.INCOMPLETE_LINE_ERROR }, incompletePreview.errors, 'Team, stage, level, field and requirement are required');
    }

    @isTest
    static void test_saveLine() {
        // New line on a Fund field missing from the dictionary, for a team and stage without a rule: the PMTField, the PMTFieldRule and the line are created
        List<String> fieldsOutsideDictionary = getFieldsOutsideDictionary();
        PMTMatrixExplorerController.LineRequest newRequest = new PMTMatrixExplorerController.LineRequest();
        newRequest.objectName = FUND_OBJECT;
        newRequest.fieldApiName = fieldsOutsideDictionary[0];
        newRequest.isSensitive = true;
        newRequest.dependentFields = new List<String>{ fieldsOutsideDictionary[1] };
        newRequest.requirement = 'Conditional';
        newRequest.requiredCondition = PROJECT_CONDITION;
        Set<String> ruleKeys = new Set<String>();
        for (PMTFieldRule__mdt rule : [SELECT Team__r.DeveloperName, Stage__r.DeveloperName FROM PMTFieldRule__mdt]) {
            ruleKeys.add(rule.Team__r.DeveloperName + '.' + rule.Stage__r.DeveloperName);
        }
        for (String team : PMTTeam__mdt.getAll().keySet()) {
            for (String stage : PMTStage__mdt.getAll().keySet()) {
                if (!ruleKeys.contains(team + '.' + stage)) {
                    newRequest.team = team;
                    newRequest.stage = stage;
                }
            }
        }
        // Existing line moved to that team and stage and switched off: the new PMTFieldRule is deployed with the line, which keeps its DeveloperName
        PMTMatrixExplorerController.LineRequest editRequest = buildExistingLineRequest();
        PMTMatrixExplorerController.LineRequest duplicateRequest = copyRequest(editRequest);
        duplicateRequest.lineId = null;
        editRequest.team = newRequest.team;
        editRequest.stage = newRequest.stage;
        editRequest.isActive = false;
        Id editedLineId = editRequest.lineId;
        PMTFieldRuleLine__mdt editedRecord = [SELECT DeveloperName FROM PMTFieldRuleLine__mdt WHERE Id = :editedLineId];
        Profile minimumAccess = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String username = 'pmtexplorer' + System.currentTimeMillis() + '@pmtexplorer.test';
        User minimumAccessUser = new User(Alias = 'pmtexp', Email = username, Username = username, LastName = 'PMT Explorer', ProfileId = minimumAccess.Id,
                                          EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', TimeZoneSidKey = 'Europe/Paris');
        insert minimumAccessUser;

        Test.startTest();

        PMTMatrixExplorerController.saveLine(JSON.serialize(newRequest));
        List<Metadata.Metadata> newRecords = PMTMatrixExplorerController.lastContainer.getMetadata();
        PMTMatrixExplorerController.saveLine(JSON.serialize(editRequest));
        List<Metadata.Metadata> editRecords = PMTMatrixExplorerController.lastContainer.getMetadata();
        String duplicateMessage = getSaveError(duplicateRequest);
        String noAccessMessage;
        System.runAs(minimumAccessUser) {
            noAccessMessage = getSaveError(newRequest);
        }

        Metadata.DeployResult success = new Metadata.DeployResult();
        success.id = '0Af000000000001AAA';
        success.status = Metadata.DeployStatus.Succeeded;
        new PMTMatrixExplorerController.DeployCallback().handleResult(success, null);
        PMTConfigurationDeploy__e successEvent = PMTMatrixExplorerController.lastDeployEvent;
        Metadata.DeployMessage componentFailure = new Metadata.DeployMessage();
        componentFailure.fullName = 'PMTFieldRuleLine.Test';
        componentFailure.problem = 'Invalid value';
        Metadata.DeployResult failure = new Metadata.DeployResult();
        failure.id = '0Af000000000002AAA';
        failure.status = Metadata.DeployStatus.Failed;
        failure.errorMessage = 'Deployment failed';
        failure.details = new Metadata.DeployDetails();
        failure.details.componentFailures = new List<Metadata.DeployMessage>{ componentFailure };
        new PMTMatrixExplorerController.DeployCallback().handleResult(failure, null);
        PMTConfigurationDeploy__e failureEvent = PMTMatrixExplorerController.lastDeployEvent;

        Test.stopTest();

        System.assertEquals(3, newRecords.size(), 'A new field and a new rule are deployed with the line');
        Metadata.CustomMetadata newField = (Metadata.CustomMetadata) newRecords[0];
        Metadata.CustomMetadata newRule = (Metadata.CustomMetadata) newRecords[1];
        Metadata.CustomMetadata newLine = (Metadata.CustomMetadata) newRecords[2];
        String fieldDeveloperName = newField.fullName.substringAfter('.');
        String ruleDeveloperName = newRule.fullName.substringAfter('.');
        System.assert(newField.fullName.startsWith('PMTField.Fund') && getValue(newField, 'IsSensitive__c') == true, 'The PMTField follows the Fund naming and keeps its values: ' + newField.fullName);
        System.assertEquals(fieldsOutsideDictionary[1], getValue(newField, 'DependentFields__c'), 'The dependent fields are saved on the PMTField');
        System.assertEquals(newRequest.team, getValue(newRule, 'Team__c'), 'The PMTFieldRule points to the chosen team');
        System.assertEquals('PMTFieldRuleLine.' + ('FUND_' + newRequest.fieldApiName.removeEndIgnoreCase('__c')).left(37).removeEnd('_') + '_1', newLine.fullName, 'The line is named after its field only');
        System.assert(getValue(newLine, 'FieldRule__c') == ruleDeveloperName && getValue(newLine, 'Field__c') == fieldDeveloperName, 'The line points to the records deployed with it');
        System.assert(getValue(newLine, 'RequiredCondition__c') == PROJECT_CONDITION && getValue(newLine, 'IsActive__c') == true, 'The line values are sent in full');

        System.assertEquals(2, editRecords.size(), 'A line moved to a team and stage without a rule is deployed with the new rule, not with its unchanged field');
        Metadata.CustomMetadata movedRule = (Metadata.CustomMetadata) editRecords[0];
        Metadata.CustomMetadata editedLine = (Metadata.CustomMetadata) editRecords[1];
        System.assertEquals('PMTFieldRuleLine.' + editedRecord.DeveloperName, editedLine.fullName, 'A moved line keeps its record and DeveloperName');
        System.assertEquals(movedRule.fullName.substringAfter('.'), getValue(editedLine, 'FieldRule__c'), 'A moved line points to its new rule');
        System.assert(editedLine.label.startsWith(PMTTeam__mdt.getInstance(newRequest.team).MasterLabel + ' - ') && getValue(editedLine, 'IsActive__c') == false, 'The label follows the new team, and the line can be switched off: ' + editedLine.label);
        System.assert(duplicateMessage.contains(PMTMatrixExplorerController.DUPLICATE_LINE_ERROR), 'A duplicate is refused before deploying');
        System.assertEquals(PMTMatrixExplorerController.NO_EDIT_ACCESS_ERROR, noAccessMessage, 'Only a user who can customize the application saves');

        System.assert(successEvent.IsSuccess__c && successEvent.JobId__c == '0Af000000000001AAA' && String.isBlank(successEvent.Message__c), 'A successful deployment is published as a success');
        System.assert(!failureEvent.IsSuccess__c && failureEvent.Message__c.contains('PMTFieldRuleLine.Test: Invalid value') && failureEvent.Message__c.contains('Deployment failed'), 'A failed deployment is published with its errors');
    }

    // Fund line of a team at the Proposal stage, from an in-memory PMTFieldRuleLine__mdt record
    private static PMTMatrixExplorerController.Line buildLine(String team, String requirement, String condition, String requiredCondition) {
        PMTFieldRuleLine__mdt record = new PMTFieldRuleLine__mdt(DeveloperName = team + requirement, Requirement__c = requirement, Condition__c = condition, RequiredCondition__c = requiredCondition, IsActive__c = true);
        return new PMTMatrixExplorerController.Line(record, team, 'Proposal', true);
    }

    // Request editing an existing line, as the editor sends it: the first line whose field is on its stage object and has no dependent fields
    private static PMTMatrixExplorerController.LineRequest buildExistingLineRequest() {
        Map<String, PMTFieldRule__mdt> ruleByDeveloperName = new Map<String, PMTFieldRule__mdt>();
        for (PMTFieldRule__mdt rule : [SELECT DeveloperName, Team__r.DeveloperName, Stage__r.DeveloperName FROM PMTFieldRule__mdt]) {
            ruleByDeveloperName.put(rule.DeveloperName, rule);
        }
        for (PMTFieldRuleLine__mdt line : [SELECT Id, FieldRule__r.DeveloperName, Field__r.Object__c, Field__r.FieldApiName__c, Field__r.IsSensitive__c, Field__r.DependentFields__c,
                                                  Requirement__c, Condition__c, RequiredCondition__c, IsActive__c
                                           FROM PMTFieldRuleLine__mdt
                                           ORDER BY DeveloperName]) {
            Boolean isFund = line.Field__r.Object__c == FUND_OBJECT;
            Map<String, Schema.SObjectField> stageFields = (isFund ? Schema.SObjectType.ProjectProductChild__c : Schema.SObjectType.ProjectShareclassChild__c).fields.getMap();
            if (!stageFields.containsKey(line.Field__r.FieldApiName__c) || String.isNotBlank(line.Field__r.DependentFields__c)) continue;
            PMTFieldRule__mdt rule = ruleByDeveloperName.get(line.FieldRule__r.DeveloperName);
            PMTMatrixExplorerController.LineRequest request = new PMTMatrixExplorerController.LineRequest();
            request.lineId = line.Id;
            request.team = rule.Team__r.DeveloperName;
            request.stage = rule.Stage__r.DeveloperName;
            request.objectName = line.Field__r.Object__c;
            request.fieldApiName = line.Field__r.FieldApiName__c;
            request.isSensitive = line.Field__r.IsSensitive__c;
            request.dependentFields = new List<String>();
            request.requirement = line.Requirement__c;
            request.condition = line.Condition__c;
            request.requiredCondition = line.RequiredCondition__c;
            request.isActive = line.IsActive__c;
            return request;
        }
        return null;
    }

    // Custom fields of the Fund stage object that no PMTField uses yet (the first one gets a new line, the second one is its dependent field)
    private static List<String> getFieldsOutsideDictionary() {
        Set<String> dictionaryFields = new Set<String>();
        for (PMTField__mdt field : PMTField__mdt.getAll().values()) {
            if (field.Object__c == FUND_OBJECT) dictionaryFields.add(field.FieldApiName__c.toLowerCase());
        }
        List<String> fields = new List<String>();
        for (Schema.SObjectField stageField : Schema.SObjectType.ProjectProductChild__c.fields.getMap().values()) {
            Schema.DescribeFieldResult describedField = stageField.getDescribe();
            if (describedField.isCustom() && !dictionaryFields.contains(describedField.getName().toLowerCase())) fields.add(describedField.getName());
        }
        return fields;
    }

    // DeveloperNames base_1 to base_{count}, all taken
    private static Set<String> getLineNames(String base, Integer count) {
        Set<String> names = new Set<String>();
        for (Integer index = 1; index <= count; index++) names.add(base + '_' + index);
        return names;
    }

    private static PMTMatrixExplorerController.LineRequest copyRequest(PMTMatrixExplorerController.LineRequest request) {
        return (PMTMatrixExplorerController.LineRequest) JSON.deserialize(JSON.serialize(request), PMTMatrixExplorerController.LineRequest.class);
    }

    private static String getSaveError(PMTMatrixExplorerController.LineRequest request) {
        try {
            PMTMatrixExplorerController.saveLine(JSON.serialize(request));
            return null;
        }
        catch (AuraHandledException e) {
            return e.getMessage();
        }
    }

    private static Object getValue(Metadata.CustomMetadata record, String field) {
        for (Metadata.CustomMetadataValue value : record.values) {
            if (value.field == field) return value.value;
        }
        return null;
    }
}
