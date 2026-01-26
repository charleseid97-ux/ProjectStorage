public with sharing class GridBuilderController {

    @AuraEnabled(cacheable=true)
    public static GridBuilderHelper.GridSettings getGridSettings(String gridBuilderSettingName, String selectedTeam) {
        return GridBuilderHelper.getGridSettings(gridBuilderSettingName, selectedTeam, true);
    }

    @AuraEnabled(cacheable=true)
    public static AgreementSelectionPageSettings getAgreementSelectionPageSettings(String gridBuilderSettingName) {
        String agreementSelectionMode = 'Single';
        Boolean gridBuilderFound = false;
        List<GridBuilderSetting__mdt> gridSetting = [SELECT Id, AgreementSelectionMode__c
                                                     FROM GridBuilderSetting__mdt
                                                     WHERE DeveloperName = :gridBuilderSettingName LIMIT 1];
        if(gridSetting != null && !gridSetting.isEmpty()) {
            gridBuilderFound = true;
            agreementSelectionMode = String.isNotBlank(gridSetting[0].AgreementSelectionMode__c)? gridSetting[0].AgreementSelectionMode__c : agreementSelectionMode;
        }

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

        List<AgreementWrapper> agreementOptions = new List<AgreementWrapper>();
        Set<String> availableTeams = new Set<String>();
        String agreementLabel;
        for (Convention__c agreement : [SELECT Id, ConventionName__c, Name, Team__c
                                        FROM Convention__c
                                        WHERE Team__c != null
                                        AND (Team__c IN :userSecondaryTeams OR Team__c = :userPrimaryTeam)
                                        ORDER BY ConventionName__c ASC, Name ASC, Team__c ASC LIMIT 5000]) {
            agreementLabel = String.isNotBlank(agreement.ConventionName__c)? agreement.ConventionName__c + ' (' + agreement.Name + ')' : agreement.Name;
            agreementOptions.add(new AgreementWrapper(agreement.Id, agreementLabel, agreement.Team__c));
            availableTeams.add(agreement.Team__c);
        }
        return new AgreementSelectionPageSettings(gridBuilderFound, agreementSelectionMode, userPrimaryTeam, availableTeams, agreementOptions);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailableGrids(String selectedTeam) {
        List<Map<String, String>> gridOptions = new List<Map<String, String>>();
        for (Grid__c g : [SELECT Id, Name 
                          FROM Grid__c 
                          WHERE ActiveGrid__c = true
                          AND Team__c = :selectedTeam
                          ORDER BY Name ASC LIMIT 5000]) {
            gridOptions.add(new Map<String, String>{'label' => g.Name, 'value' => g.Id});
        }
        return gridOptions;
    }

    @AuraEnabled(cacheable=true)
    public static GridBuilderHelper.ProductSelectionResult getAllProductsForSelection(String gridBuilderSettingName, String selectedTeam) {
        return GridBuilderHelper.buildProductSelectionResult(gridBuilderSettingName, selectedTeam, null, null, new Set<Id>(), null);
    }

    @AuraEnabled
    public static GridBuilderHelper.ProductSelectionResult getProductsAndShareClasses(String gridBuilderSettingName, String selectedTeam, String gridCriteriaJson, String gridCriteriaDetailsJson, Boolean getAllProductsWithSelection, List<String> selectedShareTypes) {
         GridBuilderHelper.GridSettings gridSettings = GridBuilderHelper.getGridSettings(gridBuilderSettingName, selectedTeam, false);

        GridCriteria__c criteria = (GridCriteria__c)JSON.deserialize(gridCriteriaJson, GridCriteria__c.class);
        List<GridCriteriaDetail__c> criteriaDetails = (List<GridCriteriaDetail__c>)JSON.deserialize(gridCriteriaDetailsJson, List<GridCriteriaDetail__c>.class);

        Map<String, GridBuilderHelper.FieldInfo> fieldsApiToInfoMap = GridBuilderHelper.buildFieldsApiToInfoMap(gridSettings.fieldsToDisplay + GridBuilderHelper.getAdditionalQueryColumns());
        FilterFragments filterFragments = buildWhereFragments(criteriaDetails, gridSettings.filterValueSeparator);
        String finalWhere = buildWhereClause(gridSettings, criteria, filterFragments, selectedTeam, selectedShareTypes);

        if(getAllProductsWithSelection) {
            String filteredQuery = 'SELECT Id, ' + String.join(fieldsApiToInfoMap.keySet(), ', ') + 
                                  ' FROM Share_Class__c ';
            filteredQuery += (String.isNotBlank(finalWhere)) ? ' WHERE ' + finalWhere : '';

            Set<Id> filteredIds = new Set<Id>();
            for (Share_Class__c scFiltered : Database.query(filteredQuery)) {
                filteredIds.add(scFiltered.Id);
            }
            
            return GridBuilderHelper.buildProductSelectionResult(gridBuilderSettingName, selectedTeam, gridSettings, fieldsApiToInfoMap, filteredIds, null);
        }
        else {
            return GridBuilderHelper.buildProductSelectionResult(gridBuilderSettingName, selectedTeam, gridSettings, fieldsApiToInfoMap, new Set<Id>(), finalWhere);
        }
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
        String formattedValue;
        if(String.isBlank(rawValue)) {
            formattedValue = '\'\'';
        }
        //Multi-value operators
        else if (op == 'IN' || op == 'NOT IN') {
            formattedValue = GridBuilderHelper.toSoqlInListLiteral(rawValue, separator);
        }
        // Single-value operators
        else if (op == 'LIKE' || op == 'NOT {_} LIKE') {
            formattedValue = '\'' + String.escapeSingleQuotes(rawValue) + '\'';
        }
        else {
            formattedValue = '\'' + String.escapeSingleQuotes(rawValue) + '\'';
        }
        return formattedValue;
    }

    private static String buildWhereClause(GridBuilderHelper.GridSettings gridSettings, GridCriteria__c criteria, FilterFragments filterFragments, String selectedTeam, List<String> selectedShareTypes) {
        //Build default conditions
        List<String> whereFragments = GridBuilderHelper.buildDefaultConditions(true, true, selectedTeam, gridSettings.shareTypeWrp, false);

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
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String teamCountry { get; set; }
        public AgreementWrapper(String val, String label, String team) {
            this.value          =   val;
            this.label          =   label;
            this.teamCountry    =   team;
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