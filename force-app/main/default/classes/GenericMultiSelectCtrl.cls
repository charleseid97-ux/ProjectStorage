public with sharing class GenericMultiSelectCtrl {

    public class PickOpt {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public PickOpt(String l, String v) {
            label = l;
            value = v;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PickOpt> getOptions(
        String objectApiName,
        String labelFieldApiName,
        String valueFieldApiName,
        Integer limitSize,
        String filterFieldApiName,
        String filterOperator,
        String filterValue
    ) {
        System.debug('GenericMultiSelectCtrl.getOptions: ' +
            ' objectApiName=' + objectApiName +
            ' labelFieldApiName=' + labelFieldApiName +
            ' valueFieldApiName=' + valueFieldApiName +
            ' limitSize=' + limitSize +
            ' filterFieldApiName=' + filterFieldApiName +
            ' filterOperator=' + filterOperator +
            ' filterValue=' + filterValue
        );

        if (String.isBlank(objectApiName) || String.isBlank(labelFieldApiName) || String.isBlank(valueFieldApiName)) {
            return new List<PickOpt>();
        }

        Integer lim = resolveLimit(limitSize);

        Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectApiName);
        if (sType == null) return new List<PickOpt>();

        Schema.DescribeSObjectResult d = sType.getDescribe();
        if (!d.isAccessible()) return new List<PickOpt>();

        Map<String, Schema.SObjectField> fields = d.fields.getMap();
        if (!hasReadableFields(fields, labelFieldApiName, valueFieldApiName)) {
            return new List<PickOpt>();
        }

        // --- Optional filter (safe-ish) ---
        String whereClause = buildWhereClause(fields, filterFieldApiName, filterOperator, filterValue);
        if (whereClause == null) {
            return new List<PickOpt>();
        }

        String soql =
            'SELECT ' + labelFieldApiName + ', ' + valueFieldApiName +
            ' FROM ' + objectApiName +
            whereClause +
            ' ORDER BY ' + labelFieldApiName +
            ' LIMIT ' + lim;

        List<SObject> rows = Database.query(soql);

        // Strip inaccessible fields
        SObjectAccessDecision dec = Security.stripInaccessible(AccessType.READABLE, rows);
        List<SObject> safeRows = dec.getRecords();

        List<PickOpt> out = new List<PickOpt>();
        for (SObject r : safeRows) {
            PickOpt opt = toPickOpt(r, labelFieldApiName, valueFieldApiName);
            if (opt != null) out.add(opt);
        }
        return out;
    }

    private static Integer resolveLimit(Integer limitSize) {
        return (limitSize == null || limitSize <= 0) ? 200 : Math.min(limitSize, 2000);
    }

    private static Boolean hasReadableFields(
        Map<String, Schema.SObjectField> fields,
        String labelFieldApiName,
        String valueFieldApiName
    ) {
        if (!fields.containsKey(labelFieldApiName) || !fields.containsKey(valueFieldApiName)) return false;
        if (!fields.get(labelFieldApiName).getDescribe().isAccessible()) return false;
        if (!fields.get(valueFieldApiName).getDescribe().isAccessible()) return false;
        return true;
    }

    // --- Optional filter (safe-ish) ---
    // Returns:
    //  - '' (empty string) when no filter requested
    //  - a valid ' WHERE ...' clause when filter is valid
    //  - null when filter is invalid => caller should refuse (empty output)
    private static String buildWhereClause(
        Map<String, Schema.SObjectField> fields,
        String filterFieldApiName,
        String filterOperator,
        String filterValue
    ) {
        if (String.isBlank(filterFieldApiName) || filterValue == null) {
            return '';
        }

        if (!fields.containsKey(filterFieldApiName)) {
            return null; // unknown field => refuse
        }
        if (!fields.get(filterFieldApiName).getDescribe().isAccessible()) {
            return null; // field not readable => refuse
        }

        // Allow only very limited operators
        String op = normalizeOperator(filterOperator);
        if (op == null) return null;

        String safeValue = String.escapeSingleQuotes(filterValue);

        if (op == 'IN') {
            // Expect comma-separated values from Flow: 001..,001..
            String inList = buildInList(safeValue);
            if (inList == null) return null;
            return ' WHERE ' + filterFieldApiName + ' IN (' + inList + ')';
        }

        return ' WHERE ' + filterFieldApiName + ' ' + op + ' \'' + safeValue + '\'';
    }

    // Allow only very limited operators
    private static String normalizeOperator(String filterOperator) {
        String op = String.isBlank(filterOperator) ? '=' : filterOperator.trim().toUpperCase();
        Set<String> allowedOps = new Set<String>{'=', '!=', 'IN'};
        return allowedOps.contains(op) ? op : null;
    }

    // Expect comma-separated values from Flow: 001..,001..
    private static String buildInList(String safeValue) {
        List<String> parts = safeValue.split(',');
        List<String> quoted = new List<String>();
        for (String p : parts) {
            String t = (p == null) ? null : p.trim();
            if (String.isBlank(t)) continue;
            quoted.add('\'' + t + '\'');
        }
        return quoted.isEmpty() ? null : String.join(quoted, ',');
    }

    private static PickOpt toPickOpt(SObject r, String labelFieldApiName, String valueFieldApiName) {
        Object lab = r.get(labelFieldApiName);
        Object val = r.get(valueFieldApiName);
        if (val == null) return null;

        return new PickOpt(
            lab == null ? String.valueOf(val) : String.valueOf(lab),
            String.valueOf(val)
        );
    }
}