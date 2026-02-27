/** ──────────────────────────────────────
 * @description Shared utility class for Grid Builder and Grid Validation components. 
 *              Provides common functionality for retrieving grid settings from custom metadata, filtering products 
 *              and share classes based on criteria, handling relationship paths, and formatting data for display. 
 *              Supports complex filter logic evaluation and dynamic field value extraction.
 * @author Charles EID
 * @testClass GridBuilderControllerTest, GridValidationControllerTest
 * @coverage 95% (Combined coverage from both test classes)
 ────────────────────────────────────── */
public with sharing class GridBuilderHelper {
    public static final String RT_STANDARD_GRID = 'StandardGrid';
    public static final String RT_CUSTOM_GRID = 'CustomGrid';
    public static final String RT_STANDARD_GRID_DETAIL = 'StandardGridDetail';
    public static final String RT_CUSTOM_GRID_DETAIL = 'CustomGridDetail';

    public static final String defaultAgreementSelectionMode = 'Single';
    public static final String defaultFilterValueSeparator = ';';
    public static final String defaultFilterLogic = 'AND';
    public static final Integer defaultMaxFilterDetails = 10;
    public static final String defaultFieldsToDisplay = 'Strategy__c => AssetClass__c\n'+
                                                        'Product__c => ProductName__c\n'+
                                                        'Share_Class__c => Name\n'+
                                                        'Share_Class__c => ISIN__c\n'+
                                                        'Share_Class__c => EffectiveManagementFees__c';
    public static final String defaultSortingFields = 'Strategy__c => AssetClass__c\n'+
                                                      'Product__c => ProductName__c\n'+
                                                      'Share_Class__c => ISIN__c';
    public static final String defaultFilterOperators = '=, !=, IN, NOT IN, LIKE, NOT {_} LIKE';
    private static final String REBATE_RATE_FIELD_KEY = 'RebateRate';
    public static GridSettings getGridSettings(String gridBuilderSettingName, String countriesOfDistribution, Boolean includeFilterObjects) {
        GridBuilderSetting__mdt gridSetting = loadGridBuilderSetting(gridBuilderSettingName);
        if (gridSetting == null) {
            return null;
        }
        GridSettings settings = buildGridSettings(gridSetting);
        settings.filterObjects = includeFilterObjects? buildFilterObjectWrappers(gridSetting.GridCriteriaSettings__r, countriesOfDistribution, settings.shareTypeWrp) : null;
        return settings;
    }

    private static GridBuilderSetting__mdt loadGridBuilderSetting(String gridBuilderSettingName) {
        List<GridBuilderSetting__mdt> gridSetting = [SELECT Id, (SELECT Id, DeveloperName, ObjectApiName__c, FieldApiNames__c, SortOrder__c, AllowedOperators__c
                                                                FROM GridCriteriaSettings__r
                                                                WHERE IsActive__c = true
                                                                ORDER BY SortOrder__c ASC LIMIT 10), FilterLimit__c, FilterDefaultLogic__c, FilterValueSeparator__c,
                                                                    AllShareTypeOptions__c, DefaultShareTypeInclusion__c, DefinitiveShareTypeExclusion__c,
                                                                    FieldsToDisplay__c, DefaultSortFields__c, AgreementSelectionMode__c, AgreementQueryConditions__c
                                                     FROM GridBuilderSetting__mdt
                                                     WHERE DeveloperName = :gridBuilderSettingName LIMIT 1];
        if (gridSetting == null || gridSetting.isEmpty()) {
            return null;
        }
        return gridSetting[0];
    }

    private static GridSettings buildGridSettings(GridBuilderSetting__mdt gridSetting) {
        String agreementSelectionMode   =   (String.isNotBlank(gridSetting.AgreementSelectionMode__c))? gridSetting.AgreementSelectionMode__c : defaultAgreementSelectionMode;
        String agreementQueryConditions =   (String.isNotBlank(gridSetting.AgreementQueryConditions__c))? gridSetting.AgreementQueryConditions__c : '';
        Integer filterLimit             =   gridSetting.FilterLimit__c != null ? Integer.valueOf(gridSetting.FilterLimit__c) : defaultMaxFilterDetails;
        String onLoadFilterLogic        =   (String.isNotBlank(gridSetting.FilterDefaultLogic__c)) ? gridSetting.FilterDefaultLogic__c : defaultFilterLogic;
        String filterValueSeparator     =   (String.isNotBlank(gridSetting.FilterValueSeparator__c)) ? ' ' + gridSetting.FilterValueSeparator__c + ' ' : defaultFilterValueSeparator;
        String allShareTypes            =   (String.isNotBlank(gridSetting.AllShareTypeOptions__c)) ? gridSetting.AllShareTypeOptions__c : '';
        String shareTypeInclusion       =   (String.isNotBlank(gridSetting.DefaultShareTypeInclusion__c)) ? gridSetting.DefaultShareTypeInclusion__c : '';
        String shareTypeExclusion       =   (String.isNotBlank(gridSetting.DefinitiveShareTypeExclusion__c)) ? gridSetting.DefinitiveShareTypeExclusion__c : '';
        String fieldsToDisplay          =   (String.isNotBlank(gridSetting.FieldsToDisplay__c)) ? gridSetting.FieldsToDisplay__c : defaultFieldsToDisplay;
        String sortingFields            =   (String.isNotBlank(gridSetting.DefaultSortFields__c)) ? gridSetting.DefaultSortFields__c : defaultSortingFields;
        return new GridSettings(agreementSelectionMode, agreementQueryConditions, filterLimit, onLoadFilterLogic, filterValueSeparator, allShareTypes, shareTypeInclusion, shareTypeExclusion, fieldsToDisplay, sortingFields);
    }

    private static List<FilterObjectWrapper> buildFilterObjectWrappers(List<GridCriteriaSetting__mdt> criteriaSettings, String countriesOfDistribution, ShareTypeWrapper shareTypeWrp) {
        String objectsToFieldsString = '';
        for (GridCriteriaSetting__mdt criteriaSetting : criteriaSettings) {
            if(criteriaSetting.FieldApiNames__c != null) {
                for (String fieldApiName : criteriaSetting.FieldApiNames__c.split(',')) {
                    objectsToFieldsString += criteriaSetting.ObjectApiName__c + ' => ' + fieldApiName.trim() + '\n';
                }
            }
        }
        Map<String, Map<String, Map<String, String>>> objectToFieldToValuesMap = getMapObjectToFieldToValues(buildFieldsApiToInfoMap(objectsToFieldsString, false), countriesOfDistribution, shareTypeWrp);
        List<FilterObjectWrapper> filterObjects = new List<FilterObjectWrapper>();
        for (GridCriteriaSetting__mdt criteriaSetting : criteriaSettings) {
            if(criteriaSetting.FieldApiNames__c != null) {
                filterObjects.add(new FilterObjectWrapper(criteriaSetting, objectToFieldToValuesMap.get(criteriaSetting.ObjectApiName__c)));
            }
        }
        return filterObjects;
    }

    private static List<Map<String, String>> getFilterLogics() {
        List<Map<String, String>> logics = new List<Map<String, String>>();
        for (Schema.PicklistEntry entry : GridCriteria__c.FilterLogic__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                logics.add(new Map<String, String>{'label' => entry.getLabel(), 'value' => entry.getValue()});
            }
        }
        return logics;
    }

    private static List<FilterFieldWrapper> getFields(GridCriteriaSetting__mdt criteriaSetting, Map<String, Map<String, String>> mapFieldToValues) {
        String objectApiName = criteriaSetting.ObjectApiName__c;
        List<String> fieldApiNames = criteriaSetting.FieldApiNames__c.remove(' ').split(',');
        List<String> allowedOperators = stringToList(criteriaSetting.AllowedOperators__c, ',');
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();

        List<FilterFieldWrapper> result = new List<FilterFieldWrapper>();
        String fieldLabel;
        Schema.DisplayType type;
        Map<String, String> ops, fieldValsAvl;
        for (String fieldApiName : fieldApiNames) {
            if (fieldMap.containsKey(fieldApiName)) {
                Schema.DescribeFieldResult f = fieldMap.get(fieldApiName).getDescribe();
                fieldLabel = f.getLabel();
                type = f.getType();
                fieldValsAvl = mapFieldToValues.containsKey(fieldApiName)? mapFieldToValues.get(fieldApiName) : new Map<String, String>();
                ops = buildOperatorsForType(type, allowedOperators);

                result.add(new FilterFieldWrapper(fieldLabel, fieldApiName, type, fieldValsAvl, ops));
            }
        }
        return result;
    }

    private static Map<String, Map<String, Map<String, String>>> getMapObjectToFieldToValues(Map<String, FieldInfo> fieldsApiToInfoMap, String countriesOfDistribution, ShareTypeWrapper shareTypeWrp) {
        String whereClause = String.join(buildDefaultConditions(true, true, countriesOfDistribution, shareTypeWrp, false), ' AND ');
        String query = 'SELECT Id, ' + String.join(fieldsApiToInfoMap.keySet(), ', ') + 
                      ' FROM Share_Class__c ';
        query += String.isNotBlank(whereClause)? ' WHERE ' + whereClause : '';
        String objectFieldKey;
        Map<String, List<String>> mapObjectFieldToValuesInList = new Map<String, List<String>>();
        for(SObject rec : Database.query(query)) {
            for(String selectField : fieldsApiToInfoMap.keySet()) {
                objectFieldKey = fieldsApiToInfoMap.get(selectField).objectApiName + '_-_' + fieldsApiToInfoMap.get(selectField).fieldApiName;
                if(!mapObjectFieldToValuesInList.containsKey(objectFieldKey)) {
                    mapObjectFieldToValuesInList.put(objectFieldKey, new List<String>());
                }
                mapObjectFieldToValuesInList.get(objectFieldKey).add((String) getFieldValue(rec, selectField.split('\\.'), 0));
            }
        }
        Map<String, Map<String, Map<String, String>>> mapObjectToFieldToValues = new Map<String, Map<String, Map<String, String>>>();
        Map<String, Map<String, String>> mapFieldToValues = new Map<String, Map<String, String>>();
        String objectApiName, fieldApiName;
        for(String objectField : mapObjectFieldToValuesInList.keySet()) {
            objectApiName = objectField.split('_-_')[0];
            fieldApiName = objectField.split('_-_')[1];
            if(!mapObjectToFieldToValues.containsKey(objectApiName)) {
                mapObjectToFieldToValues.put(objectApiName, new Map<String, Map<String, String>>());
            }
            mapObjectFieldToValuesInList.get(objectField).sort();
            for(String value : mapObjectFieldToValuesInList.get(objectField)) {
                if(!mapFieldToValues.containsKey(fieldApiName)) {
                    mapFieldToValues.put(fieldApiName, new Map<String, String>());
                }
                mapFieldToValues.get(fieldApiName).put(value, value);
            }
            mapObjectToFieldToValues.get(objectApiName).put(fieldApiName, mapFieldToValues.get(fieldApiName));
        }
        return mapObjectToFieldToValues;
    }

    private static Map<String, String> buildOperatorsForType(Schema.DisplayType type, List<String> allowedOperators) {
        Set<String> inOps = new Set<String>{ 'IN', 'NOT IN' };
        Set<String> compareOps = new Set<String>{ '>', '>=', '<', '<=' };
        Set<String> likeOps = new Set<String>{ 'LIKE', 'NOT {_} LIKE' };
        
        Boolean isInType = type == Schema.DisplayType.String || type == Schema.DisplayType.Picklist || type == Schema.DisplayType.MultiPicklist || type == Schema.DisplayType.Id;
        Boolean isCompareType = type == Schema.DisplayType.Date || type == Schema.DisplayType.DateTime || type == Schema.DisplayType.Double || type == Schema.DisplayType.Integer || type == Schema.DisplayType.Currency;
        Boolean isStringType = type == Schema.DisplayType.String;

        Map<String, String> ops = new Map<String, String>();
        for (Schema.PicklistEntry entry : GridCriteriaDetail__c.Logic__c.getDescribe().getPicklistValues()) {
            if (entry.isActive() && allowedOperators.contains(entry.getValue())) {
                String op = entry.getValue();
                Boolean allow = true;
                if (inOps.contains(op)) {
                    allow = isInType;
                }
                else if (compareOps.contains(op)) {
                    allow = isCompareType;
                }
                else if (likeOps.contains(op)) {
                    allow = isStringType;
                }
                if (allow) {
                    ops.put(entry.getLabel(), op);
                }
            }
        }
        return ops;
    }

    public static Map<String, FieldInfo> buildFieldsApiToInfoMap(String objectsToFieldsString, Boolean includeRebateRate) {
        Map<String, Map<String, Schema.SObjectField>> objectToFieldsMap = new Map<String, Map<String, Schema.SObjectField>>();
        Map<String, FieldInfo> fieldsApiToInfoMap = new Map<String, FieldInfo>();
        for (String line : objectsToFieldsString.split('\n')) {
            buildFieldsApiInfoMapFromLine(line, objectToFieldsMap, fieldsApiToInfoMap);
        }
        if(includeRebateRate) {
            Schema.DescribeFieldResult rebateDFR = GridDetail__c.RebateRate__c.getDescribe();
            fieldsApiToInfoMap.put(REBATE_RATE_FIELD_KEY, new FieldInfo(rebateDFR.getLabel(), rebateDFR.getType(), false, rebateDFR.getName(), 'GridDetail__c'));
        }
        return fieldsApiToInfoMap;
    }

    public static void buildFieldsApiInfoMapFromLine(String line, Map<String, Map<String, Schema.SObjectField>> objectToFieldsMap, Map<String, FieldInfo> fieldsApiToInfoMap) {
        if (String.isBlank(line) || !line.contains('=>')) {
            return;
        }
        List<String> parts = line.split('=>');
        if (parts.size() < 2) {
            return;
        }
        String objectApi = parts[0].trim();
        String fieldApi = parts[1].trim();
        if (String.isBlank(objectApi) || String.isBlank(fieldApi) || !Schema.getGlobalDescribe().containsKey(objectApi)) {
            return;
        }
        if (!objectToFieldsMap.containsKey(objectApi)) {
            objectToFieldsMap.put(objectApi, Schema.getGlobalDescribe().get(objectApi).getDescribe().fields.getMap());
        }
        Map<String, Schema.SObjectField> fieldMap = objectToFieldsMap.get(objectApi);
        if (!fieldMap.containsKey(fieldApi)) {
            return;
        }
        Schema.DescribeFieldResult describeFieldResult = fieldMap.get(fieldApi).getDescribe();
        String relationshipFieldPath = getRelationshipPath(objectApi) + fieldApi;
        if (!fieldsApiToInfoMap.containsKey(relationshipFieldPath)) {
            fieldsApiToInfoMap.put(relationshipFieldPath, new FieldInfo(describeFieldResult.getLabel(), describeFieldResult.getType(), describeFieldResult.isSortable(), fieldApi, objectApi));
        }
    }

    public static String getRelationshipPath(String objectApiName) {
        return (objectApiName == 'Share_Class__c')? '' : 
               (objectApiName == 'Product__c')? 'Fund__r.' :
               (objectApiName == 'Strategy__c')? 'Fund__r.FundStrategy__r.' : '';
    }

    public static Map<String, Object> buildRecordResults(Set<String> selectFieldsApiSet, Share_Class__c sc, Map<Id, StandardGridDetailInfo> stdGridDetailInfoByShareClass) {
        Map<String, Object> recordResults = new Map<String, Object>();
        for(String field : selectFieldsApiSet) {
            recordResults.put(field, getFieldValue(sc, field.split('\\.'), 0));
        }
        if (stdGridDetailInfoByShareClass != null && sc != null && stdGridDetailInfoByShareClass.containsKey(sc.Id)) {
            recordResults.put(REBATE_RATE_FIELD_KEY, stdGridDetailInfoByShareClass.get(sc.Id).formatted);
        }
        return recordResults;
    }

    public static Object getFieldValue(SObject record, List<String> fieldApiPath, Integer index) {
        if (record == null) {
            return null;
        }
        
        String segment = fieldApiPath[index];
        Object value;
        if (index == fieldApiPath.size() - 1) { // Last segment → normal field
            value = record.get(segment);
            value = (record.getSObjectType() == Schema.Share_Class__c.getSObjectType() && segment == 'EffectiveManagementFees__c') ? formatPercent((Decimal)value) : value;
            return value;
        }

        SObject child = record.getSObject(segment); // Intermediate segment → relationship
        return getFieldValue(child, fieldApiPath, index + 1);
    }

    public static ProductSelectionResult buildProductSelectionResult(String gridBuilderSettingName, String countriesOfDistribution, GridSettings gridSettings, Map<String, FieldInfo> fieldsApiToInfoMap, Set<Id> filteredIds, String finalWhere, Map<Id, String> aumByShareClass, Boolean onlyIncludeSCInAgreement, Map<String, String> shareClassGridIdMap, Boolean includeRebateRate) {
        gridSettings = gridSettings != null? gridSettings : getGridSettings(gridBuilderSettingName, countriesOfDistribution, false);
        fieldsApiToInfoMap = fieldsApiToInfoMap != null? fieldsApiToInfoMap : buildFieldsApiToInfoMap(gridSettings.fieldsToDisplay + getAdditionalQueryColumns(), includeRebateRate);

        Set<String> selectFields = new Set<String>{'Id', 'Fund__c', 'Fund__r.ProductName__c', 'Fund__r.InternalShortName__c'};
        selectFields.addAll(getSelectableFieldSet(fieldsApiToInfoMap));
        finalWhere = String.isNotBlank(finalWhere)? finalWhere : String.join(buildDefaultConditions(true, true, countriesOfDistribution, gridSettings.shareTypeWrp, false), ' AND ');
        String finalOrderBy = buildOrderByClause(gridSettings.sortingFields);

        String allQuery = 'SELECT ' + String.join(new List<String>(selectFields), ', ') + 
                         ' FROM Share_Class__c';
        allQuery += (String.isNotBlank(finalWhere)) ? ' WHERE ' + finalWhere : '';
        allQuery += (String.isNotBlank(finalOrderBy)) ? ' ORDER BY ' + finalOrderBy : '';
        System.debug('@@@ allQuery: ' + allQuery);

        List<Share_Class__c> shareClasses = Database.query(allQuery);
        Map<Id, StandardGridDetailInfo> rebateByShareClass = (includeRebateRate && shareClassGridIdMap != null)? buildStandardGridDetailInfoByShareClass(shareClassGridIdMap) : null;
        List<ProductWrapper> productWrapperList = buildProductIdToWrapper(shareClasses, filteredIds, fieldsApiToInfoMap, aumByShareClass, onlyIncludeSCInAgreement, rebateByShareClass);
        return new ProductSelectionResult(fieldsApiToInfoMap, productWrapperList);
    }

    private static List<ProductWrapper> buildProductIdToWrapper(List<Share_Class__c> shareClasses, Set<Id> filteredIds, Map<String, FieldInfo> fieldsApiToInfoMap, Map<Id, String> aumByShareClass, Boolean onlyIncludeSCInAgreement, Map<Id, StandardGridDetailInfo> rebateByShareClass) {
        Map<Id, ProductWrapper> productIdToWrapper = new Map<Id, ProductWrapper>();
        Id prodId;
        String productLabel;
        for (Share_Class__c sc : shareClasses) {
            prodId = (Id)sc.get('Fund__c');
            if ((onlyIncludeSCInAgreement && aumByShareClass.containsKey(sc.Id) || !onlyIncludeSCInAgreement || filteredIds.contains(sc.Id))) {
                if (!productIdToWrapper.containsKey(prodId)) {
                    productLabel = (String)sc.getSObject('Fund__r')?.get('ProductName__c')+' ('+(String)sc.getSObject('Fund__r')?.get('InternalShortName__c')+')';
                    productLabel = String.isNotBlank(productLabel) ? productLabel : 'Unnamed Product. Internal Short Name: ' + (String)sc.getSObject('Fund__r')?.get('InternalShortName__c');
                    productIdToWrapper.put(prodId, new ProductWrapper(prodId, productLabel));
                }
                productIdToWrapper.get(prodId).shareClasses.add(new ShareClassWrapper(sc, filteredIds, fieldsApiToInfoMap, aumByShareClass, rebateByShareClass));
            }
        }
        return productIdToWrapper.values();
    }

    public static Set<String> getSelectableFieldSet(Map<String, FieldInfo> fieldsApiToInfoMap) {
        Set<String> selectFields = new Set<String>();
        for (String fieldKey : fieldsApiToInfoMap.keySet()) {
            if (fieldKey != REBATE_RATE_FIELD_KEY) {
                selectFields.add(fieldKey);
            }
        }
        return selectFields;
    }

    public static Map<Id, StandardGridDetailInfo> buildStandardGridDetailInfoByShareClass(Map<String, String> shareClassGridIdMap) {
        Set<Id> shareClassIds = new Set<Id>();
        Set<Id> gridIds = new Set<Id>();
        for (String shareClassId : shareClassGridIdMap.keySet()) {
            shareClassIds.add((Id)shareClassId);
            gridIds.add((Id)shareClassGridIdMap.get(shareClassId));
        }

        Map<Id, StandardGridDetailInfo> stdGridDetailInfoByShareClass = new Map<Id, StandardGridDetailInfo>();
        String standardGridRT = RT_STANDARD_GRID;
        for (GridDetail__c detail : [SELECT Id, ShareClass__c, Grid__c, RebateRate__c, StartDate__c, CreatedDate
                                     FROM GridDetail__c
                                     WHERE ShareClass__c IN :shareClassIds
                                     AND Grid__c IN :gridIds
                                     AND RebateRate__c != null
                                     AND Grid__r.RecordType.DeveloperName = :standardGridRT
                                     ORDER BY Grid__c, ShareClass__c, StartDate__c DESC, CreatedDate DESC]) {
            if (!stdGridDetailInfoByShareClass.containsKey(detail.ShareClass__c) && shareClassGridIdMap.get(detail.ShareClass__c) == detail.Grid__c) {
                stdGridDetailInfoByShareClass.put(detail.ShareClass__c, new StandardGridDetailInfo(detail.Id, detail.RebateRate__c, formatPercent(detail.RebateRate__c)));
            }
        }
        return stdGridDetailInfoByShareClass;
    }

    public static String formatDecimal(Decimal value) {
        if (value == null) {
            return null;
        }
        Decimal scaled = value.setScale(2, RoundingMode.HALF_UP);
        return scaled.format();
    }

    public static String formatAum(Decimal totalAum) {
        if (totalAum == null) {
            return '0';
        }
        Decimal scaled = totalAum >= 100000 ? totalAum.setScale(0) : totalAum.setScale(2, RoundingMode.HALF_UP);
        return scaled.format();
    }

    public static String formatPercent(Decimal value) {
        if (value == null) {
            return null;
        }
        return formatDecimal(value) + '%';
    }

    public static List<String> buildDefaultConditions(Boolean excludeJPY, Boolean onlyAddSharesFromRegisteredCountries, String countriesOfDistribution, ShareTypeWrapper shareTypeWrp, Boolean alwaysIncludeDefaultShareTypeInclusion) {
        List<String> whereFragments = new List<String>();
        whereFragments.add('Fund__c != null');
        whereFragments.add('Fund__r.FundStrategy__c != null');
        if(excludeJPY) {
            whereFragments.add('Currency__c != \'JPY\'');
        }
        if(String.isNotBlank(countriesOfDistribution) && onlyAddSharesFromRegisteredCountries) {
            whereFragments.add(getRegisteredCountriesCondition(countriesOfDistribution));
        }
        if(String.isNotBlank(shareTypeWrp.defaultShareTypeInclusion) && alwaysIncludeDefaultShareTypeInclusion) {
            whereFragments.add('(Type__c IN '+ toSoqlInListLiteral(shareTypeWrp.defaultShareTypeInclusion, ',') +' OR Type__c = null)');
        }
        if(String.isNotBlank(shareTypeWrp.definitiveShareTypeExclusion)) {
            whereFragments.add('(Type__c NOT IN '+ toSoqlInListLiteral(shareTypeWrp.definitiveShareTypeExclusion, ',')+')');
        }
        return whereFragments;
    }

    public static String toSoqlInListLiteral(String raw, String separator) {
        String valuesInListLiteral = '';
        if(String.isNotBlank(raw)) {
            List<String> quoted = new List<String>();
            for (String token : raw.split(separator)) {
                quoted.add('\'' + String.escapeSingleQuotes(token).trim() + '\'');
            }
            if (!quoted.isEmpty()) {
                valuesInListLiteral = '(' + String.join(quoted, ',') + ')';
            }
        }
        return valuesInListLiteral;
    }

    public static String buildOrderByClause(String sortingFields) {
        Map<String, String> orderByMap = new Map<String, String>();
        String appendOrderWith;
        Schema.DisplayType fieldType;
        Map<String, FieldInfo> fieldsApiToInfoMap = buildFieldsApiToInfoMap(sortingFields, false);
        for (String field : fieldsApiToInfoMap.keySet()) {
            if(fieldsApiToInfoMap.get(field).isSortable && !orderByMap.containsKey(field)) {
                fieldType = fieldsApiToInfoMap.get(field).type;
                appendOrderWith = fieldType == Schema.DisplayType.Picklist || fieldType == Schema.DisplayType.MultiPicklist ? ' DESC ' : ' NULLS LAST ';
                orderByMap.put(field, field + appendOrderWith);
            }
        }
        return String.join(orderByMap.values(), ',');
    }

    private static ShareTypeWrapper buildShareTypeWrapper(String allShareTypes, String defaultShareTypeInclusion, String definitiveShareTypeExclusion) {
        List<Map<String, String>> allShareTypeOptions = new List<Map<String, String>>();
        List<String> defaultShareTypeValues = new List<String>();
        List<String> allShareTypesList = stringToList(allShareTypes, ',');
        List<String> defaultShareTypeInclusionList = stringToList(defaultShareTypeInclusion, ',');
        List<String> definitiveShareTypeExclusionList = stringToList(definitiveShareTypeExclusion, ',');

        for (Schema.PicklistEntry entry : Share_Class__c.Type__c.getDescribe().getPicklistValues()) {
            if (entry.isActive() && !definitiveShareTypeExclusionList.contains(entry.getValue().toUpperCase()) && allShareTypesList.contains(entry.getValue().toUpperCase())) {
                allShareTypeOptions.add(new Map<String, String>{'label' => entry.getLabel(), 'value' => entry.getValue()});
                if(defaultShareTypeInclusionList.contains(entry.getValue())) {
                    defaultShareTypeValues.add(entry.getValue());
                }
            }
        }

        return new ShareTypeWrapper(defaultShareTypeInclusion, definitiveShareTypeExclusion, allShareTypeOptions, defaultShareTypeValues);
    }

    public static List<String> stringToList(String str, String separator) {
        List<String> listVals = new List<String>();
        if(String.isNotBlank(str)) {
            for(String val : str.toUpperCase().split(separator)) {
                listVals.add(val.trim());
            }
        }
        return listVals;
    }

    private static String getRegisteredCountriesCondition(String countriesOfDistribution) {
        String countriesInListLiteral = toSoqlInListLiteral(countriesOfDistribution, ';');
        String condition = String.isNotBlank(countriesInListLiteral) ? 'Id IN (SELECT ShareClass__c FROM Country__c WHERE RegistrationStatus__c = \'REG\' and ShareClass__c != null AND Country__c IN '+countriesInListLiteral+')' : '';
        return condition;
    }

    public static String getAdditionalQueryColumns() {
        return '\nShare_Class__c => ISIN__c' +
        '\nShare_Class__c => EffectiveManagementFees__c';
    }

    // ────────────────────────────────────── WRAPPERS ──────────────────────────────────────
    public class GridSettings {
        @AuraEnabled public String agreementSelectionMode { get; set; }
        @AuraEnabled public String agreementQueryConditions { get; set; }
        @AuraEnabled public List<FilterObjectWrapper> filterObjects { get; set; }
        @AuraEnabled public Integer filterLimit { get; set; }
        @AuraEnabled public List<Map<String, String>> filterLogics { get; set; }
        @AuraEnabled public String onLoadFilterLogic { get; set; }
        @AuraEnabled public String filterValueSeparator { get; set; }
        @AuraEnabled public String fieldsToDisplay { get; set; }
        @AuraEnabled public String sortingFields { get; set; }
        @AuraEnabled public ShareTypeWrapper shareTypeWrp { get; set; }
        public GridSettings(String agrSelectionMode, String agrQueryConditions, Integer filterLimit, String filterLogic, String filterValueSeparator, String allShareTypes, String dfltShareTypeInclusion, String defShareTypeExclusion, String fieldsToDisplay, String sortingFields) {
            this.agreementSelectionMode     =   agrSelectionMode;
            this.agreementQueryConditions   =   agrQueryConditions;
            this.filterLimit                =   filterLimit;
            this.filterLogics               =   getFilterLogics();
            this.onLoadFilterLogic          =   filterLogic;
            this.filterValueSeparator       =   filterValueSeparator;
            this.shareTypeWrp               =   buildShareTypeWrapper(allShareTypes, dfltShareTypeInclusion, defShareTypeExclusion);
            this.fieldsToDisplay            =   fieldsToDisplay;
            this.sortingFields              =   sortingFields;
        }
    }

    public class ShareTypeWrapper {
        @AuraEnabled public String defaultShareTypeInclusion { get; set; }
        @AuraEnabled public String definitiveShareTypeExclusion { get; set; }
        @AuraEnabled public List<Map<String, String>> allShareTypeOptions { get; set; }
        @AuraEnabled public List<String> defaultShareTypeValues { get; set; }
        public ShareTypeWrapper(String dfltShareTypeInclusion, String defShareTypeExclusion, List<Map<String, String>> allShareTypeOptions, List<String> defaultShareTypeValues) {
            this.defaultShareTypeInclusion      =   dfltShareTypeInclusion;
            this.definitiveShareTypeExclusion   =   defShareTypeExclusion;
            this.allShareTypeOptions            =   allShareTypeOptions;
            this.defaultShareTypeValues         =   defaultShareTypeValues;
        }
    }

    public class FilterObjectWrapper {
        @AuraEnabled public String objectLabel { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public List<FilterFieldWrapper> fields { get; set; }
        public FilterObjectWrapper(GridCriteriaSetting__mdt criteriaSetting, Map<String, Map<String, String>> mapFieldToValues) {
            this.objectLabel    =   Schema.getGlobalDescribe().get(criteriaSetting.ObjectApiName__c).getDescribe().getLabel();
            this.objectApiName  =   criteriaSetting.ObjectApiName__c;
            this.fields         =   getFields(criteriaSetting, mapFieldToValues);
        }
    }

    public class FilterFieldWrapper {
        @AuraEnabled public String fieldLabel { get; set; }
        @AuraEnabled public String fieldApiName { get; set; }
        @AuraEnabled public String fieldType { get; set; }
        @AuraEnabled public Map<String, String> fieldValuesAvailable { get; set; }
        @AuraEnabled public Map<String, String> operators { get; set; }
        public FilterFieldWrapper(String fieldLabel, String fieldApiName, Schema.DisplayType displayType, Map<String, String> fieldValuesAvailable, Map<String, String> operators) {
            this.fieldLabel             =   fieldLabel;
            this.fieldApiName           =   fieldApiName;
            this.fieldType              =   String.valueOf(displayType);
            this.fieldValuesAvailable   =   fieldValuesAvailable;
            this.operators              =   operators;
        }
    }

    public class FieldInfo {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Schema.DisplayType type { get; set; }
        @AuraEnabled public Boolean isSortable { get; set; }
        @AuraEnabled public String fieldApiName { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        public FieldInfo(String label, Schema.DisplayType type, Boolean isSortable, String fieldApiName, String objectApiName) {
            this.label          =   label;
            this.type           =   type;
            this.isSortable     =   isSortable;
            this.fieldApiName   =   fieldApiName;
            this.objectApiName  =   objectApiName;
        }
    }

    public class ProductSelectionResult {
        @AuraEnabled public Map<String, FieldInfo> fieldsApiToInfoMap { get; set; }
        @AuraEnabled public List<ProductWrapper> products { get; set; }
        public ProductSelectionResult(Map<String, FieldInfo> fieldsApiToInfoMap, List<ProductWrapper> products) {
            this.fieldsApiToInfoMap     =   fieldsApiToInfoMap;
            this.products               =   products;
            this.products.sort(new ProductNameComparator());
        }
    }

    public class ProductWrapper {
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public String productLabel { get; set; }
        @AuraEnabled public List<ShareClassWrapper> shareClasses { get; set; }
        public ProductWrapper(Id productId, String productLabel) {
            this.productId      =   productId;
            this.productLabel   =   productLabel;
            this.shareClasses   =   new List<ShareClassWrapper>();
        }
    }

    public class ShareClassWrapper {
        @AuraEnabled public Id shareClassId { get; set; }
        @AuraEnabled public Boolean isSelected { get; set; }
        @AuraEnabled public Map<String, Object> recordResults { get; set; }
        @AuraEnabled public String amountAUM { get; set; }
        public ShareClassWrapper(Share_Class__c sc, Set<Id> selectedShareClassIds, Map<String, FieldInfo> fieldsApiToInfoMap, Map<Id, String> aumByShareClass, Map<Id, StandardGridDetailInfo> rebateByShareClass) {
            this.shareClassId   =   sc.Id;
            this.isSelected     =   selectedShareClassIds.contains(sc.Id);
            this.recordResults  =   buildRecordResults(getSelectableFieldSet(fieldsApiToInfoMap), sc, rebateByShareClass);
            this.amountAUM      =   (aumByShareClass != null && aumByShareClass.containsKey(sc.Id)) ? aumByShareClass.get(sc.Id) : '0';
        }
    }

    public class ProductNameComparator implements Comparator<ProductWrapper> {
        public Integer compare(ProductWrapper a, ProductWrapper b) {
            String aName = a.productLabel != null ? a.productLabel : '';
            String bName = b.productLabel != null ? b.productLabel : '';
            return aName.compareTo(bName);
        }
    }

    public class StandardGridDetailInfo {
        public Id gridDetailId      { get; set; }
        public Decimal value        { get; set; }
        public String  formatted    { get; set; }
        public StandardGridDetailInfo(Id gridDetailId, Decimal value, String formatted) {
            this.gridDetailId = gridDetailId;
            this.value        = value;
            this.formatted    = formatted;
        }
    }
}