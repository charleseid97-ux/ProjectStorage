/**
 * @description Apex controller for the customReportMatrix LWC component.
 *              Reads matrix configuration from ReportMatrixConfiguration__mdt,
 *              dynamically queries the configured object, then groups records
 *              in Apex using Maps to build a pivot/matrix result.
 *              Supports up to 2 row grouping levels and 2 column grouping levels.
 * @author Charles EID
 */
public with sharing class CustomReportMatrixController {

    private static final String SEPARATOR = '||';

    @AuraEnabled(cacheable=false)
    public static MatrixResult getMatrixData(String configName) {
        MatrixResult result = new MatrixResult();
        result.errors = new List<String>();

        // 1. Read CMDT — SOQL required: getInstance() silently truncates LongTextArea fields
        List<ReportMatrixConfiguration__mdt> configs = [SELECT ObjectName__c, RowGroup1__c, RowGroup2__c, ColGroup1__c, ColGroup2__c,
                                                          ValueField__c, WhereClause__c, OrderByClause__c, Title__c, CellStyles__c
                                                        FROM ReportMatrixConfiguration__mdt
                                                        WHERE DeveloperName = :configName LIMIT 1];
        if (configs.isEmpty()) {
            throw new AuraHandledException(System.Label.Matrix_ConfigNotFound);
        }
        ReportMatrixConfiguration__mdt config = configs[0];

        String objectName       =   config.ObjectName__c;
        String rowGroup1        =   config.RowGroup1__c;
        String rowGroup2        =   config.RowGroup2__c;
        String colGroup1        =   config.ColGroup1__c;
        String colGroup2        =   config.ColGroup2__c;
        String valueField       =   config.ValueField__c;
        String whereClause      =   config.WhereClause__c;
        String orderByClause    =   config.OrderByClause__c;
        Boolean hasRowGroup2    =   String.isNotBlank(rowGroup2);
        Boolean hasColGroup2    =   String.isNotBlank(colGroup2);

        result.title = String.isNotBlank(config.Title__c) ? config.Title__c : configName;
        result.hasRowGroup2 = hasRowGroup2;
        result.hasColGroup2 = hasColGroup2;

        // 2. Build dynamic SOQL
        Set<String> fieldSet = new Set<String>{'Id'};
        fieldSet.add(rowGroup1);
        if (hasRowGroup2) {
            fieldSet.add(rowGroup2);
        }
        fieldSet.add(colGroup1);
        if (hasColGroup2) {
            fieldSet.add(colGroup2);
        }
        fieldSet.add(valueField);

        String soql = 'SELECT ' + String.join(new List<String>(fieldSet), ', ')
                    + ' FROM ' + String.escapeSingleQuotes(objectName);
        soql += (String.isNotBlank(whereClause))? ' WHERE ' + whereClause : '';
        soql += (String.isNotBlank(orderByClause))? ' ORDER BY ' + orderByClause : '';
        soql += ' LIMIT 50000';

        // 3. Build picklist label maps for all fields (API value → Label)
        Map<String, Map<String, String>> picklistMaps = new Map<String, Map<String, String>>();
        for (String fieldPath : fieldSet) {
            if (fieldPath == 'Id') { continue; }
            Map<String, String> plMap = buildPicklistLabelMap(objectName, fieldPath);
            if (!plMap.isEmpty()) {
                picklistMaps.put(fieldPath, plMap);
            }
        }

        // 4. Parse CellStyles JSON into style lookup maps
        StyleLookup styleLookup = parseStyleLookup(config.CellStyles__c);

        // 5. Group with Maps
        Map<String, Set<String>> colGroup2ByCg1 = new Map<String, Set<String>>();
        Map<String, Set<String>> rowGroup2ByRg1 = new Map<String, Set<String>>();
        Set<String> rg1Values = new Set<String>();
        Map<String, Map<String, Map<String, CellData>>> cells = new Map<String, Map<String, Map<String, CellData>>>();

        for (SObject rec : Database.query(soql)) {
            String rg1Val = getValOrBlank(toLabel(getStringFieldValue(rec, rowGroup1), picklistMaps.get(rowGroup1)));
            String rg2Val = hasRowGroup2 ? getValOrBlank(toLabel(getStringFieldValue(rec, rowGroup2), picklistMaps.get(rowGroup2))) : '';
            String cg1Val = getValOrBlank(toLabel(getStringFieldValue(rec, colGroup1), picklistMaps.get(colGroup1)));
            String cg2Val = hasColGroup2 ? getValOrBlank(toLabel(getStringFieldValue(rec, colGroup2), picklistMaps.get(colGroup2))) : '';
            String rawValStr = getStringFieldValue(rec, valueField);
            String valStr = toLabel(rawValStr, picklistMaps.get(valueField));

            // Column structure
            if (!colGroup2ByCg1.containsKey(cg1Val)) {
                colGroup2ByCg1.put(cg1Val, new Set<String>());
            }
            if (hasColGroup2) {
                colGroup2ByCg1.get(cg1Val).add(cg2Val);
            }

            // Row structure
            rg1Values.add(rg1Val);
            if (!rowGroup2ByRg1.containsKey(rg1Val)) {
                rowGroup2ByRg1.put(rg1Val, new Set<String>());
            }
            if (hasRowGroup2) {
                rowGroup2ByRg1.get(rg1Val).add(rg2Val);
            }

            // Cell value
            String rowKey = rg1Val + (hasRowGroup2? SEPARATOR + rg2Val : '');
            String colKey = cg1Val + (hasColGroup2? SEPARATOR + cg2Val : '');
            if (!cells.containsKey(rowKey)) {
                cells.put(rowKey, new Map<String, Map<String, CellData>>());
            }
            if (!cells.get(rowKey).containsKey(colKey)) {
                cells.get(rowKey).put(colKey, new Map<String, CellData>());
            }
            if (rawValStr != null && valStr != null) {
                cells.get(rowKey).get(colKey).put(rawValStr, new CellData(rawValStr, valStr));
            }
        }

        // 6. Sort and build column structure
        List<String> sortedCg1 = new List<String>(colGroup2ByCg1.keySet());
        sortedCg1.sort();

        List<ColumnGroup> columnGroups = new List<ColumnGroup>();
        List<String> columnKeys = new List<String>();
        List<String> subColumnLabels = new List<String>();

        for (String cg1 : sortedCg1) {
            if (hasColGroup2) {
                List<String> sortedCg2 = new List<String>(colGroup2ByCg1.get(cg1));
                sortedCg2.sort();
                columnGroups.add(new ColumnGroup(cg1, sortedCg2.size()));
                for (String cg2 : sortedCg2) {
                    columnKeys.add(cg1 + SEPARATOR + cg2);
                    subColumnLabels.add(cg2);
                }
            }
            else {
                columnKeys.add(cg1);
                subColumnLabels.add(cg1);
            }
        }

        // 7. Sort and build row structure
        List<String> sortedRg1 = new List<String>(rg1Values);
        sortedRg1.sort();
        List<RowGroup> rowGroups = new List<RowGroup>();
        for (String rg1 : sortedRg1) {
            List<RowData> rows = new List<RowData>();
            if (hasRowGroup2) {
                List<String> sortedRg2 = new List<String>(rowGroup2ByRg1.get(rg1));
                sortedRg2.sort();
                for (String rg2 : sortedRg2) {
                    rows.add(buildRowData(rg2, rg1 + SEPARATOR + rg2, columnKeys, cells, styleLookup));
                }
            }
            else {
                rows.add(buildRowData(rg1, rg1, columnKeys, cells, styleLookup));
            }
            rowGroups.add(new RowGroup(rg1, rows.size(), rows));
        }

        // 8. Resolve field labels
        result.columnGroups = columnGroups;
        result.subColumnLabels = subColumnLabels;
        result.columnKeys = columnKeys;
        result.rowGroups = rowGroups;
        result.valueFieldLabel = getFieldLabel(objectName, valueField);
        result.colGroup1Label = getFieldLabel(objectName, colGroup1);
        result.colGroup2Label = hasColGroup2 ? getFieldLabel(objectName, colGroup2) : null;
        result.rowGroup1Label = getFieldLabel(objectName, rowGroup1);
        result.rowGroup2Label = hasRowGroup2 ? getFieldLabel(objectName, rowGroup2) : null;

        return result;
    }

    // ------------------------------------ HELPERS ------------------------------------
    private static StyleLookup parseStyleLookup(String cellStylesJson) {
        StyleLookup stylelookup = new StyleLookup();
        if (String.isNotBlank(cellStylesJson)) {
            List<FieldStyleConfig> cfgList = (List<FieldStyleConfig>) JSON.deserialize(cellStylesJson, List<FieldStyleConfig>.class);
            for (FieldStyleConfig cfg : (cfgList ?? new List<FieldStyleConfig>())) {
                if (cfg.rules != null) {
                    for (StyleRule rule : cfg.rules) {
                        if (rule.values != null && String.isNotBlank(rule.style)) {
                            for (String v : rule.values) {
                                stylelookup.styleByRawValue.put(v, rule.style);
                            }
                        }
                    }
                }
                if (cfg.defaultStyle != null && String.isNotBlank(cfg.defaultStyle.style)) {
                    stylelookup.defaultStyle = cfg.defaultStyle.style;
                }
            }
        }
        return stylelookup;
    }

    private static RowData buildRowData(String label, String rowKey, List<String> columnKeys, Map<String, Map<String, Map<String, CellData>>> cells, StyleLookup stylelookup) {
        Map<String, Map<String, CellData>> colMap = cells.containsKey(rowKey) ? cells.get(rowKey) : new Map<String, Map<String, CellData>>();
        List<CellData> orderedValues = new List<CellData>();
        for (String ck : columnKeys) {
            List<CellData> vals = colMap.containsKey(ck) ? colMap.get(ck).values() : new List<CellData>();
            CellData cell = sortAndJoin(vals);
            cell.inlineStyle = resolveInlineStyle(cell.rawValue, stylelookup);
            orderedValues.add(cell);
        }
        return new RowData(label, orderedValues);
    }

    private static String resolveInlineStyle(String joinedRawValue, StyleLookup stylelookup) {
        if (String.isBlank(joinedRawValue)) { return ''; }
        Set<String> distinctStyles = new Set<String>();
        for (String raw : joinedRawValue.split('\n')) {
            distinctStyles.add(stylelookup.styleByRawValue.containsKey(raw) ? stylelookup.styleByRawValue.get(raw) : stylelookup.defaultStyle);
        }
        return (distinctStyles.size() == 1) ? new List<String>(distinctStyles)[0] : System.Label.Matrix_ConflictStyle;
    }

    private static CellData sortAndJoin(List<CellData> cellData) {
        if(cellData.isEmpty()) {
            return new CellData('', '');
        }
        else {
            List<String> rawValsList = new List<String>();
            List<String> valsList = new List<String>();
            for(CellData cd : cellData) {
                rawValsList.add(cd.rawValue);
                rawValsList.sort();
                valsList.add(cd.value);
                valsList.sort();
            }
            return new CellData(String.join(rawValsList, '\n'), String.join(valsList, '\n'));
        }
    }

    public static Object getFieldValue(SObject record, List<String> fieldApiPath, Integer index) {
        if (record == null) { return null; }
        String segment = fieldApiPath[index];
        if (index == fieldApiPath.size() - 1) {
            return record.get(segment);
        }
        SObject child = record.getSObject(segment);
        return getFieldValue(child, fieldApiPath, index + 1);
    }

    private static String getStringFieldValue(SObject record, String fieldPath) {
        if (record == null || String.isBlank(fieldPath)) {
            return null;
        }
        Object raw = getFieldValue(record, fieldPath.split('\\.'), 0);
        return raw == null ? null : String.valueOf(raw);
    }

    private static String getValOrBlank(String val) {
        return val != null ? val : Label.Matrix_Blank;
    }

    private static String toLabel(String val, Map<String, String> picklistMap) {
        if (val == null || picklistMap == null || picklistMap.isEmpty()) {
            return val;
        }
        return picklistMap.containsKey(val) ? picklistMap.get(val) : val;
    }

    private static Map<String, String> buildPicklistLabelMap(String objectName, String fieldPath) {
        Map<String, String> labelMap = new Map<String, String>();
        DescribeFieldResult dfr = resolveFieldDescribe(objectName, fieldPath);
        if (dfr != null && (dfr.getType() == Schema.DisplayType.Picklist || dfr.getType() == Schema.DisplayType.MultiPicklist)) {
            for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                labelMap.put(pe.getValue(), pe.getLabel());
            }
        }
        return labelMap;
    }

    private static DescribeFieldResult resolveFieldDescribe(String objectName, String fieldPath) {
        try {
            List<String> segments = fieldPath.split('\\.');
            SObjectType currentType = Schema.getGlobalDescribe().get(objectName);

            for (Integer i = 0; i < segments.size(); i++) {
                if (currentType == null) { return null; }
                String segment = segments[i];
                Map<String, SObjectField> fieldMap = currentType.getDescribe().fields.getMap();

                if (i == segments.size() - 1) {
                    SObjectField field = fieldMap.get(segment);
                    return field?.getDescribe();
                }

                // Intermediate segment: relationship → resolve to lookup field → get referenced object
                String lookupFieldName = (segment.endsWith('__r'))? segment.removeEnd('__r') + '__c' : segment + 'Id';
                SObjectField lookupField = fieldMap.get(lookupFieldName);
                if (lookupField == null) { return null; }

                List<SObjectType> refs = lookupField.getDescribe().getReferenceTo();
                if (refs.isEmpty()) { return null; }
                currentType = refs[0];
            }
            return null;
        }
        catch (Exception e) {
            return null;
        }
    }

    private static String getFieldLabel(String objectName, String fieldPath) {
        DescribeFieldResult fieldDescribe = resolveFieldDescribe(objectName, fieldPath);
        return fieldDescribe != null ? fieldDescribe.getLabel() : fieldPath;
    }

    // ------------------------------------ WRAPPERS ------------------------------------
    public class MatrixResult {
        @AuraEnabled public List<ColumnGroup> columnGroups { get; set; }
        @AuraEnabled public List<String> subColumnLabels { get; set; }
        @AuraEnabled public List<String> columnKeys { get; set; }
        @AuraEnabled public List<RowGroup> rowGroups { get; set; }
        @AuraEnabled public String valueFieldLabel { get; set; }
        @AuraEnabled public String colGroup1Label { get; set; }
        @AuraEnabled public String colGroup2Label { get; set; }
        @AuraEnabled public String rowGroup1Label { get; set; }
        @AuraEnabled public String rowGroup2Label { get; set; }
        @AuraEnabled public Boolean hasColGroup2 { get; set; }
        @AuraEnabled public Boolean hasRowGroup2 { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public List<String> errors { get; set; }
    }

    public class ColumnGroup {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Integer colspan { get; set; }
        public ColumnGroup(String label, Integer colspan) {
            this.label = label;
            this.colspan = colspan;
        }
    }

    public class RowGroup {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Integer rowspan { get; set; }
        @AuraEnabled public List<RowData> rows { get; set; }
        public RowGroup(String label, Integer rowspan, List<RowData> rows) {
            this.label = label;
            this.rowspan = rowspan;
            this.rows = rows;
        }
    }

    public class RowData {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public List<CellData> values { get; set; }
        public RowData(String label, List<CellData> values) {
            this.label = label;
            this.values = values;
        }
    }

    public class CellData {
        @AuraEnabled public String rawValue { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String inlineStyle { get; set; }
        public CellData(String rawValue, String value) {
            this.rawValue    = rawValue;
            this.value       = value;
            this.inlineStyle = '';
        }
    }
    
    public class StyleLookup {
        Map<String, String> styleByRawValue = new Map<String, String>();
        String defaultStyle = '';
    }

    // JSON deserialization wrappers for CellStyles__c
    public class FieldStyleConfig {
        public String field;
        public List<StyleRule> rules;
        public StyleDefault defaultStyle;
    }

    public class StyleRule {
        public List<String> values;
        public String style;
    }

    public class StyleDefault {
        public String style;
    }
}