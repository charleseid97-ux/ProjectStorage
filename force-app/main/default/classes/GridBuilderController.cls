/** ──────────────────────────────────────
 * @description Lightning Web Component controller for the Grid Builder interface. 
 *              Provides methods for retrieving grid settings, available grids, products, 
 *                  share classes, and agreement selection page configuration. 
 *              Works in conjunction with GridBuilderHelper for data filtering and formatting.
 * @author Charles EID
 * @testClass GridBuilderControllerTest
 * @coverage 85%   [19-03-26]
 ────────────────────────────────────── */
public with sharing class GridBuilderController {

    @AuraEnabled(cacheable=true)
    public static GridBuilderHelper.GridSettings getGridSettings(String gridBuilderSettingName, String countriesOfDistribution, List<String> availableGridIds) {
        return GridBuilderHelper.getGridSettings(gridBuilderSettingName, countriesOfDistribution, true, availableGridIds);
    }

    @AuraEnabled(cacheable=true)
    public static AgreementSelectionPageSettings getAgreementSelectionPageSettings(String gridBuilderSettingName, String agreementId) {
        GridBuilderHelper.GridSettings gridSettings = GridBuilderHelper.getGridSettings(gridBuilderSettingName, null, false, new List<String>());

        String userPrimaryTeam = '';
        List<String> userSecondaryTeams = new List<String>();
        User usr = [SELECT Id, Team__c, Secondary_Teams__c 
                    FROM User 
                    WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if(String.isNotBlank(usr.Team__c)) {
            userPrimaryTeam = usr.Team__c;
        }
        if(String.isNotBlank(usr.Secondary_Teams__c)) {
            userSecondaryTeams.addAll(usr.Secondary_Teams__c.split(';'));
        }

        String agreementWhere = buildAgreementWhereClause(agreementId, userPrimaryTeam, userSecondaryTeams, gridSettings?.agreementQueryConditions);
        String agreementQuery = 'SELECT Id, ConventionName__c, Name, Team__c, Countries_of_Distribution__c, Business_Region__c, Grid__c, Grid__r.Kind__c, Grid__r.EndDate__c, Grid_Request__c, Grid_Request__r.ApprovalStatus__c '+
                                ' FROM Convention__c ';
        agreementQuery +=       ' WHERE ' + agreementWhere;
        agreementQuery +=       ' ORDER BY ConventionName__c ASC, Name ASC, Team__c ASC LIMIT 5000';

        List<AgreementWrapper> agreementOptions = new List<AgreementWrapper>();
        Set<String> availableTeams = new Set<String>();
        Boolean hasExistingGrid = false;
        String  existingGridKind    = null;
        String  existingGridEndDate = null;
        Boolean hasDraftGrid = false;
        for (Convention__c agreement : Database.query(agreementQuery)) {
            agreementOptions.add(new AgreementWrapper(agreement));
            availableTeams.add(agreement.Team__c);
            if (String.isNotBlank(agreementId) && agreement.Id == agreementId) {
                if (agreement.Grid__c != null) {
                    hasExistingGrid     = true;
                    existingGridKind    = agreement.Grid__r.Kind__c;
                    existingGridEndDate = agreement.Grid__r.EndDate__c != null ? String.valueOf(agreement.Grid__r.EndDate__c) : null;
                }
                if (agreement.Grid_Request__c != null && agreement.Grid_Request__r.ApprovalStatus__c == 'Draft') {
                    hasDraftGrid = true;
                }
            }
        }

        return new AgreementSelectionPageSettings((gridSettings != null), gridSettings?.agreementSelectionMode, userPrimaryTeam, availableTeams, agreementOptions, hasExistingGrid, existingGridKind, existingGridEndDate, hasDraftGrid);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getGridPicklistOptions() {
        String profileName = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1].Name;
        Boolean isRestrictedProfile = (profileName == 'Carmignac - CRM' || profileName == 'Carmignac - Business Developer');

        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Grid__c.fields.getMap();
        for (String f : new List<String>{'Kind__c', 'Type__c', 'ThresholdAmountCurrency__c', 'MinimumAmountCurrency__c', 'MinimumAmountFrequency__c'}) {
            List<Map<String, String>> opts = new List<Map<String, String>>();
            for (Schema.PicklistEntry e : fieldMap.get(f).getDescribe().getPicklistValues()) {
                if (e.isActive()) {
                    if (f == 'Kind__c' && isRestrictedProfile && e.getValue() != 'Rebates') continue;
                    opts.add(new Map<String, String>{'label' => e.getLabel(), 'value' => e.getValue()});
                }
            }
            result.put(f, opts);
        }
        return result;
    }

    private static String buildAgreementWhereClause(String agreementId, String userPrimaryTeam, List<String> userSecondaryTeams, String agreementQueryConditions) {
        String agreementWhere = '';
        // Redirection from Agreement directly
        if (String.isNotBlank(agreementId)) {
            agreementWhere = 'Id = :agreementId';
        }
        // Initial agreement selection screen
        else {
            List<String> whereFragments = new List<String>{'(Team__c != null AND (Team__c IN :userSecondaryTeams OR Team__c = :userPrimaryTeam))'};
            if(String.isNotBlank(agreementQueryConditions)) {
                whereFragments.add('(' + agreementQueryConditions + ')');
            }
            agreementWhere = String.join(whereFragments, ' AND ');
        }
        return agreementWhere;
    }

    @AuraEnabled
    public static DraftGridData getDraftGridData(Id agreementId) {
        Convention__c agr = [SELECT Id, Grid_Request__c, Grid_Request__r.ApprovalStatus__c
                             FROM Convention__c 
                             WHERE Id = :agreementId LIMIT 1];

        if (agr.Grid_Request__c == null || agr.Grid_Request__r.ApprovalStatus__c != 'Draft') return null;
        Id gridId = agr.Grid_Request__c;

        Grid__c grid = [SELECT Id, Name, Kind__c, Type__c, AutomaticGridUpdate__c, StartDate__c, EndDate__c, ThresholdAmount__c, ThresholdAmountCurrency__c, MinimumAmount__c, MinimumAmountCurrency__c, MinimumAmountFrequency__c
                        FROM Grid__c
                        WHERE Id = :gridId LIMIT 1];

        List<GridCriteria__c> criteriaRecords = [SELECT Id, StandardGrid__c, FilterLogic__c, FilterLogicExpression__c, StartDate__c
                                                 FROM GridCriteria__c 
                                                 WHERE Grid__c = :gridId];

        Map<Id, GridCriteriaData> criteriaDataMap = new Map<Id, GridCriteriaData>();
        List<GridCriteriaData> criteriaDataList = new List<GridCriteriaData>();
        for (GridCriteria__c gc : criteriaRecords) {
            GridCriteriaData cd = new GridCriteriaData();
            cd.criteria = gc;
            cd.details = new List<GridCriteriaDetail__c>();
            cd.shareClassIds = new List<Id>();
            criteriaDataMap.put(gc.Id, cd);
            criteriaDataList.add(cd);
        }

        if (!criteriaDataMap.isEmpty()) {
            for (GridCriteriaDetail__c gcd : [SELECT Id, Object__c, Field__c, Logic__c, Value__c, FilterNumber__c, TECHOrigin__c, GridCriteria__c
                                              FROM GridCriteriaDetail__c
                                              WHERE GridCriteria__c IN :criteriaDataMap.keySet()]) {
                criteriaDataMap.get(gcd.GridCriteria__c).details.add(gcd);
            }
            for (GridDetail__c gd : [SELECT Id, ShareClass__c, GridCriteria__c
                                     FROM GridDetail__c 
                                     WHERE Grid__c = :gridId]) {
                if (gd.GridCriteria__c != null && criteriaDataMap.containsKey(gd.GridCriteria__c)) {
                    criteriaDataMap.get(gd.GridCriteria__c).shareClassIds.add(gd.ShareClass__c);
                }
            }
        }

        DraftGridData result = new DraftGridData();
        result.grid = grid;
        result.criteriaList = criteriaDataList;
        return result;
    }

    @AuraEnabled
    public static AvailableGridsResult getAvailableGrids(String countriesOfDistribution, String agreementNames) {
        AvailableGridsResult result = new AvailableGridsResult();
        String standardGridRT = GridBuilderHelper.RT_STANDARD_GRID;
        List<String> countryList = GridBuilderHelper.stringToList(countriesOfDistribution, ';');
        List<String> agreementNameList = GridBuilderHelper.stringToList(agreementNames, ',');
        Set<Id> matchingGridIds = new Set<Id>();

        for (GridScope__c scope : [SELECT Grid__c, Grid__r.Name, Country__c, Agreement__c
                                   FROM GridScope__c
                                   WHERE Grid__c != null
                                   AND Grid__r.ActiveGrid__c = true
                                   AND Grid__r.RecordType.DeveloperName = :standardGridRT
                                   ORDER BY Grid__r.Name ASC LIMIT 5000]) {
            if (!matchingGridIds.contains(scope.Grid__c) && matchesScope(scope.Country__c, countryList, scope.Agreement__c, agreementNameList)) {
                result.gridOptions.add(new Map<String, String>{'label' => scope.Grid__r.Name, 'value' => scope.Grid__c});
                matchingGridIds.add(scope.Grid__c);
            }
        }

        for (Grid__c grid : [SELECT Id, (SELECT ShareClass__c FROM GridDetails__r WHERE ShareClass__c != null)
                             FROM Grid__c WHERE Id IN :matchingGridIds]) {
            List<String> shareClassIds = new List<String>();
            for (GridDetail__c detail : grid.GridDetails__r) {
                shareClassIds.add(String.valueOf(detail.ShareClass__c));
            }
            result.gridShareClassIds.put(String.valueOf(grid.Id), shareClassIds);
        }

        return result;
    }

    private static Boolean matchesScope(String scopeCountry, List<String> countryList, String scopeAgreement, List<String> agreementNameList) {
        Boolean scopeMatch = false;
        if (String.isNotBlank(scopeCountry) && scopeCountry.trim() == 'ALL' && String.isNotBlank(scopeAgreement) && scopeAgreement.trim() == 'ALL') {
            scopeMatch = true;
        }
        else if (String.isNotBlank(scopeCountry) && !countryList.isEmpty()) {
            scopeMatch = checkScopeToAgreementMatch(scopeCountry, countryList);
        }
        else if (String.isNotBlank(scopeAgreement) && !agreementNameList.isEmpty()) {
            scopeMatch = checkScopeToAgreementMatch(scopeAgreement, agreementNameList);
        }
        return scopeMatch;
    }

    private static Boolean checkScopeToAgreementMatch(String scopeParameters, List<String> agreementParamaters) {
        for (String c : scopeParameters.split('[,;]')) {
            if (agreementParamaters.contains(c.trim())) {
                return true;
            }
        }
        return false;
    }

    @AuraEnabled(cacheable=true)
    public static GridBuilderHelper.ProductSelectionResult getAllProductsForSelection(String gridBuilderSettingName, String countriesOfDistribution, List<String> availableGridIds) {
        return GridBuilderHelper.buildProductSelectionResult(gridBuilderSettingName, countriesOfDistribution, null, null, new Set<Id>(), null, new Map<Id, String>(), false, null, false, availableGridIds);
    }

    @AuraEnabled
    public static GridBuilderHelper.ProductSelectionResult getProductsAndShareClasses(String gridBuilderSettingName, String countriesOfDistribution, String gridCriteriaJson, String gridCriteriaDetailsJson, Boolean getAllProductsWithSelection, List<String> selectedShareTypes, List<String> availableGridIds) {
        GridBuilderHelper.GridSettings gridSettings = GridBuilderHelper.getGridSettings(gridBuilderSettingName, null, false, new List<String>());

        GridCriteria__c criteria = (GridCriteria__c)JSON.deserialize(gridCriteriaJson, GridCriteria__c.class);
        List<GridCriteriaDetail__c> criteriaDetails = (List<GridCriteriaDetail__c>)JSON.deserialize(gridCriteriaDetailsJson, List<GridCriteriaDetail__c>.class);
        Id gridId = criteria != null ? criteria.StandardGrid__c : null;

        Map<String, GridBuilderHelper.FieldInfo> fieldsApiToInfoMap = GridBuilderHelper.buildFieldsApiToInfoMap(gridSettings.fieldsToDisplay + GridBuilderHelper.getAdditionalQueryColumns(), getAllProductsWithSelection);
        FilterFragments filterFragments = buildWhereFragments(criteriaDetails, gridSettings.filterValueSeparator);
        String finalWhere = buildWhereClause(gridSettings, criteria, filterFragments, countriesOfDistribution, selectedShareTypes, availableGridIds);

        if(getAllProductsWithSelection) {
            String filteredQuery = 'SELECT Id, ' + String.join(GridBuilderHelper.getSelectableFieldSet(fieldsApiToInfoMap), ', ') + 
                                  ' FROM Share_Class__c ';
            filteredQuery += (String.isNotBlank(finalWhere)) ? ' WHERE ' + finalWhere : '';

            Set<Id> filteredIds = new Set<Id>();
            for (Share_Class__c scFiltered : Database.query(filteredQuery)) {
                filteredIds.add(scFiltered.Id);
            }
            
            return GridBuilderHelper.buildProductSelectionResult(gridBuilderSettingName, countriesOfDistribution, gridSettings, fieldsApiToInfoMap, filteredIds, null, new Map<Id, String>(), false, buildShareClassGridIdMap(filteredIds, gridId), true, availableGridIds);
        }
        else {
            return GridBuilderHelper.buildProductSelectionResult(gridBuilderSettingName, countriesOfDistribution, gridSettings, fieldsApiToInfoMap, new Set<Id>(), finalWhere, new Map<Id, String>(), false, null, false, availableGridIds);
        }
    }

    private static Map<String, String> buildShareClassGridIdMap(Set<Id> shareClassIds, Id gridId) {
        Map<String, String> shareClassGridIdMap = new Map<String, String>();
        for (Id shareClassId : shareClassIds) {
            shareClassGridIdMap.put(String.valueOf(shareClassId), String.valueOf(gridId));
        }
        return shareClassGridIdMap;
    }

    private static FilterFragments buildWhereFragments(List<GridCriteriaDetail__c> criteriaDetails, String filterValueSeparator) {
        FilterFragments filterFragments = new FilterFragments();
        String fieldPath, value, fragment;
        String detObject, detField, detLogic, detValue, detTechOrigin;
        for (GridCriteriaDetail__c d : criteriaDetails) {
            detObject = d.Object__c;
            detField = d.Field__c;
            detValue = d.Value__c;
            detLogic = getDetailLogic(d);
            detTechOrigin = d.TECHOrigin__c;
            if(String.isNotBlank(detObject) && String.isNotBlank(detField) && String.isNotBlank(detLogic)) {
                fieldPath = GridBuilderHelper.getRelationshipPath(detObject) + detField;
                value = formatValueForSoql(detLogic, detValue, filterValueSeparator);
                fragment = (detLogic == 'NOT {_} LIKE') ? detLogic.replace('{_}', fieldPath) + value : fieldPath + ' ' + detLogic + ' ' + value;
                if(detTechOrigin == 'User-Defined') {
                    filterFragments.userDefinedFragments.add(fragment);
                }
                else if(detTechOrigin == 'System') {
                    filterFragments.systemDefinedFragments.add(fragment);
                }
            }
        }
        return filterFragments;
    }

    private static String getDetailLogic(GridCriteriaDetail__c d) {
        return String.isBlank(d.Value__c)? (d.Logic__c == 'IN'? '=' : (d.Logic__c == 'NOT IN'? '!=' : d.Logic__c)) : d.Logic__c;
    }

    private static String formatValueForSoql(String op, String rawValue, String separator) {
        return (String.isBlank(rawValue))? '\'\'' :
               (op == 'IN' || op == 'NOT IN')? GridBuilderHelper.toSoqlInListLiteral(rawValue, separator) : //Multi-value operators
                '\'' + String.escapeSingleQuotes(rawValue) + '\''; // Single-value operators
    }

    private static String buildWhereClause(GridBuilderHelper.GridSettings gridSettings, GridCriteria__c criteria, FilterFragments filterFragments, String countriesOfDistribution, List<String> selectedShareTypes, List<String> availableGridIds) {
        //Build default conditions
        List<String> whereFragments = GridBuilderHelper.buildDefaultConditions(true, true, countriesOfDistribution, gridSettings.shareTypeWrp, false, availableGridIds);

        //Build selected share types condition
        String selectedShareTypesWhere = '';
        if(!selectedShareTypes.isEmpty()) {
           whereFragments.add('(Type__c IN '+ GridBuilderHelper.toSoqlInListLiteral(String.join(selectedShareTypes, ','), ',')+')');
        }

        //Build filters conditions
        String filtersWhere = '';
        if (filterFragments != null) {
            if(!filterFragments.userDefinedFragments.isEmpty()) {
                filtersWhere = buildUserDefinedFiltersWhere(criteria, filterFragments);
                if(String.isNotBlank(filtersWhere)) {
                    whereFragments.add('(' + filtersWhere + ')');
                }
            }
            if(!filterFragments.systemDefinedFragments.isEmpty()) {
                whereFragments.addAll(filterFragments.systemDefinedFragments);
            }
        }
        
        return String.join(whereFragments, ' AND ');
    }

    private static String buildUserDefinedFiltersWhere(GridCriteria__c criteria, FilterFragments filterFragments) {
        String filtersWhere;
        List<String> userDefFrags = filterFragments.userDefinedFragments;
        String logic = criteria.FilterLogic__c;
        String customLogic = criteria.FilterLogicExpression__c;
        if (logic == 'AND') { // AND logic
            filtersWhere = String.join(userDefFrags, ' AND ');
        }
        else if (logic == 'OR') { // OR logic
            filtersWhere = String.join(userDefFrags, ' OR ');
        }
        else if (logic == 'Custom Logic' && String.isNotBlank(customLogic)) { // Custom logic: replace numbers with userDefFrags
            String temp = customLogic;
            String nbr;
            for (Integer i = 0; i < userDefFrags.size(); i++) {
                nbr = String.valueOf(i + 1);
                temp = temp.replace(nbr, '~F' + nbr + '~');
            }
            for (Integer i = 0; i < userDefFrags.size(); i++) {
                nbr = '~F' + String.valueOf(i + 1) + '~';
                temp = temp.replace(nbr, '(' + userDefFrags[i] + ')');
            }
            filtersWhere = temp;
        }
        else {
            filtersWhere = String.join(userDefFrags, ' AND '); // Fallback: AND everything
        }
        return filtersWhere;
    }
    private static List<String> buildAvailableTeams(String primaryTeam, Set<String> setAvailableTeams) {
        List<String> availableTeams = new List<String>{primaryTeam};

        setAvailableTeams.remove(primaryTeam);
        List<String> sortedSecondaryTeams = new List<String>(setAvailableTeams);
        sortedSecondaryTeams.sort();

        availableTeams.addAll(sortedSecondaryTeams);
        return availableTeams;
    }

    // ────────────────────────────────────── WRAPPERS ──────────────────────────────────────
    public class AvailableGridsResult {
        @AuraEnabled public List<Map<String, String>> gridOptions { get; set; }
        @AuraEnabled public Map<String, List<String>> gridShareClassIds { get; set; }
        public AvailableGridsResult() {
            this.gridOptions = new List<Map<String, String>>();
            this.gridShareClassIds = new Map<String, List<String>>();
        }
    }

    public class AgreementSelectionPageSettings {
        @AuraEnabled public Boolean gridBuilderFound { get; set; }
        @AuraEnabled public String agreementSelectionMode { get; set; }
        @AuraEnabled public String primaryTeam { get; set; }
        @AuraEnabled public List<String> availableTeams { get; set; }
        @AuraEnabled public List<AgreementWrapper> agreementOptions { get; set; }
        @AuraEnabled public Boolean hasExistingGrid { get; set; }
        @AuraEnabled public String existingGridKind { get; set; }
        @AuraEnabled public String existingGridEndDate { get; set; }
        @AuraEnabled public Boolean hasDraftGrid { get; set; }
        public AgreementSelectionPageSettings(Boolean gridBuilderFound, String agreementSelectionMode, String primaryTeam, Set<String> setAvailableTeams, List<AgreementWrapper> agreementOptions, Boolean hasExistingGrid, String existingGridKind, String existingGridEndDate, Boolean hasDraftGrid) {
            this.gridBuilderFound           =   gridBuilderFound;
            this.agreementSelectionMode     =   agreementSelectionMode;
            this.agreementOptions           =   agreementOptions;
            this.primaryTeam                =   primaryTeam;
            this.availableTeams             =   buildAvailableTeams(primaryTeam, setAvailableTeams);
            this.hasExistingGrid            =   hasExistingGrid;
            this.existingGridKind           =   existingGridKind;
            this.existingGridEndDate        =   existingGridEndDate;
            this.hasDraftGrid               =   hasDraftGrid;
        }
    }
    
    public class AgreementWrapper {
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String teamCountry { get; set; }
        @AuraEnabled public String countriesOfDistribution { get; set; }
        @AuraEnabled public String regionCode { get; set; }
        public AgreementWrapper(Convention__c agr) {
            this.value                      =   agr.Id;
            this.name                       =   agr.Name;
            this.label                      =   String.isNotBlank(agr.ConventionName__c)? agr.ConventionName__c + ' (' + agr.Name + ')' : agr.Name;
            this.teamCountry                =   agr.Team__c;
            this.countriesOfDistribution    =   agr.Countries_of_Distribution__c;
            this.regionCode                 =   agr.Business_Region__c;
        }
    }

    public class FilterFragments {
        public List<String> userDefinedFragments { get; set; }
        public List<String> systemDefinedFragments { get; set; }
        public FilterFragments() {
            this.userDefinedFragments       =   new List<String>();
            this.systemDefinedFragments     =   new List<String>();
        }
    }

    public class DraftGridData {
        @AuraEnabled public Grid__c grid { get; set; }
        @AuraEnabled public List<GridCriteriaData> criteriaList { get; set; }
    }

    public class GridCriteriaData {
        @AuraEnabled public GridCriteria__c criteria { get; set; }
        @AuraEnabled public List<GridCriteriaDetail__c> details { get; set; }
        @AuraEnabled public List<Id> shareClassIds { get; set; }
    }
}