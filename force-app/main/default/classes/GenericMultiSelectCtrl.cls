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

        Integer lim = (limitSize == null || limitSize <= 0) ? 200 : Math.min(limitSize, 2000);

        Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectApiName);
        if (sType == null) return new List<PickOpt>();

        Schema.DescribeSObjectResult d = sType.getDescribe();
        if (!d.isAccessible()) return new List<PickOpt>();

        Map<String, Schema.SObjectField> fields = d.fields.getMap();
        if (!fields.containsKey(labelFieldApiName) || !fields.containsKey(valueFieldApiName)) return new List<PickOpt>();
        if (!fields.get(labelFieldApiName).getDescribe().isAccessible()) return new List<PickOpt>();
        if (!fields.get(valueFieldApiName).getDescribe().isAccessible()) return new List<PickOpt>();

        // --- Optional filter (safe-ish) ---
        String whereClause = '';
        if (!String.isBlank(filterFieldApiName) && filterValue != null) {
            if (!fields.containsKey(filterFieldApiName)) {
                return new List<PickOpt>(); // unknown field => refuse
            }
            if (!fields.get(filterFieldApiName).getDescribe().isAccessible()) {
                return new List<PickOpt>(); // field not readable => refuse
            }

            // Allow only very limited operators
            String op = String.isBlank(filterOperator) ? '=' : filterOperator.trim().toUpperCase();
            Set<String> allowedOps = new Set<String>{'=', '!=', 'IN'};
            if (!allowedOps.contains(op)) {
                return new List<PickOpt>();
            }

            String safeValue = String.escapeSingleQuotes(filterValue);

            if (op == 'IN') {
                // Expect comma-separated values from Flow: 001..,001..
                List<String> parts = safeValue.split(',');
                List<String> quoted = new List<String>();
                for (String p : parts) {
                    String t = (p == null) ? null : p.trim();
                    if (String.isBlank(t)) continue;
                    quoted.add('\'' + t + '\'');
                }
                if (quoted.isEmpty()) return new List<PickOpt>();
                whereClause = ' WHERE ' + filterFieldApiName + ' IN (' + String.join(quoted, ',') + ')';
            } else {
                whereClause = ' WHERE ' + filterFieldApiName + ' ' + op + ' \'' + safeValue + '\'';
            }
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
            Object lab = r.get(labelFieldApiName);
            Object val = r.get(valueFieldApiName);
            if (val == null) continue;

            out.add(new PickOpt(
                lab == null ? String.valueOf(val) : String.valueOf(lab),
                String.valueOf(val)
            ));
        }
        return out;
    }
}