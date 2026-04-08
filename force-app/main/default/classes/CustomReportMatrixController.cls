/**
 * @description Apex controller for the customReportMatrix LWC component.
 *              Reads matrix configuration from ReportMatrixConfiguration__mdt,
 *              dynamically queries the configured object, then groups records
 *              in Apex using Maps to build a recursive pivot/matrix result.
 *              Supports N row grouping levels and N column grouping levels.
 * @author Charles EID
 * @testClass CustomReportMatrixControllerTest
 * @coverage 97%
 */
public with sharing class CustomReportMatrixController {

    private static final String SEPARATOR = '||';

    @AuraEnabled(cacheable=false)
    public static MatrixResult getMatrixData(String configName, String filterSelectionsJson, Boolean isInitialLoad) {
        // 1. Read CMDT — SOQL required: getInstance() silently truncates LongTextArea fields
        List<ReportMatrixConfiguration__mdt> configs = [SELECT ObjectName__c, RowGroups__c, ColGroups__c, ValueFields__c, WhereClause__c, OrderByClause__c,
                                                                Title__c, CellStyles__c, AllowExcelExport__c, AllowFilters__c, FilterFields__c, FilterRowsLabel__c,
                                                                OnHoverFields__c
                                                        FROM ReportMatrixConfiguration__mdt
                                                        WHERE DeveloperName = :configName LIMIT 1];
        if (configs.isEmpty()) {
            throw new AuraHandledException(System.Label.Matrix_ConfigNotFound);
        }
        ReportMatrixConfiguration__mdt config = configs[0];

        String objectName = config.ObjectName__c;

        // 2. Shared describe cache — each field path is resolved at most once
        Map<String, DescribeFieldResult> describeCache = new Map<String, DescribeFieldResult>();
        Map<String, Schema.DisplayType> fieldTypeMap   = new Map<String, Schema.DisplayType>();

        // 3. Build ordered row/col group levels (each line = one level; fields on a line separated by ';')
        List<List<String>> rowGroupLevels = parseGroupLevels(config.RowGroups__c, objectName, fieldTypeMap, describeCache);
        List<List<String>> colGroupLevels = parseGroupLevels(config.ColGroups__c, objectName, fieldTypeMap, describeCache);

        // 4. Parse filter fields — always parsed so fieldTypeMap contains their types (needed for date-range SOQL on reload)
        List<String> filterGroupFields = parseGroupFields(config.FilterFields__c, objectName, '\n', fieldTypeMap, describeCache);

        // 5. Parse hover fields and build configs (label + path)
        List<String> hoverFieldPaths = parseGroupFields(config.OnHoverFields__c, objectName, '\n', fieldTypeMap, describeCache);
        List<HoverFieldConfig> hoverFieldConfigs = new List<HoverFieldConfig>();
        for (String fp : hoverFieldPaths) {
            hoverFieldConfigs.add(new HoverFieldConfig(fp, getFieldLabel(objectName, fp, describeCache)));
        }

        // 6. Parse value fields (one or more, newline-separated)
        List<String> valueFields = parseGroupFields(config.ValueFields__c, objectName, '\n', fieldTypeMap, describeCache);

        // 7. Deserialize filter selections and build the SOQL filter fragment
        Map<String, List<String>> filterSelMap = String.isNotBlank(filterSelectionsJson)? (Map<String, List<String>>) JSON.deserialize(filterSelectionsJson, Map<String, List<String>>.class) : new Map<String, List<String>>();
        String filterFragment = buildFilterFragment(filterSelMap, fieldTypeMap);

        // 8. Build field set — include filter fields on initial load so a single query serves both purposes
        Set<String> fieldSet = buildFieldSet(rowGroupLevels, colGroupLevels, valueFields);
        if (isInitialLoad == true) { fieldSet.addAll(filterGroupFields); }
        fieldSet.addAll(hoverFieldPaths);

        // 9. Build picklist label maps for all fields (API value → Label)
        Map<String, Map<String, String>> picklistMaps = buildFieldPicklistLabelMap(fieldSet, objectName, fieldTypeMap, describeCache);

        // 10. Parse CellStyles JSON into style lookup
        StyleLookup styleLookup = parseStyleLookup(config.CellStyles__c);

        // 11. Run the single SOQL query
        String soql = buildDynamicSOQL(config, fieldSet, objectName, filterFragment);
        List<SObject> records = Database.query(soql);

        // 12. On initial load: build filter options from the same query records (no extra query needed)
        List<FilterOption> filterOptions = new List<FilterOption>();
        if (isInitialLoad == true && !filterGroupFields.isEmpty()) {
            filterOptions = buildFilterOptions(filterGroupFields, records, picklistMaps, objectName, fieldTypeMap, describeCache);
        }

        // 13. Group records — builds parent→children maps and cells map
        GroupResult grouped = groupRecords(records, rowGroupLevels, colGroupLevels, valueFields, objectName, picklistMaps, hoverFieldConfigs, fieldTypeMap, describeCache, styleLookup);

        // 14. Build column tree and extract ordered leaf keys
        List<String> columnKeys = new List<String>();
        List<ColNode> colTree = buildColTree(colGroupLevels, 0, '', grouped.colChildrenByParentKey, columnKeys);

        // 15. Build row tree (uses columnKeys to order leaf values)
        List<RowNode> rowTree = buildRowTree(rowGroupLevels, 0, '', grouped.rowChildrenByParentKey, columnKeys, grouped.cells, styleLookup);

        // 16. Assemble result
        MatrixResult result     = new MatrixResult(String.isNotBlank(config.Title__c) ? config.Title__c : configName, config.AllowExcelExport__c);
        result.allowFilters     = config.AllowFilters__c;
        result.filterRowsLabel  = String.isNotBlank(config.FilterRowsLabel__c) ? config.FilterRowsLabel__c : 'Filter';
        result.filterOptions    = filterOptions;
        result.rowTree          = rowTree;
        result.colTree          = colTree;
        result.columnKeys       = columnKeys;
        List<String> vfLabels = new List<String>();
        for (String vf : valueFields) { vfLabels.add(getFieldLabel(objectName, vf, describeCache)); }
        result.valueFieldLabel  = String.join(vfLabels, ' / ');

        for (List<String> level : rowGroupLevels) {
            List<String> lbls = new List<String>();
            for (String f : level) { lbls.add(getFieldLabel(objectName, f, describeCache)); }
            result.rowGroupLabels.add(String.join(lbls, ' / '));
        }

        for (List<String> level : colGroupLevels) {
            List<String> lbls = new List<String>();
            for (String f : level) { lbls.add(getFieldLabel(objectName, f, describeCache)); }
            result.colGroupLabels.add(String.join(lbls, ' / '));
        }

        return result;
    }

    // ------------------------------------ HELPERS ------------------------------------
    private static List<List<String>> parseGroupLevels(String raw, String objectName, Map<String, Schema.DisplayType> fieldTypeMap, Map<String, DescribeFieldResult> describeCache) {
        List<List<String>> result = new List<List<String>>();
        if (String.isBlank(raw)) return result;
        for (String line : raw.split('\n')) {
            String trimmedLine = line.trim();
            if (String.isBlank(trimmedLine)) continue;
            List<String> levelFields = parseGroupFields(trimmedLine, objectName, ';', fieldTypeMap, describeCache);
            if (!levelFields.isEmpty()) result.add(levelFields);
        }
        return result;
    }

    private static List<String> parseGroupFields(String raw, String objectName, String separator, Map<String, Schema.DisplayType> fieldTypeMap, Map<String, DescribeFieldResult> describeCache) {
        List<String> result = new List<String>();
        if (String.isBlank(raw)) return result;
        for (String line : raw.split(separator)) {
            String trimmed = line.trim();
            if (String.isBlank(trimmed)) continue;
            DescribeFieldResult dfr = resolveFieldDescribe(objectName, trimmed, describeCache);
            if (dfr == null) {
                throw new AuraHandledException(String.format(System.Label.Matrix_InvalidField, new List<Object>{ trimmed }));
            }
            fieldTypeMap.put(trimmed, dfr.getType());
            result.add(trimmed);
        }
        return result;
    }

    private static Set<String> buildFieldSet(List<List<String>> rowGroupLevels, List<List<String>> colGroupLevels, List<String> valueFields) {
        Set<String> fieldSet = new Set<String>{'Id'};
        for (List<String> level : rowGroupLevels) { fieldSet.addAll(level); }
        for (List<String> level : colGroupLevels) { fieldSet.addAll(level); }
        fieldSet.addAll(valueFields);
        return fieldSet;
    }

    private static String buildDynamicSOQL(ReportMatrixConfiguration__mdt config, Set<String> fieldSet, String objectName, String filterFragment) {
        String soql = 'SELECT ' + String.join(new List<String>(fieldSet), ', ')
                    + ' FROM ' + String.escapeSingleQuotes(objectName);
        List<String> whereParts = new List<String>();
        if (String.isNotBlank(config.WhereClause__c)) {
            whereParts.add(config.WhereClause__c);
        }
        if (String.isNotBlank(filterFragment)) {
            whereParts.add('(' + filterFragment + ')');
        }
        if (!whereParts.isEmpty()) {
            soql += ' WHERE ' + String.join(whereParts, ' AND ');
        }
        soql += String.isNotBlank(config.OrderByClause__c)? ' ORDER BY ' + config.OrderByClause__c : '';
        soql += ' LIMIT 50000';
        return soql;
    }

    private static String buildFilterFragment(Map<String, List<String>> selections, Map<String, Schema.DisplayType> fieldTypeMap) {
        List<String> conds = new List<String>();
        for (String fp : selections.keySet()) {
            List<String> vals = selections.get(fp);
            if (vals == null || vals.isEmpty()) continue;

            Schema.DisplayType dt = fieldTypeMap?.get(fp);
            if (dt == Schema.DisplayType.Date || dt == Schema.DisplayType.DateTime) { // Type: Date or DateTime
                buildDateConditions(fp, vals, dt, conds);
            } 
            else { // Type: Everything else
                conds.add(fp + ' IN (' + toSoqlInLiteral(vals) + ')');
            }
        }
        return String.join(conds, ' AND ');
    }

    private static void buildDateConditions(String fp, List<String> vals, Schema.DisplayType dt, List<String> conds) {
        if (vals.size() == 1 && String.isNotBlank(vals[0])) {
            conds.add(fp + ' = ' + toDateLiteral(vals[0], dt));
        } else if (vals.size() == 2) {
            if (String.isNotBlank(vals[0])) {
                conds.add(fp + ' >= ' + toDateLiteral(vals[0], dt));
            }
            if (String.isNotBlank(vals[1])) {
                conds.add(fp + ' <= ' + toDateLiteral(vals[1], dt));
            }
        }
    }

    private static String toDateLiteral(String val, Schema.DisplayType dt) {
        String safe = String.escapeSingleQuotes(val);
        if (dt == Schema.DisplayType.DateTime) {
            // JS sends datetime-local as 'YYYY-MM-DDTHH:mm' — append seconds + UTC for SOQL
            return safe + ':00Z';
        }
        return safe; // Date literal: YYYY-MM-DD (no quotes needed in SOQL)
    }

    private static String toSoqlInLiteral(List<String> vals) {
        List<String> quoted = new List<String>();
        for (String v : vals) { quoted.add('\'' + String.escapeSingleQuotes(v) + '\''); }
        return String.join(quoted, ', ');
    }

    private static List<FilterOption> buildFilterOptions(List<String> filterFields, List<SObject> records, Map<String, Map<String, String>> picklistMaps, String objectName, Map<String, Schema.DisplayType> fieldTypeMap, Map<String, DescribeFieldResult> describeCache) {
        List<FilterOption> result = new List<FilterOption>();
        for (String fp : filterFields) {
            Map<String, String> seen = new Map<String, String>(); // rawValue → displayLabel
            for (SObject rec : records) {
                String raw = getStringFieldValue(rec, fp, fieldTypeMap);
                if (raw != null && !seen.containsKey(raw)) {
                    seen.put(raw, toLabel(raw, picklistMaps.get(fp)));
                }
            }
            List<String> sortedRaw = new List<String>(seen.keySet());
            sortedRaw.sort();
            List<OptionEntry> entries = new List<OptionEntry>();
            for (String raw : sortedRaw) {
                entries.add(new OptionEntry(seen.get(raw), raw));
            }
            result.add(new FilterOption(getFieldLabel(objectName, fp, describeCache), fp, String.valueOf(fieldTypeMap.get(fp)), entries));
        }
        return result;
    }

    private static Map<String, Map<String, String>> buildFieldPicklistLabelMap(Set<String> fieldSet, String objectName, Map<String, Schema.DisplayType> fieldTypeMap, Map<String, DescribeFieldResult> describeCache) {
        Map<String, Map<String, String>> picklistMaps = new Map<String, Map<String, String>>();
        for (String fieldPath : fieldSet) {
            if (fieldPath == 'Id') continue;
            DescribeFieldResult dfr = resolveFieldDescribe(objectName, fieldPath, describeCache);
            if (dfr == null) continue;
            if (!fieldTypeMap.containsKey(fieldPath)) {
                fieldTypeMap.put(fieldPath, dfr.getType()); // fills gaps (e.g. valueField)
            }
            if (dfr.getType() == Schema.DisplayType.Picklist || dfr.getType() == Schema.DisplayType.MultiPicklist) {
                Map<String, String> plMap = new Map<String, String>();
                for (Schema.PicklistEntry pe : dfr.getPicklistValues()) { plMap.put(pe.getValue(), pe.getLabel()); }
                if (!plMap.isEmpty()) {
                    picklistMaps.put(fieldPath, plMap);
                }
            }
        }
        return picklistMaps;
    }

    private static StyleLookup parseStyleLookup(String cellStylesJson) {
        StyleLookup stylelookup = new StyleLookup();
        if (String.isNotBlank(cellStylesJson)) {
            List<FieldStyleConfig> cfgList = (List<FieldStyleConfig>) JSON.deserialize(cellStylesJson, List<FieldStyleConfig>.class);
            for (FieldStyleConfig cfg : (cfgList ?? new List<FieldStyleConfig>())) {
                if (String.isNotBlank(cfg.field)) {
                    stylelookup.styledFieldPath = cfg.field;
                }
                if (cfg.rules != null) {
                    stylelookup.styleByRawValue = buildStyleByRawValueMap(cfg.rules);
                }
                if (cfg.defaultStyle != null && String.isNotBlank(cfg.defaultStyle.style)) {
                    stylelookup.defaultStyle = cfg.defaultStyle.style;
                }
            }
        }
        return stylelookup;
    }

    private static Map<String, String> buildStyleByRawValueMap(List<StyleRule> rules) {
        Map<String, String> styleByRawValue = new Map<String, String>();
        for (StyleRule rule : rules) {
            if (rule.values != null && String.isNotBlank(rule.style)) {
                for (String v : rule.values) {
                    styleByRawValue.put(v, rule.style);
                }
            }
        }
        return styleByRawValue;
    }

    private static GroupResult groupRecords(List<SObject> records, List<List<String>> rowGroupLevels, List<List<String>> colGroupLevels, List<String> valueFields, String objectName, Map<String, Map<String, String>> picklistMaps, List<HoverFieldConfig> hoverConfigs, Map<String, Schema.DisplayType> fieldTypeMap, Map<String, DescribeFieldResult> describeCache, StyleLookup styleLookup) {
        GroupResult g = new GroupResult();
        Boolean multiValue = valueFields.size() > 1;
        // Pre-resolve labels once (outside the record loop)
        Map<String, String> valueFieldLabels = new Map<String, String>();
        if (multiValue) {
            for (String vf : valueFields) {
                valueFieldLabels.put(vf, getFieldLabel(objectName, vf, describeCache));
            }
        }
        for (SObject rec : records) {
            String rowKey = buildGroupKey(rec, rowGroupLevels, picklistMaps, g.rowChildrenByParentKey, fieldTypeMap);
            String colKey = buildGroupKey(rec, colGroupLevels, picklistMaps, g.colChildrenByParentKey, fieldTypeMap);
            String rawValStr;
            String valStr;
            String styleRawVal;
            if (multiValue) {
                List<String> rawParts = new List<String>();
                List<String> valParts = new List<String>();
                styleRawVal = null;
                for (String vf : valueFields) {
                    String raw   = getStringFieldValue(rec, vf, fieldTypeMap);
                    String label = valueFieldLabels.get(vf);
                    String val   = toLabel(raw, picklistMaps.get(vf));
                    rawParts.add(label + ': ' + (val != null ? val : ''));
                    valParts.add(label + ': ' + (val != null ? val : ''));
                    if (vf == styleLookup.styledFieldPath) {
                        styleRawVal = raw;
                    }
                }
                rawValStr = String.join(rawParts, '\n');
                valStr    = String.join(valParts, '\n');
            } else {
                rawValStr = getStringFieldValue(rec, valueFields[0], fieldTypeMap);
                valStr    = toLabel(rawValStr, picklistMaps.get(valueFields[0]));
                styleRawVal = rawValStr;
            }
            registerCell(g, rowKey, colKey, rawValStr, valStr, styleRawVal, rec, hoverConfigs, picklistMaps, fieldTypeMap);
        }
        return g;
    }

    private static String buildGroupKey(SObject rec, List<List<String>> groupLevels, Map<String, Map<String, String>> picklistMaps, Map<String, Set<String>> childrenByParentKey, Map<String, Schema.DisplayType> fieldTypeMap) {
        String parentKey = '';
        for (List<String> levelFields : groupLevels) {
            List<String> parts = new List<String>();
            for (String field : levelFields) {
                String raw = getStringFieldValue(rec, field, fieldTypeMap);
                if (String.isNotBlank(raw)) { parts.add(toLabel(raw, picklistMaps.get(field))); }
            }
            String val = getValOrBlank(parts.isEmpty() ? null : String.join(parts, ' - '));
            if (!childrenByParentKey.containsKey(parentKey)) {
                childrenByParentKey.put(parentKey, new Set<String>());
            }
            childrenByParentKey.get(parentKey).add(val);
            parentKey = String.isBlank(parentKey) ? val : parentKey + SEPARATOR + val;
        }
        return parentKey;
    }

    private static void registerCell(GroupResult g, String rowKey, String colKey, String rawValStr, String valStr, String styleRawVal, SObject rec, List<HoverFieldConfig> hoverConfigs, Map<String, Map<String, String>> picklistMaps, Map<String, Schema.DisplayType> fieldTypeMap) {
        if (!g.cells.containsKey(rowKey)) {
            g.cells.put(rowKey, new Map<String, Map<String, CellData>>());
        }
        if (!g.cells.get(rowKey).containsKey(colKey)) {
            g.cells.get(rowKey).put(colKey, new Map<String, CellData>());
        }
        if (rawValStr != null && valStr != null && !g.cells.get(rowKey).get(colKey).containsKey(rawValStr)) {
            String hoverText = buildHoverText(rec, hoverConfigs, picklistMaps, fieldTypeMap);
            CellData cell = new CellData(rawValStr, valStr, hoverText);
            cell.styleRawValue = styleRawVal;
            g.cells.get(rowKey).get(colKey).put(rawValStr, cell);
        }
    }

    private static String buildHoverText(SObject rec, List<HoverFieldConfig> hoverConfigs, Map<String, Map<String, String>> picklistMaps, Map<String, Schema.DisplayType> fieldTypeMap) {
        if (hoverConfigs == null || hoverConfigs.isEmpty()) { return ''; }
        List<String> lines = new List<String>();
        for (HoverFieldConfig hf : hoverConfigs) {
            String raw   = getStringFieldValue(rec, hf.fieldPath, fieldTypeMap);
            String label = toLabel(raw, picklistMaps.get(hf.fieldPath));
            lines.add(hf.fieldLabel + ': ' + (label != null ? label : ''));
        }
        return String.join(lines, '\n');
    }

    private static List<ColNode> buildColTree(List<List<String>> colGroupLevels, Integer depth, String parentKey, Map<String, Set<String>> childrenByParentKey, List<String> columnKeys) {
        List<String> sorted = new List<String>(childrenByParentKey.get(parentKey) ?? new Set<String>());
        sorted.sort();
        List<ColNode> nodes = new List<ColNode>();
        Boolean isLeafLevel = (depth == colGroupLevels.size() - 1);
        for (String val : sorted) {
            String key = String.isBlank(parentKey) ? val : parentKey + SEPARATOR + val;
            if (isLeafLevel) {
                columnKeys.add(key);
                nodes.add(new ColNode(val, 1, true, key, null));
            }
            else {
                List<ColNode> children = buildColTree(colGroupLevels, depth + 1, key, childrenByParentKey, columnKeys);
                Integer totalColspan = 0;
                for (ColNode c : children) {
                    totalColspan += c.colspan;
                }
                nodes.add(new ColNode(val, totalColspan, false, null, children));
            }
        }
        return nodes;
    }

    private static List<RowNode> buildRowTree(List<List<String>> rowGroupLevels, Integer depth, String parentKey, Map<String, Set<String>> childrenByParentKey, List<String> columnKeys, Map<String, Map<String, Map<String, CellData>>> cells, StyleLookup styleLookup) {
        List<String> sorted = new List<String>(childrenByParentKey.get(parentKey) ?? new Set<String>());
        sorted.sort();
        List<RowNode> nodes = new List<RowNode>();
        Boolean isLeafLevel = (depth == rowGroupLevels.size() - 1);
        for (String val : sorted) {
            String key = String.isBlank(parentKey) ? val : parentKey + SEPARATOR + val;
            if (isLeafLevel) {
                nodes.add(new RowNode(val, 1, true, null, buildLeafValues(key, columnKeys, cells, styleLookup)));
            }
            else {
                List<RowNode> children = buildRowTree(rowGroupLevels, depth + 1, key, childrenByParentKey, columnKeys, cells, styleLookup);
                Integer totalRowspan = 0;
                for (RowNode c : children) {
                    totalRowspan += c.rowspan;
                }
                nodes.add(new RowNode(val, totalRowspan, false, children, null));
            }
        }
        return nodes;
    }

    private static List<CellData> buildLeafValues(String rowKey, List<String> columnKeys, Map<String, Map<String, Map<String, CellData>>> cells, StyleLookup styleLookup) {
        Map<String, Map<String, CellData>> colMap = cells.containsKey(rowKey) ? cells.get(rowKey) : new Map<String, Map<String, CellData>>();
        List<CellData> orderedValues = new List<CellData>();
        for (String ck : columnKeys) {
            List<CellData> vals = colMap.containsKey(ck) ? colMap.get(ck).values() : new List<CellData>();
            CellData cell = sortAndJoin(vals);
            cell.inlineStyle = resolveInlineStyle(cell.styleRawValue, styleLookup);
            orderedValues.add(cell);
        }
        return orderedValues;
    }

    private static String resolveInlineStyle(String styleRawValue, StyleLookup stylelookup) {
        if (String.isBlank(styleRawValue)) { return ''; }
        Set<String> distinctStyles = new Set<String>();
        for (String raw : styleRawValue.split('\n')) {
            distinctStyles.add(stylelookup.styleByRawValue.containsKey(raw) ? stylelookup.styleByRawValue.get(raw) : stylelookup.defaultStyle);
        }
        return (distinctStyles.size() == 1) ? new List<String>(distinctStyles)[0] : System.Label.Matrix_ConflictStyle;
    }

    private static CellData sortAndJoin(List<CellData> cellData) {
        if (cellData.isEmpty()) { return new CellData('', '', ''); }
        List<String> rawValsList      = new List<String>();
        List<String> valsList         = new List<String>();
        List<String> styleRawValsList = new List<String>();
        for (CellData cd : cellData) {
            rawValsList.add(cd.rawValue);
            valsList.add(cd.value);
            if (cd.styleRawValue != null) { styleRawValsList.add(cd.styleRawValue); }
        }
        rawValsList.sort();
        valsList.sort();
        styleRawValsList.sort();
        String firstRaw  = rawValsList[0];
        String hoverText = '';
        for (CellData cd : cellData) {
            if (cd.rawValue == firstRaw) { hoverText = cd.hoverText; break; }
        }
        String recordSeparator = valsList.size() > 1 ? '\n────────\n' : '\n';
        CellData joined = new CellData(String.join(rawValsList, '\n'), String.join(valsList, recordSeparator), hoverText);
        joined.styleRawValue = styleRawValsList.isEmpty() ? joined.rawValue : String.join(styleRawValsList, '\n');
        return joined;
    }

    private static Object getFieldValue(SObject record, List<String> fieldApiPath, Integer index) {
        if (record == null) { return null; }
        String segment = fieldApiPath[index];
        if (index == fieldApiPath.size() - 1) {
            return record.get(segment);
        }
        SObject child = record.getSObject(segment);
        return getFieldValue(child, fieldApiPath, index + 1);
    }

    private static String getStringFieldValue(SObject record, String fieldPath, Map<String, Schema.DisplayType> fieldTypeMap) {
        if (record == null || String.isBlank(fieldPath)) { return null; }
        Object raw = getFieldValue(record, fieldPath.split('\\.'), 0);
        if (raw == null) return null;
        Schema.DisplayType dt = fieldTypeMap?.get(fieldPath);
        return dt != null ? formatByFieldType(raw, dt) : String.valueOf(raw);
    }

    private static String formatByFieldType(Object val, Schema.DisplayType dt) {
        if (val == null) return null;
        switch on dt {
            when Date             { return String.valueOf((Date) val); }                           // YYYY-MM-DD
            when DateTime         { return ((DateTime) val).format('yyyy-MM-dd HH:mm'); }          // YYYY-MM-DD HH:MM (no seconds)
            when Double, Currency { return ((Decimal) val).stripTrailingZeros().toPlainString(); } // 1500 instead of 1500.0
            when Percent          { return ((Decimal) val).setScale(2).toPlainString() + '%'; }    // 15.35%
            when else             { return String.valueOf(val); }                                  // Other field types
        }
    }

    private static String getValOrBlank(String val) {
        return val != null ? val : Label.Matrix_Blank;
    }

    private static String toLabel(String val, Map<String, String> picklistMap) {
        if (val == null || picklistMap == null || picklistMap.isEmpty()) { return val; }
        return picklistMap.containsKey(val) ? picklistMap.get(val) : val;
    }

    private static DescribeFieldResult resolveFieldDescribe(String objectName, String fieldPath, Map<String, DescribeFieldResult> describeCache) {
        if (describeCache.containsKey(fieldPath)) {
            return describeCache.get(fieldPath);
        }
        DescribeFieldResult dfr = resolveFieldDescribeUncached(objectName, fieldPath);
        describeCache.put(fieldPath, dfr);
        return dfr;
    }

    private static DescribeFieldResult resolveFieldDescribeUncached(String objectName, String fieldPath) {
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

                String lookupFieldName = (segment.endsWith('__r')) ? segment.removeEnd('__r') + '__c' : segment + 'Id'; // Intermediate segment: relationship → resolve to lookup field → get referenced object
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

    private static String getFieldLabel(String objectName, String fieldPath, Map<String, DescribeFieldResult> describeCache) {
        DescribeFieldResult fieldDescribe = resolveFieldDescribe(objectName, fieldPath, describeCache);
        return fieldDescribe != null ? fieldDescribe.getLabel() : fieldPath;
    }

    // ------------------------------------ WRAPPERS ------------------------------------
    public class MatrixResult {
        @AuraEnabled public List<RowNode>      rowTree          { get; set; }
        @AuraEnabled public List<ColNode>      colTree          { get; set; }
        @AuraEnabled public List<String>       columnKeys       { get; set; }
        @AuraEnabled public List<String>       rowGroupLabels   { get; set; }
        @AuraEnabled public List<String>       colGroupLabels   { get; set; }
        @AuraEnabled public String             valueFieldLabel  { get; set; }
        @AuraEnabled public Boolean            allowExcelExport { get; set; }
        @AuraEnabled public Boolean            allowFilters     { get; set; }
        @AuraEnabled public String             filterRowsLabel  { get; set; }
        @AuraEnabled public List<FilterOption> filterOptions    { get; set; }
        @AuraEnabled public String             title            { get; set; }
        public MatrixResult(String title, Boolean allowExcelExport) {
            this.title              =   title;
            this.allowExcelExport   =   allowExcelExport;
            this.rowGroupLabels     =   new List<String>();
            this.colGroupLabels     =   new List<String>();
        }
    }

    public class FilterOption {
        @AuraEnabled public String            fieldPath  { get; set; }
        @AuraEnabled public String            fieldLabel { get; set; }
        @AuraEnabled public String            fieldType  { get; set; }
        @AuraEnabled public List<OptionEntry> options    { get; set; }
        public FilterOption(String fieldLabel, String fieldPath, String fieldType, List<OptionEntry> options) {
            this.fieldLabel =   fieldLabel;
            this.fieldPath  =   fieldPath;
            this.fieldType  =   fieldType;
            this.options    =   options;
        }
    }

    public class OptionEntry {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        public OptionEntry(String label, String value) {
            this.label  =   label;
            this.value  =   value;
        }
    }

    public class RowNode {
        @AuraEnabled public String         label    { get; set; }
        @AuraEnabled public Integer        rowspan  { get; set; }
        @AuraEnabled public Boolean        isLeaf   { get; set; }
        @AuraEnabled public List<RowNode>  children { get; set; }
        @AuraEnabled public List<CellData> values   { get; set; }
        public RowNode(String label, Integer rowspan, Boolean isLeaf, List<RowNode> children, List<CellData> values) {
            this.label      =   label;
            this.rowspan    =   rowspan;
            this.isLeaf     =   isLeaf;
            this.children   =   children;
            this.values     =   values;
        }
    }

    public class ColNode {
        @AuraEnabled public String        label    { get; set; }
        @AuraEnabled public Integer       colspan  { get; set; }
        @AuraEnabled public Boolean       isLeaf   { get; set; }
        @AuraEnabled public String        key      { get; set; }
        @AuraEnabled public List<ColNode> children { get; set; }
        public ColNode(String label, Integer colspan, Boolean isLeaf, String key, List<ColNode> children) {
            this.label      =   label;
            this.colspan    =   colspan;
            this.isLeaf     =   isLeaf;
            this.key        =   key;
            this.children   =   children;
        }
    }

    public class CellData {
        @AuraEnabled public String rawValue    { get; set; }
        @AuraEnabled public String value       { get; set; }
        @AuraEnabled public String inlineStyle { get; set; }
        @AuraEnabled public String hoverText   { get; set; }
        public String styleRawValue; // Internal only — raw value of the styled field for style resolution
        public CellData(String rawValue, String value, String hoverText) {
            this.rawValue       =   rawValue;
            this.value          =   value;
            this.inlineStyle    =   '';
            this.hoverText      =   hoverText != null ? hoverText : '';
            this.styleRawValue  =   rawValue; // Default: same as rawValue (single-value case)
        }
    }

    public class StyleLookup {
        Map<String, String> styleByRawValue = new Map<String, String>();
        String defaultStyle = '';
        String styledFieldPath = '';
    }

    public class FieldStyleConfig { // JSON deserialization wrappers for CellStyles__c
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

    private class GroupResult {
        Map<String, Set<String>> rowChildrenByParentKey = new Map<String, Set<String>>{ '' => new Set<String>() };
        Map<String, Set<String>> colChildrenByParentKey = new Map<String, Set<String>>{ '' => new Set<String>() };
        Map<String, Map<String, Map<String, CellData>>> cells = new Map<String, Map<String, Map<String, CellData>>>();
    }

    private class HoverFieldConfig {
        String fieldPath;
        String fieldLabel;
        HoverFieldConfig(String fieldPath, String fieldLabel) {
            this.fieldPath  =   fieldPath;
            this.fieldLabel =   fieldLabel;
        }
    }
}