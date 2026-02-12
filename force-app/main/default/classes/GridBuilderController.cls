/**
 * @description Lightning Web Component controller for the Grid Builder interface. 
 *              Provides methods for retrieving grid settings, available grids, products, 
 *                  share classes, and agreement selection page configuration. 
 *              Works in conjunction with GridBuilderHelper for data filtering and formatting.
 * @author Charles EID
 * @testClass GridBuilderControllerTest
 * @coverage 95%
 */
public with sharing class GridBuilderController {

    @AuraEnabled(cacheable=true)
    public static GridBuilderHelper.GridSettings getGridSettings(String gridBuilderSettingName, String countriesOfDistribution) {
        return GridBuilderHelper.getGridSettings(gridBuilderSettingName, countriesOfDistribution, true);
    }

    @AuraEnabled(cacheable=true)
    public static AgreementSelectionPageSettings getAgreementSelectionPageSettings(String gridBuilderSettingName, String agreementId) {
        GridBuilderHelper.GridSettings gridSettings = GridBuilderHelper.getGridSettings(gridBuilderSettingName, null, false);

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
        String agreementQuery = 'SELECT Id, ConventionName__c, Name, Team__c, Countries_of_Distribution__c '+
                                ' FROM Convention__c ';
        agreementQuery +=       ' WHERE ' + agreementWhere;
        agreementQuery +=       ' ORDER BY ConventionName__c ASC, Name ASC, Team__c ASC LIMIT 5000';

        List<AgreementWrapper> agreementOptions = new List<AgreementWrapper>();
        Set<String> availableTeams = new Set<String>();
        for (Convention__c agreement : Database.query(agreementQuery)) {
            agreementOptions.add(new AgreementWrapper(agreement));
            availableTeams.add(agreement.Team__c);
        }
        return new AgreementSelectionPageSettings((gridSettings != null), gridSettings?.agreementSelectionMode, userPrimaryTeam, availableTeams, agreementOptions);
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
    public static List<Map<String, String>> getAvailableGrids(String countriesOfDistribution, String agreementNames) {
        List<Map<String, String>> gridOptions = new List<Map<String, String>>();
        String standardGridRT = GridBuilderHelper.RT_STANDARD_GRID;

        for (Grid__c g : [SELECT Id, Name, GridScope__c, GridScope__r.Country__c, GridScope__r.Agreement__c
                          FROM Grid__c
                          WHERE ActiveGrid__c = true
                          AND GridScope__c != null
                          AND RecordType.DeveloperName = :standardGridRT
                          ORDER BY Name ASC LIMIT 5000]) {
            if (matchesScope(g.GridScope__r.Country__c, GridBuilderHelper.stringToList(countriesOfDistribution, ';'), g.GridScope__r.Agreement__c, GridBuilderHelper.stringToList(agreementNames, ','))) {
                gridOptions.add(new Map<String, String>{'label' => g.Name, 'value' => g.Id});
            }
        }
        return gridOptions;
    }

    private static Boolean matchesScope(String scopeCountry, List<String> countryList, String scopeAgreement, List<String> agreementNameList) {
        Boolean scopeMatch = false;
        if (String.isNotBlank(scopeCountry) && scopeCountry.trim() == 'ALL') {
            scopeMatch = true;
        }
        else if (String.isNotBlank(scopeAgreement) && !agreementNameList.isEmpty()) {
            scopeMatch = checkScopeToAgreementMatch(scopeAgreement, agreementNameList);
        }
        else if (String.isNotBlank(scopeCountry) && !countryList.isEmpty()) {
            scopeMatch = checkScopeToAgreementMatch(scopeCountry, countryList);
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
    public static GridBuilderHelper.ProductSelectionResult getAllProductsForSelection(String gridBuilderSettingName, String countriesOfDistribution) {
        return GridBuilderHelper.buildProductSelectionResult(gridBuilderSettingName, countriesOfDistribution, null, null, new Set<Id>(), null, new Map<Id, String>(), false, null, false);
    }

    @AuraEnabled
    public static GridBuilderHelper.ProductSelectionResult getProductsAndShareClasses(String gridBuilderSettingName, String countriesOfDistribution, String gridCriteriaJson, String gridCriteriaDetailsJson, Boolean getAllProductsWithSelection, List<String> selectedShareTypes) {
        GridBuilderHelper.GridSettings gridSettings = GridBuilderHelper.getGridSettings(gridBuilderSettingName, null, false);

        GridCriteria__c criteria = (GridCriteria__c)JSON.deserialize(gridCriteriaJson, GridCriteria__c.class);
        List<GridCriteriaDetail__c> criteriaDetails = (List<GridCriteriaDetail__c>)JSON.deserialize(gridCriteriaDetailsJson, List<GridCriteriaDetail__c>.class);
        Id gridId = criteria != null ? criteria.StandardGrid__c : null;

        Map<String, GridBuilderHelper.FieldInfo> fieldsApiToInfoMap = GridBuilderHelper.buildFieldsApiToInfoMap(gridSettings.fieldsToDisplay + GridBuilderHelper.getAdditionalQueryColumns(), getAllProductsWithSelection);
        FilterFragments filterFragments = buildWhereFragments(criteriaDetails, gridSettings.filterValueSeparator);
        String finalWhere = buildWhereClause(gridSettings, criteria, filterFragments, countriesOfDistribution, selectedShareTypes);

        if(getAllProductsWithSelection) {
            String filteredQuery = 'SELECT Id, ' + String.join(GridBuilderHelper.getSelectableFieldSet(fieldsApiToInfoMap), ', ') + 
                                  ' FROM Share_Class__c ';
            filteredQuery += (String.isNotBlank(finalWhere)) ? ' WHERE ' + finalWhere : '';

            Set<Id> filteredIds = new Set<Id>();
            for (Share_Class__c scFiltered : Database.query(filteredQuery)) {
                filteredIds.add(scFiltered.Id);
            }
            
            return GridBuilderHelper.buildProductSelectionResult(gridBuilderSettingName, countriesOfDistribution, gridSettings, fieldsApiToInfoMap, filteredIds, null, new Map<Id, String>(), false, buildShareClassGridIdMap(filteredIds, gridId), true);
        }
        else {
            return GridBuilderHelper.buildProductSelectionResult(gridBuilderSettingName, countriesOfDistribution, gridSettings, fieldsApiToInfoMap, new Set<Id>(), finalWhere, new Map<Id, String>(), false, null, false);
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

    private static String buildWhereClause(GridBuilderHelper.GridSettings gridSettings, GridCriteria__c criteria, FilterFragments filterFragments, String countriesOfDistribution, List<String> selectedShareTypes) {
        //Build default conditions
        List<String> whereFragments = GridBuilderHelper.buildDefaultConditions(true, true, countriesOfDistribution, gridSettings.shareTypeWrp, false);

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

    // ------------------------------------ WRAPPERS ------------------------------------
    public class AgreementSelectionPageSettings {
        @AuraEnabled public Boolean gridBuilderFound { get; set; }
        @AuraEnabled public String agreementSelectionMode { get; set; }
        @AuraEnabled public String primaryTeam { get; set; }
        @AuraEnabled public List<String> availableTeams { get; set; }
        @AuraEnabled public List<AgreementWrapper> agreementOptions { get; set; }
        public AgreementSelectionPageSettings(Boolean gridBuilderFound, String agreementSelectionMode, String primaryTeam, Set<String> setAvailableTeams, List<AgreementWrapper> agreementOptions) {
            this.gridBuilderFound           =   gridBuilderFound;
            this.agreementSelectionMode     =   agreementSelectionMode;
            this.agreementOptions           =   agreementOptions;
            this.primaryTeam                =   primaryTeam;
            this.availableTeams             =   buildAvailableTeams(primaryTeam, setAvailableTeams);
        }
    }
    public class AgreementWrapper {
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String teamCountry { get; set; }
        @AuraEnabled public String countriesOfDistribution { get; set; }
        public AgreementWrapper(Convention__c agr) {
            this.value                      =   agr.Id;
            this.name                       =   agr.Name;
            this.label                      =   String.isNotBlank(agr.ConventionName__c)? agr.ConventionName__c + ' (' + agr.Name + ')' : agr.Name;
            this.teamCountry                =   agr.Team__c;
            this.countriesOfDistribution    =   agr.Countries_of_Distribution__c;
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
}