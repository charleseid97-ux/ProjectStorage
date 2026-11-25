/** ──────────────────────────────────────
 * @description Condition of the PMT configuration (US-20194): PMTFieldRuleLine__mdt.Condition__c, PMTOwnerRule__mdt.Condition__c.
 *              A condition is a Salesforce formula returning true or false whose fields are prefixed with their object:
 *                  ProjectProduct__c.LegalForm__c (the project) or ProjectShareclass__c.HasPerfFees__c (the share class being evaluated).
 *              US-20194 V1.8: like a formula field, a condition follows lookups, e.g. ProjectProduct__c.ParentProduct__r.Name or
 *                  ProjectProduct__c.RecordType.DeveloperName (up to MAX_RELATIONSHIP_HOPS, never a polymorphic lookup such as Owner:
 *                  the formula engine reads it as blank). PMTMatrix attaches the parent records before an evaluation (Trigger.new carries none).
 *              Compiled once per transaction: the prefixes become a formula on ProjectShareclass__c (the project through ProjectProduct__r),
 *                  built with Formula.builder(), whose referenced fields tell what to query (projectPaths, shareClassPaths) and which
 *                  fields of the project or share class change the result (projectFields, shareClassFields: a lookup for a path).
 *              Evaluated on an in-memory share class carrying the project: an empty share class for a project-level evaluation.
 * @author Charles EID
 * @lastModifiedBy Charles EID   [18-11-26]
 * @testClass PMTConditionTest
 * @coverage 100%   [18-11-26]
 ────────────────────────────────────── */
public without sharing class PMTCondition {

    private static final String PROJECT_OBJECT = 'ProjectProduct__c';
    private static final String SHARE_CLASS_OBJECT = 'ProjectShareclass__c';
    private static final String PROJECT_RELATIONSHIP = 'ProjectProduct__r';
    private static final String SHARE_CLASS_RELATIONSHIP = 'ProjectShareclasses__r';
    // US-20194 V1.8: lookups a path may follow from the project or the share class (SOQL reads 5 levels of parents, the share class adds one)
    public static final Integer MAX_RELATIONSHIP_HOPS = 4;

    private static Map<String, PMTCondition> conditionByText = new Map<String, PMTCondition>();
    private static Map<Schema.SObjectType, Map<String, Schema.SObjectField>> lookupByRelationshipByType = new Map<Schema.SObjectType, Map<String, Schema.SObjectField>>();

    public String text { get; private set; }
    // Fields of the project / share class whose change can change the result: the direct fields read and the lookup of each path
    public Set<String> projectFields { get; private set; }
    public Set<String> shareClassFields { get; private set; }
    // US-20194 V1.8: what the condition reads, as written (LegalForm__c, ParentProduct__r.Name): what a query selects
    public Set<String> projectPaths { get; private set; }
    public Set<String> shareClassPaths { get; private set; }
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
        projectPaths = new Set<String>();
        shareClassPaths = new Set<String>();
        for (String reference : formulaInstance.getReferencedFields()) {
            Boolean readsProject = reference.startsWith(PROJECT_RELATIONSHIP + '.');
            String path = readsProject ? reference.substringAfter('.') : reference;
            Schema.SObjectType objectType = readsProject ? Schema.ProjectProduct__c.SObjectType : Schema.ProjectShareclass__c.SObjectType;
            String field = path.contains('.') ? getFirstLookup(objectType, path, text).getDescribe().getName() : path;
            if (readsProject) {
                projectFields.add(field);
                projectPaths.add(path);
            }
            else {
                shareClassFields.add(field);
                shareClassPaths.add(path);
            }
        }
    }

    // US-20194 V1.8: lookup of the object followed first by a path (ParentProduct__r.Name -> ParentProduct__c, RecordType.DeveloperName -> RecordTypeId), once each hop of the path is checked: a lookup to a single object, at most MAX_RELATIONSHIP_HOPS
    private static Schema.SObjectField getFirstLookup(Schema.SObjectType objectType, String path, String text) {
        List<String> hops = path.split('\\.');
        hops.remove(hops.size() - 1);
        if (hops.size() > MAX_RELATIONSHIP_HOPS) throw new PMTConditionException('"' + text + '": ' + path + ' follows more than ' + MAX_RELATIONSHIP_HOPS + ' lookups');

        Schema.SObjectField firstLookup;
        Schema.SObjectType hopType = objectType;
        for (String hop : hops) {
            Schema.SObjectField lookup = getLookup(hopType, hop);
            List<Schema.SObjectType> targets = lookup?.getDescribe().getReferenceTo();
            if (hop.contains(':') || targets == null || targets.size() != 1) throw new PMTConditionException('"' + text + '": ' + path + ' follows a polymorphic lookup (' + hop + '), which a condition cannot read');
            if (firstLookup == null) firstLookup = lookup;
            hopType = targets[0];
        }
        return firstLookup;
    }

    // US-20194 V1.8: lookup field of a relationship of an object (ParentProduct__r -> ParentProduct__c), case-insensitive; null when the object has none
    public static Schema.SObjectField getLookup(Schema.SObjectType objectType, String relationshipName) {
        if (!lookupByRelationshipByType.containsKey(objectType)) {
            Map<String, Schema.SObjectField> lookupByRelationship = new Map<String, Schema.SObjectField>();
            for (Schema.SObjectField field : objectType.getDescribe().fields.getMap().values()) {
                String name = field.getDescribe().getRelationshipName();
                if (name != null) lookupByRelationship.put(name.toLowerCase(), field);
            }
            lookupByRelationshipByType.put(objectType, lookupByRelationship);
        }
        return lookupByRelationshipByType.get(objectType).get(relationshipName.toLowerCase());
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