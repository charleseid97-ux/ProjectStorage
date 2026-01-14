public with sharing class GridBuilderController {

    @AuraEnabled(cacheable=true)
    public static GridBuilderHelper.GridSettings getGridSettings(String gridBuilderSettingName, String selectedTeam) {
        return GridBuilderHelper.getGridSettings(gridBuilderSettingName, selectedTeam);
    }

    @AuraEnabled(cacheable=true)
    public static AgreementSelectionPageSettings getAgreementSelectionPageSettings(String gridBuilderSettingName) {
        String agreementSelectionMode = 'Single';
        Boolean gridBuilderFound = false;
        List<GridBuilderSetting__mdt> gridSetting = [SELECT Id, AgreementSelectionMode__c
                                                     FROM GridBuilderSetting__mdt
                                                     WHERE DeveloperName = :gridBuilderSettingName];
        if(gridSetting != null && !gridSetting.isEmpty()) {
            gridBuilderFound = true;
            agreementSelectionMode = String.isNotBlank(gridSetting[0].AgreementSelectionMode__c)? gridSetting[0].AgreementSelectionMode__c : agreementSelectionMode;
        }

        String userPrimaryTeam = '';
        List<String> userSecondaryTeams = new List<String>();
        User usr = [SELECT Id, Team__c, Secondary_Teams__c 
                    FROM User 
                    WHERE Id = :UserInfo.getUserId()];
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
                                        ORDER BY Team__c ASC, Name ASC]) {
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
                          ORDER BY Name ASC]) {
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
         GridBuilderHelper.GridSettings gridSettings = GridBuilderHelper.getGridSettings(gridBuilderSettingName, selectedTeam);

        GridCriteria__c criteria = (GridCriteria__c)JSON.deserialize(gridCriteriaJson, GridCriteria__c.class);
        List<GridCriteriaDetail__c> criteriaDetails = (List<GridCriteriaDetail__c>)JSON.deserialize(gridCriteriaDetailsJson, List<GridCriteriaDetail__c>.class);

        Map<String, GridBuilderHelper.FieldInfo> fieldsApiToInfoMap = GridBuilderHelper.buildFieldsApiToInfoMap(gridSettings.fieldsToDisplay + GridBuilderHelper.getAdditionalQueryColumns());
        List<String> filterFragments = buildWhereFragments(criteriaDetails, gridSettings.filterValueSeparator);
        String finalWhere = buildWhereClause(gridSettings, criteria.FilterLogic__c, criteria.FilterLogicExpression__c, filterFragments, selectedTeam, selectedShareTypes);

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

    private static List<String> buildWhereFragments(List<GridCriteriaDetail__c> criteriaDetails, String filterValueSeparator) {
        List<String> filterFragments = new List<String>();
        String fieldPath, value, fragment;
        for (GridCriteriaDetail__c d : criteriaDetails) {
            if(String.isNotBlank(d.Object__c) && String.isNotBlank(d.Field__c) && String.isNotBlank(d.Logic__c)) {
                fieldPath = GridBuilderHelper.getRelationshipPath(d.Object__c) + d.Field__c;
                value = formatValueForSoql(d.Logic__c, d.Value__c, filterValueSeparator);
                fragment = (d.Logic__c == 'NOT {_} LIKE') ? d.Logic__c.replace('{_}', fieldPath) + value : fieldPath + ' ' + d.Logic__c + ' ' + value;
                filterFragments.add(fragment);
            }
        }
        return filterFragments;
    }

    private static String formatValueForSoql(String op, String rawValue, String separator) {
        String formattedValue;
        //Multi-value operators
        if (op == 'IN' || op == 'NOT IN') {
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

    private static String buildWhereClause(GridBuilderHelper.GridSettings gridSettings, String logic, String customLogic, List<String> filterFragments, String selectedTeam, List<String> selectedShareTypes) {
        //Build default conditions
        List<String> whereFragments = GridBuilderHelper.buildDefaultConditions(true, true, selectedTeam, gridSettings.shareTypeWrp, false);

        //Build selected share types condition
        String selectedShareTypesWhere = '';
        if(!selectedShareTypes.isEmpty()) {
           whereFragments.add('(Type__c IN '+ GridBuilderHelper.toSoqlInListLiteral(String.join(selectedShareTypes, ','), ',')+')');
        }

        //Build filters conditions
        String filtersWhere = '';
        if (!filterFragments.isEmpty()) {
            if (logic == 'AND') { // AND logic
                filtersWhere = String.join(filterFragments, ' AND ');
            }
            else if (logic == 'OR') { // OR logic
                filtersWhere = String.join(filterFragments, ' OR ');
            }
            else if (logic == 'Custom Logic' && String.isNotBlank(customLogic)) { // Custom logic: replace numbers with filterFragments
                String temp = customLogic;
                for (Integer i = 0; i < filterFragments.size(); i++) {
                    String nbr = String.valueOf(i + 1);
                    temp = temp.replace(nbr, '(' + filterFragments[i] + ')');
                }
                filtersWhere = temp;
            }
            else {
                filtersWhere = String.join(filterFragments, ' AND '); // Fallback: AND everything
            }
            if(String.isNotBlank(filtersWhere)) {
                whereFragments.add('(' + filtersWhere + ')');
            }
        }
        
        return String.join(whereFragments, ' AND ');
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
}