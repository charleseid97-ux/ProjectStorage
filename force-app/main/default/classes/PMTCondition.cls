/** ──────────────────────────────────────
 * @description Condition of the PMT configuration (US-20194): PMTFieldRuleLine__mdt.Condition__c, PMTOwnerRule__mdt.Condition__c.
 *              A condition is a Salesforce formula returning true or false whose fields are prefixed with their object:
 *                  ProjectProduct__c.LegalForm__c (the project) or ProjectShareclass__c.HasPerfFees__c (the share class being evaluated).
 *                  Only direct fields of the two objects can be read: trigger records (Trigger.new) carry no parent relationship.
 *              Compiled once per transaction: the prefixes become a formula on ProjectShareclass__c (the project through ProjectProduct__r),
 *                  built with Formula.builder(), whose referenced fields tell what to query (queryProjects).
 *              Evaluated on an in-memory share class carrying the project: an empty share class for a project-level evaluation.
 * @author Charles EID
 * @testClass PMTConditionTest
 * @coverage 100%   [21-10-26]
 ────────────────────────────────────── */
public without sharing class PMTCondition {

    private static final String PROJECT_OBJECT = 'ProjectProduct__c';
    private static final String SHARE_CLASS_OBJECT = 'ProjectShareclass__c';
    private static final String PROJECT_RELATIONSHIP = 'ProjectProduct__r';
    private static final String SHARE_CLASS_RELATIONSHIP = 'ProjectShareclasses__r';

    private static Map<String, PMTCondition> conditionByText = new Map<String, PMTCondition>();

    public String text { get; private set; }
    public Set<String> projectFields { get; private set; }
    public Set<String> shareClassFields { get; private set; }
    private FormulaEval.FormulaInstance formulaInstance;

    // Compiled condition of a text, cached per transaction. Null for an empty text: the line or rule always applies.
    public static PMTCondition compile(String text) {
        if (String.isBlank(text)) return null;
        if (!conditionByText.containsKey(text)) conditionByText.put(text, new PMTCondition(text));
        return conditionByText.get(text);
    }

    private PMTCondition(String text) {
        this.text = text;
        String rewritten = text.replaceAll('(?i)\\b' + PROJECT_OBJECT + '\\.', PROJECT_RELATIONSHIP + '.').replaceAll('(?i)\\b' + SHARE_CLASS_OBJECT + '\\.', '');
        try {
            formulaInstance = Formula.builder()
                .withType(Schema.ProjectShareclass__c.SObjectType)
                .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
                .withFormula(rewritten)
                .build();
        }
        catch (Exception e) {
            throw new PMTConditionException('"' + text + '": ' + e.getMessage());
        }

        projectFields = new Set<String>();
        shareClassFields = new Set<String>();
        for (String reference : formulaInstance.getReferencedFields()) {
            String field = reference.startsWith(PROJECT_RELATIONSHIP + '.') ? reference.substringAfter('.') : reference;
            if (field.contains('.')) throw new PMTConditionException('"' + text + '": only direct fields of ' + PROJECT_OBJECT + ' and ' + SHARE_CLASS_OBJECT + ' can be read, not ' + reference);
            if (reference.startsWith(PROJECT_RELATIONSHIP + '.')) projectFields.add(field);
            else shareClassFields.add(field);
        }
    }

    // True when the condition reads a share class field: it is then evaluated once per share class.
    public Boolean readsShareClass() {
        return !shareClassFields.isEmpty();
    }

    // Result for a project (holding the project fields read) and a share class (holding the share class fields read), null for a project-level evaluation.
    public Boolean evaluate(ProjectProduct__c project, ProjectShareclass__c shareClass) {
        // Clone without Id: the master-detail of an existing share class cannot be reassigned, even in memory
        ProjectShareclass__c context = shareClass != null ? shareClass.clone(false, true, true, true) : new ProjectShareclass__c();
        context.putSObject(PROJECT_RELATIONSHIP, project);
        return formulaInstance.evaluate(context) == true;
    }

    // Projects with their Scope and the given fields, and their share classes with the given share class fields: one query whatever the number of conditions.
    public static List<ProjectProduct__c> queryProjects(Set<Id> projectIds, Set<String> projectFields, Set<String> shareClassFields) {
        String shareClassQuery = 'SELECT ' + String.join(selectList(new List<String>{ 'Id', PROJECT_OBJECT }, shareClassFields), ', ') + ' FROM ' + SHARE_CLASS_RELATIONSHIP;
        return Database.query('SELECT ' + String.join(selectList(new List<String>{ 'Id', 'Scope__c' }, projectFields), ', ') + ', (' + shareClassQuery + ')'
                              + ' FROM ' + PROJECT_OBJECT + ' WHERE Id IN :projectIds');
    }

    // Fields to select without duplicates (field names are case-insensitive).
    private static List<String> selectList(List<String> mandatoryFields, Set<String> fields) {
        Map<String, String> fieldByLowerName = new Map<String, String>();
        for (String field : mandatoryFields) fieldByLowerName.put(field.toLowerCase(), field);
        for (String field : fields) {
            if (!fieldByLowerName.containsKey(field.toLowerCase())) fieldByLowerName.put(field.toLowerCase(), field);
        }
        return fieldByLowerName.values();
    }

    public class PMTConditionException extends Exception {}
}