/** ──────────────────────────────────────
 * @description Formula Evaluator Service (US-ApexFormulaEvalEnhancement): single entry point to Apex Formula Eval (Formula.builder()) for the modules
 *                  evaluating admin-written formulas (PMT conditions, Custom Email Recipient conditions, Disclaimer Logical Rules...).
 *              A Context says on which object a formula is compiled (the host) and which objects it reads, each written as a prefix:
 *                  no prefix declared: the fields are written on the host itself (Agreement__r.Owner.Email);
 *                  withPrefix('Product__c', 'Product__r'): Product__c.LegalForm__c is read through the Product__r lookup of the host;
 *                  withPrefix('ProjectShareclass__c', null): the prefix is the host itself.
 *              Like a formula field, a formula follows lookups (Product__c.ParentProduct__r.Name): at most maxRelationshipHops per path (default 4, at most 5 = the
 *                  parent levels SOQL reads), never through a polymorphic lookup (Owner: the formula engine reads it as blank, a silently wrong result). Both rejected at compile time.
 *              compile() checks a formula once per transaction (cache) and tells, per prefix, what it reads (getPaths), what to query (getQueryFields) and
 *                  which fields change its result (getTriggerFields: the direct fields and the first lookup of each path).
 *              evaluate*() never query: the records must carry the fields read and their parents. Query them with queryRecords(getQueryFields(...)), or attach
 *                  the parents of Trigger.new / in-memory records with withParents() (one query per relationship, none when the parents are already there).
 *              Bulk: evaluateAll / evaluateAny / evaluateEvery evaluate one formula on many records (one host reused, any / every stop at the first answer).
 *                  SOQL stays constant whatever the number of records and formulas, only CPU grows.
 * @author Charles EID
 * @testClass FormulaEvaluatorServiceTest
 * @coverage 100%   [19-11-26]
 ────────────────────────────────────── */
public inherited sharing class FormulaEvaluatorService {

    public static final Integer DEFAULT_MAX_RELATIONSHIP_HOPS = 4;
    public static final Integer MAX_RELATIONSHIP_HOPS = 5; // SOQL reads at most 5 levels of parents from the queried object
    private static final String NO_PREFIX = ''; // Key of the records of a context without prefix (fields written on the host)

    private static Map<String, FormulaEvaluatorService> formulaByKey = new Map<String, FormulaEvaluatorService>();
    private static Map<Schema.SObjectType, Map<String, Schema.SObjectField>> lookupByRelationshipByType = new Map<Schema.SObjectType, Map<String, Schema.SObjectField>>();
    // Parents loaded by withParents(): relationship + fields read + Id => parent (null when not found)
    private static Map<String, SObject> parentByKey = new Map<String, SObject>();
    @TestVisible
    private static Integer evaluationCount = 0;

    public class FormulaEvaluatorException extends Exception {}

    /** ──────────────────────────────────────
     * Where a formula is compiled and what it reads: host object, prefixes, return type, lookups a path may follow.
     ────────────────────────────────────── */
    public class Context {
        public Schema.SObjectType hostType { get; private set; }
        public FormulaEval.FormulaReturnType returnType { get; private set; }
        public Integer maxRelationshipHops { get; private set; }
        // Lower-case prefix => prefix (object API name), relationship on the host (blank: the host itself), object read
        private Map<String, String> prefixByKey = new Map<String, String>();
        private Map<String, String> relationshipByKey = new Map<String, String>();
        private Map<String, Schema.SObjectType> typeByKey = new Map<String, Schema.SObjectType>();

        public Context(Schema.SObjectType hostType) {
            if (hostType == null) throw new FormulaEvaluatorException('A formula context needs a host object.');
            this.hostType = hostType;
            this.returnType = FormulaEval.FormulaReturnType.BOOLEAN;
            this.maxRelationshipHops = DEFAULT_MAX_RELATIONSHIP_HOPS;
        }

        // Fields of objectName are written "objectName.Field" and read through relationshipOnHost (blank: objectName is the host itself)
        public Context withPrefix(String objectName, String relationshipOnHost) {
            Schema.SObjectType objectType = getObjectType(objectName);
            String prefix = String.valueOf(objectType);
            String key = prefix.toLowerCase();
            if (typeByKey.containsKey(key)) throw new FormulaEvaluatorException(prefix + ' is declared twice as a prefix.');

            String relationship = '';
            if (String.isBlank(relationshipOnHost)) {
                if (objectType != hostType) throw new FormulaEvaluatorException(prefix + ' without a relationship must be the host (' + hostType + ').');
            }
            else {
                Schema.SObjectField lookup = getLookup(hostType, relationshipOnHost.trim());
                List<Schema.SObjectType> targets = lookup?.getDescribe().getReferenceTo();
                if (targets == null || targets.size() != 1 || targets[0] != objectType) throw new FormulaEvaluatorException(hostType + '.' + relationshipOnHost + ' is not a lookup to ' + prefix + ' only.');
                relationship = lookup.getDescribe().getRelationshipName();
            }
            prefixByKey.put(key, prefix);
            relationshipByKey.put(key, relationship);
            typeByKey.put(key, objectType);
            return this;
        }

        public Context withReturnType(FormulaEval.FormulaReturnType returnType) {
            if (returnType == null) throw new FormulaEvaluatorException('A formula context needs a return type.');
            this.returnType = returnType;
            return this;
        }

        public Context withMaxRelationshipHops(Integer maxRelationshipHops) {
            if (maxRelationshipHops == null || maxRelationshipHops < 1 || maxRelationshipHops > MAX_RELATIONSHIP_HOPS) throw new FormulaEvaluatorException('The lookups a path may follow must be between 1 and ' + MAX_RELATIONSHIP_HOPS + ' (SOQL parent levels).');
            this.maxRelationshipHops = maxRelationshipHops;
            return this;
        }

        private String getKey() {
            List<String> prefixes = new List<String>();
            for (String key : relationshipByKey.keySet()) prefixes.add(key + '=' + relationshipByKey.get(key));
            prefixes.sort();
            return hostType + '|' + returnType + '|' + maxRelationshipHops + '|' + String.join(prefixes, ',');
        }
    }

    public String text { get; private set; }
    private Schema.SObjectType hostType;
    private FormulaEval.FormulaReturnType returnType;
    private Integer maxRelationshipHops;
    private Map<String, String> prefixByKey;
    private Map<String, String> relationshipByKey;
    private Map<String, Schema.SObjectType> typeByKey;
    // Prefix that is the host itself (NO_PREFIX for a context without prefix), null when every prefix is read through a relationship
    private String hostPrefixKey;
    // Prefix of a context reading one object (evaluate(SObject)), null when it reads several
    private String singleKey;
    // Prefixes read through a relationship of the host, and the keys of the prefixes as callers write them
    private List<String> relationKeys = new List<String>();
    private Map<String, String> keyByPrefix = new Map<String, String>();
    private FormulaEval.FormulaInstance instance;
    private Map<String, Set<String>> pathsByKey = new Map<String, Set<String>>();
    private Map<String, Set<String>> triggerFieldsByKey = new Map<String, Set<String>>();
    // Empty host reused by the evaluations (its relationships are replaced each time)
    private SObject sharedHost;

    // Compiled formula of a text in a context, cached per transaction. Null for a blank text. Throws a FormulaEvaluatorException naming the text when invalid.
    public static FormulaEvaluatorService compile(Context context, String text) {
        if (String.isBlank(text)) return null;
        if (context == null) throw new FormulaEvaluatorException('"' + text + '": no formula context.');
        String key = context.getKey() + '|' + text;
        if (!formulaByKey.containsKey(key)) formulaByKey.put(key, new FormulaEvaluatorService(context, text));
        return formulaByKey.get(key);
    }

    private FormulaEvaluatorService(Context context, String text) {
        this.text = text;
        hostType = context.hostType;
        returnType = context.returnType;
        maxRelationshipHops = context.maxRelationshipHops;
        prefixByKey = context.prefixByKey.clone();
        relationshipByKey = context.relationshipByKey.clone();
        typeByKey = context.typeByKey.clone();
        if (relationshipByKey.isEmpty()) {
            prefixByKey.put(NO_PREFIX, String.valueOf(hostType));
            relationshipByKey.put(NO_PREFIX, '');
            typeByKey.put(NO_PREFIX, hostType);
        }
        for (String key : relationshipByKey.keySet()) {
            if (relationshipByKey.get(key) == '') hostPrefixKey = key;
            else relationKeys.add(key);
            pathsByKey.put(key, new Set<String>());
            triggerFieldsByKey.put(key, new Set<String>());
        }
        if (relationshipByKey.size() == 1) singleKey = new List<String>(relationshipByKey.keySet())[0];

        try {
            instance = Formula.builder().withType(hostType).withReturnType(returnType).withFormula(rewritePrefixes(text)).build();
        }
        catch (Exception e) {
            throw new FormulaEvaluatorException('"' + text + '": ' + e.getMessage(), e);
        }

        for (String reference : instance.getReferencedFields()) {
            String key = getPrefixKey(reference);
            String path = key == hostPrefixKey ? reference : reference.substringAfter('.');
            pathsByKey.get(key).add(path);
            triggerFieldsByKey.get(key).add(path.contains('.') ? getFirstLookup(typeByKey.get(key), path).getDescribe().getName() : path);
        }
    }

    // The prefixes become relationships of the host (or disappear for the host itself), outside string literals and comments
    private String rewritePrefixes(String formula) {
        String result = '';
        Integer codeStart = 0;
        Integer i = 0;
        Integer length = formula.length();
        while (i < length) {
            Integer character = formula.charAt(i);
            Integer literalEnd = -1;
            if (character == 34 || character == 39) {
                // "..." or '...', \ escapes the next character
                literalEnd = i + 1;
                while (literalEnd < length && formula.charAt(literalEnd) != character) literalEnd += formula.charAt(literalEnd) == 92 ? 2 : 1;
                literalEnd = Math.min(literalEnd + 1, length);
            }
            else if (character == 47 && i + 1 < length && formula.charAt(i + 1) == 42) {
                literalEnd = formula.indexOf('*/', i + 2);
                literalEnd = literalEnd < 0 ? length : literalEnd + 2;
            }
            if (literalEnd < 0) {
                i++;
                continue;
            }
            result += rewriteCode(formula.substring(codeStart, i)) + formula.substring(i, literalEnd);
            i = literalEnd;
            codeStart = literalEnd;
        }
        return result + rewriteCode(formula.substring(codeStart));
    }

    // A prefix is rewritten only where it starts a reference (not after a letter, a digit, _ or .)
    private String rewriteCode(String code) {
        for (String key : relationshipByKey.keySet()) {
            if (key == NO_PREFIX) continue;
            String relationship = relationshipByKey.get(key);
            code = code.replaceAll('(?i)(?<![\\w.])' + Pattern.quote(prefixByKey.get(key)) + '\\.', relationship == '' ? '' : relationship + '.');
        }
        return code;
    }

    // Prefix of a referenced field: the relationship it starts with, otherwise the host prefix; a context with no host prefix requires one
    private String getPrefixKey(String reference) {
        for (String key : relationshipByKey.keySet()) {
            String relationship = relationshipByKey.get(key);
            if (relationship != '' && reference.startsWithIgnoreCase(relationship + '.')) return key;
        }
        if (hostPrefixKey != null) return hostPrefixKey;
        String example = prefixByKey.values()[0] + '.Name';
        throw new FormulaEvaluatorException('"' + text + '": prefix ' + reference + ' with its object, one of ' + String.join(prefixByKey.values(), ', ') + ' (e.g. ' + example + ').');
    }

    // Lookup of the object followed first by a path (ParentProduct__r.Name -> ParentProduct__c), once each hop is checked: a lookup to a single object, at most maxRelationshipHops
    private Schema.SObjectField getFirstLookup(Schema.SObjectType objectType, String path) {
        List<String> hops = path.split('\\.');
        hops.remove(hops.size() - 1);
        if (hops.size() > maxRelationshipHops) throw new FormulaEvaluatorException('"' + text + '": ' + path + ' follows ' + hops.size() + ' lookups, more than the ' + maxRelationshipHops + ' allowed.');

        Schema.SObjectField firstLookup;
        Schema.SObjectType hopType = objectType;
        for (String hop : hops) {
            Schema.SObjectField lookup = hop.contains(':') ? null : getLookup(hopType, hop);
            List<Schema.SObjectType> targets = lookup?.getDescribe().getReferenceTo();
            if (targets == null || targets.size() != 1) throw new FormulaEvaluatorException('"' + text + '": ' + path + ' follows ' + hop + ', a polymorphic lookup (or not a lookup) that a formula cannot read.');
            if (firstLookup == null) firstLookup = lookup;
            hopType = targets[0];
        }
        return firstLookup;
    }

    // ───── What the formula reads ─────

    public FormulaEval.FormulaReturnType getReturnType() {
        return returnType;
    }

    // Fields referenced as the formula engine reads them on the host (Product__r.LegalForm__c)
    public Set<String> getReferencedFields() {
        return instance.getReferencedFields();
    }

    // What the formula reads on the object of a prefix, as written after it (LegalForm__c, ParentProduct__r.Name). Prefix null for a context without prefix.
    public Set<String> getPaths(String prefix) {
        return new Set<String>(pathsByKey.get(toKey(prefix)));
    }

    // Fields of the object of a prefix whose change can change the result: the direct fields and the lookup of each path (ParentProduct__c)
    public Set<String> getTriggerFields(String prefix) {
        return new Set<String>(triggerFieldsByKey.get(toKey(prefix)));
    }

    // What a query of the object of a prefix selects: the paths, their lookups and the Id of each parent (to tell whether an attached parent is still the right one)
    public Set<String> getQueryFields(String prefix) {
        String key = toKey(prefix);
        Set<String> fields = new Set<String>(pathsByKey.get(key));
        fields.addAll(triggerFieldsByKey.get(key));
        for (String path : pathsByKey.get(key)) {
            if (path.contains('.')) fields.add(path.substringBefore('.') + '.Id');
        }
        return fields;
    }

    // True when the formula reads a field of the object of a prefix
    public Boolean reads(String prefix) {
        return !pathsByKey.get(toKey(prefix)).isEmpty();
    }

    // Union of the query fields of several formulas for a prefix: one query whatever the number of formulas (formulas without that prefix are ignored)
    public static Set<String> getQueryFields(List<FormulaEvaluatorService> formulas, String prefix) {
        Set<String> fields = new Set<String>();
        for (FormulaEvaluatorService formula : formulas) {
            if (formula != null && formula.findKey(prefix) != null) fields.addAll(formula.getQueryFields(prefix));
        }
        return fields;
    }

    private String findKey(String prefix) {
        String key = prefix == null ? NO_PREFIX : prefix.trim().toLowerCase();
        if (!pathsByKey.containsKey(key) && pathsByKey.containsKey(NO_PREFIX) && key == String.valueOf(hostType).toLowerCase()) key = NO_PREFIX;
        return pathsByKey.containsKey(key) ? key : null;
    }

    private String toKey(String prefix) {
        String key = findKey(prefix);
        if (key == null) throw new FormulaEvaluatorException('"' + text + '": ' + prefix + ' is not one of its prefixes (' + String.join(prefixByKey.values(), ', ') + ').');
        return key;
    }

    // ───── Evaluation ─────

    // Result on one record: a context without prefix or with a single prefix
    public Object evaluate(SObject record) {
        return evaluateHost(buildHost(record));
    }

    // Result on the records of the prefixes (prefix => record, case-insensitive); a missing prefix reads blank fields
    public Object evaluate(Map<String, SObject> recordByPrefix) {
        return evaluateHost(buildHost(toRecordByKey(recordByPrefix)));
    }

    // True only when the formula returns true (blank = false)
    public Boolean evaluateBoolean(SObject record) {
        checkBoolean();
        return evaluate(record) == true;
    }

    public Boolean evaluateBoolean(Map<String, SObject> recordByPrefix) {
        checkBoolean();
        return evaluate(recordByPrefix) == true;
    }

    // Results on many records, in their order
    public List<Object> evaluateAll(List<SObject> records) {
        List<Object> results = new List<Object>();
        for (SObject record : records) results.add(evaluate(record));
        return results;
    }

    public List<Object> evaluateAll(List<Map<String, SObject>> recordsByPrefix) {
        List<Object> results = new List<Object>();
        for (Map<String, SObject> recordByPrefix : recordsByPrefix) results.add(evaluate(recordByPrefix));
        return results;
    }

    // True when the formula is true for at least one record (stops at the first one); false without records
    public Boolean evaluateAny(List<SObject> records) {
        checkBoolean();
        for (SObject record : records ?? new List<SObject>()) {
            if (evaluate(record) == true) return true;
        }
        return false;
    }

    // True when the formula is true for every record (stops at the first false); false without records: a condition never passes on nothing
    public Boolean evaluateEvery(List<SObject> records) {
        checkBoolean();
        if (records == null || records.isEmpty()) return false;
        for (SObject record : records) {
            if (evaluate(record) != true) return false;
        }
        return true;
    }

    private void checkBoolean() {
        if (returnType != FormulaEval.FormulaReturnType.BOOLEAN) throw new FormulaEvaluatorException('"' + text + '" returns a ' + returnType + ', not a BOOLEAN.');
    }

    // Formula Eval returns a DATE formula as a Datetime at midnight GMT: given back as a Date, like every other type in its own Apex type
    private Object evaluateHost(SObject host) {
        evaluationCount++;
        Object result = instance.evaluate(host);
        return returnType == FormulaEval.FormulaReturnType.DATE && result != null ? (Object) ((Datetime) result).dateGmt() : result;
    }

    // Host of one record: the record itself when it is the host, otherwise the shared host carrying it on its relationship
    private SObject buildHost(SObject record) {
        if (singleKey == null) throw new FormulaEvaluatorException('"' + text + '" reads several objects (' + String.join(prefixByKey.values(), ', ') + '): evaluate it on a Map of the records by prefix.');
        checkType(singleKey, record);
        if (singleKey == hostPrefixKey) return record ?? getSharedHost();

        SObject host = getSharedHost();
        host.putSObject(relationshipByKey.get(singleKey), record);
        return host;
    }

    // Host of several records: a clone without Id of the host-prefix record (the master-detail of an existing record cannot be reassigned, even in memory) or the shared host, every other record on its relationship
    private SObject buildHost(Map<String, SObject> recordByKey) {
        SObject hostRecord = hostPrefixKey == null ? null : recordByKey.get(hostPrefixKey);
        checkType(hostPrefixKey, hostRecord);
        if (relationshipByKey.size() == 1 && hostPrefixKey != null) return hostRecord ?? getSharedHost();

        SObject host = hostRecord == null ? getSharedHost() : hostRecord.clone(false, false, true, true);
        for (String key : relationKeys) {
            SObject record = recordByKey.get(key);
            checkType(key, record);
            host.putSObject(relationshipByKey.get(key), record);
        }
        return host;
    }

    private SObject getSharedHost() {
        if (sharedHost == null) sharedHost = hostType.newSObject();
        return sharedHost;
    }

    private void checkType(String key, SObject record) {
        if (record != null && record.getSObjectType() != typeByKey.get(key)) throw new FormulaEvaluatorException('"' + text + '": a ' + record.getSObjectType() + ' was given for ' + prefixByKey.get(key) + '.');
    }

    // Prefixes as the caller writes them are resolved once (evaluations in bulk use the same keys)
    private Map<String, SObject> toRecordByKey(Map<String, SObject> recordByPrefix) {
        Map<String, SObject> recordByKey = new Map<String, SObject>();
        for (String prefix : recordByPrefix.keySet()) {
            String key = keyByPrefix.get(prefix);
            if (key == null) {
                key = toKey(prefix);
                keyByPrefix.put(prefix, key);
            }
            recordByKey.put(key, recordByPrefix.get(prefix));
        }
        return recordByKey;
    }

    // ───── Records ─────

    // Records with the given fields (case-insensitive duplicates removed), Id always selected; no query without Id
    public static List<SObject> queryRecords(Schema.SObjectType objectType, Set<Id> ids, Set<String> fields, AccessLevel accessLevel) {
        if (ids == null || ids.isEmpty()) return new List<SObject>();
        return queryRecords(objectType, fields, 'Id IN :ids', new Map<String, Object>{ 'ids' => ids }, accessLevel);
    }

    // Records with the given fields matching a WHERE clause written with bind variables (e.g. 'InternalShortName__c IN :names'), never with concatenated user input
    public static List<SObject> queryRecords(Schema.SObjectType objectType, Set<String> fields, String whereClause, Map<String, Object> binds, AccessLevel accessLevel) {
        String query = 'SELECT ' + String.join(buildSelectList(new List<String>{ 'Id' }, fields), ', ') + ' FROM ' + objectType;
        if (String.isNotBlank(whereClause)) query += ' WHERE ' + whereClause;
        return Database.queryWithBinds(query, binds ?? new Map<String, Object>(), accessLevel);
    }

    // Fields to select without duplicates (field names are case-insensitive)
    public static List<String> buildSelectList(List<String> mandatoryFields, Set<String> fields) {
        Map<String, String> fieldByLowerName = new Map<String, String>();
        for (String field : mandatoryFields ?? new List<String>()) fieldByLowerName.put(field.trim().toLowerCase(), field.trim());
        for (String field : fields ?? new Set<String>()) {
            if (String.isNotBlank(field) && !fieldByLowerName.containsKey(field.trim().toLowerCase())) fieldByLowerName.put(field.trim().toLowerCase(), field.trim());
        }
        return fieldByLowerName.values();
    }

    /** Records of one object with the parents their paths follow, as their lookups point now (Trigger.new, in-memory records, a lookup changed before save):
     *      paths relative to the records' object, e.g. getQueryFields(prefix). One query per relationship for all the records, parents cached per transaction (clearCaches()).
     *      Returns the records in their order: a record whose parents are already attached is returned as is (records queried with the paths: no query),
     *      otherwise a clone carrying them (Trigger.new is read-only). A record whose lookup was not read keeps what is attached. */
    public static List<SObject> withParents(List<SObject> records, Set<String> paths, AccessLevel accessLevel) {
        if (records == null || records.isEmpty() || paths == null) return records;

        Map<String, Map<String, String>> subPathsByRelationship = new Map<String, Map<String, String>>();
        for (String path : paths) {
            if (path == null || !path.contains('.')) continue;
            String relationship = path.substringBefore('.').trim().toLowerCase();
            String subPath = path.substringAfter('.').trim();
            if (!subPathsByRelationship.containsKey(relationship)) subPathsByRelationship.put(relationship, new Map<String, String>());
            if (!subPath.equalsIgnoreCase('Id')) subPathsByRelationship.get(relationship).put(subPath.toLowerCase(), subPath);
        }
        if (subPathsByRelationship.isEmpty()) return records;

        Schema.SObjectType objectType = records[0].getSObjectType();
        List<Map<String, Object>> populatedByIndex = new List<Map<String, Object>>();
        for (SObject record : records) populatedByIndex.add(record.getPopulatedFieldsAsMap());

        List<ParentLink> links = new List<ParentLink>();
        // A master-detail parent cannot be attached to a record with an Id, even in memory: such a record becomes a clone without Id
        Boolean keepIds = true;
        for (String relationship : subPathsByRelationship.keySet()) {
            ParentLink link = new ParentLink(objectType, relationship, subPathsByRelationship.get(relationship));
            link.load(populatedByIndex, accessLevel);
            links.add(link);
            if (link.masterDetail) keepIds = false;
        }

        List<SObject> result = new List<SObject>();
        for (Integer i = 0; i < records.size(); i++) {
            SObject record = records[i];
            SObject context;
            for (ParentLink link : links) {
                Map<String, Object> populated = populatedByIndex[i];
                if (!link.readsLookup(populated)) continue;
                Id parentId = link.getParentId(populated);
                if (link.getAttachedId(populated) == parentId) continue;

                if (context == null) context = record.clone(keepIds, false, true, true);
                context.putSObject(link.relationshipName, parentId == null ? null : parentByKey.get(link.cacheKey + parentId));
            }
            result.add(context ?? record);
        }
        return result;
    }

    // Empties the compiled formulas and the parents loaded in this transaction (e.g. after updating parents read by a formula)
    public static void clearCaches() {
        formulaByKey.clear();
        parentByKey.clear();
    }

    // A relationship followed by withParents: its lookup, the fields read on the parent, the key of its parents in the cache
    private class ParentLink {
        private String lookupName;
        private String relationshipName;
        private Boolean masterDetail;
        private Schema.SObjectType parentType;
        private Set<String> subPaths;
        private String cacheKey;

        private ParentLink(Schema.SObjectType objectType, String relationship, Map<String, String> subPathByLowerName) {
            Schema.SObjectField lookup = getLookup(objectType, relationship);
            List<Schema.SObjectType> targets = lookup?.getDescribe().getReferenceTo();
            if (targets == null || targets.size() != 1) throw new FormulaEvaluatorException(objectType + '.' + relationship + ' is not a lookup to a single object: its parents cannot be loaded.');
            Schema.DescribeFieldResult describe = lookup.getDescribe();
            lookupName = describe.getName();
            relationshipName = describe.getRelationshipName();
            masterDetail = describe.getRelationshipOrder() != null;
            parentType = targets[0];
            subPaths = new Set<String>(subPathByLowerName.values());
            List<String> lowerNames = new List<String>(subPathByLowerName.keySet());
            lowerNames.sort();
            cacheKey = objectType + '|' + relationship + '|' + String.join(lowerNames, ',') + '|';
        }

        // One query for the parents not cached and not attached yet
        private void load(List<Map<String, Object>> populatedByIndex, AccessLevel accessLevel) {
            Set<Id> parentIds = new Set<Id>();
            for (Map<String, Object> populated : populatedByIndex) {
                Id parentId = getParentId(populated);
                if (parentId != null && !parentByKey.containsKey(cacheKey + parentId) && getAttachedId(populated) != parentId) parentIds.add(parentId);
            }
            if (parentIds.isEmpty()) return;

            for (Id parentId : parentIds) parentByKey.put(cacheKey + parentId, null);
            for (SObject parent : queryRecords(parentType, parentIds, subPaths, accessLevel)) parentByKey.put(cacheKey + parent.Id, parent);
        }

        // Read from the fields set on the record (queried or put, names as described): never a "field not queried" error
        private Boolean readsLookup(Map<String, Object> populated) {
            return populated.containsKey(lookupName);
        }

        private Id getParentId(Map<String, Object> populated) {
            return (Id) populated.get(lookupName);
        }

        private Id getAttachedId(Map<String, Object> populated) {
            SObject attached = (SObject) populated.get(relationshipName);
            return attached == null ? null : (Id) attached.getPopulatedFieldsAsMap().get('Id');
        }
    }

    // ───── Describe ─────

    // Lookup field of a relationship of an object (ParentProduct__r -> ParentProduct__c, RecordType -> RecordTypeId), case-insensitive; null when the object has none
    public static Schema.SObjectField getLookup(Schema.SObjectType objectType, String relationshipName) {
        if (String.isBlank(relationshipName)) return null;
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

    private static Schema.SObjectType getObjectType(String objectName) {
        try {
            return Schema.describeSObjects(new List<String>{ objectName.trim() })[0].getSObjectType();
        }
        catch (Exception e) {
            throw new FormulaEvaluatorException(objectName + ' is not an object.');
        }
    }
}