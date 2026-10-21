/**
 * @description Product Catalog controller with a combined Share Class / Product search.
 * @testClass ReferentialProductHomepageCtrlTest
 */
public class ReferentialProductHomepageCtrl {

    static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();

    private static final List<String> ACTIVE_SHARE_CLASS_STATUSES = new List<String>{'Active', 'Active - Lab'};

    // Retrieve all Share Class and Product fields used by the existing hierarchy helper.
    private static final String SHARE_CLASS_SELECT = 'SELECT Id, Name, Fund__c, Status__c, ISIN__c, Primary_Portfolio_Share_Class__c, ' +
                                                     'Fund__r.Id, Fund__r.Name, Fund__r.Record_Type_Name__c, Fund__r.RecordTypeId, ' +
                                                     'Fund__r.LaunchDate__c, Fund__r.FundStrategy__c, Fund__r.AssetClass__c, Fund__r.Validity__c ' +
                                                     'FROM Share_Class__c WHERE ';
    private static final String SHARE_CLASS_ORDER = ' ORDER BY Primary_Portfolio_Share_Class__c desc';

    @AuraEnabled
    public static String getAllProducts(Boolean showSRI, Boolean showRF, Boolean showAC, String country, String assetClass, String SCType, String dividendPolicy,
                                        String legalForm, String fundType, String selectedCurrency, String searchKey, Boolean isActiveProducts, String sfdr) {
        CatalogFilters filters = new CatalogFilters(country, assetClass, SCType, dividendPolicy, legalForm, fundType, selectedCurrency, searchKey, isActiveProducts, sfdr);
        List<Share_Class__c> sharesList = queryShareClasses(filters);
        if (sharesList.isEmpty()) return null;

        List<Product__c> filteredFunds = fundsOf(sharesList);
        return JSON.serialize(buildCatalog(filters, filteredFunds, sharesList));
    }

    @AuraEnabled
    public static void logClick(String buttonType) {
        UserInteractionLog__c log = new UserInteractionLog__c(
            User__c = UserInfo.getUserId(),
            ClickDate__c = System.now(),
            ButtonType__c = buttonType
        );
        insert log;
    }

    // Apply Share Class filters, Product filters and the combined search in one query.
    private static List<Share_Class__c> queryShareClasses(CatalogFilters filters) {
        Map<String, Object> binds = new Map<String, Object>{'fundRecordTypeId' => fundRecordTypeId};
        String query = SHARE_CLASS_SELECT + shareClassFilterClause(filters, binds);
        query += ' AND Fund__c != null';
        query += ' AND Fund__r.Tech_NotDisplayedProductCatalog__c = false';
        query += ' AND Fund__r.RecordTypeId = :fundRecordTypeId';
        query += ' AND Fund__r.VehicleType__c = \'Funds\'';
        query = appendEquals(query, binds, 'Fund__r.FundStrategy__r.AssetClass__c', 'assetClass', filters.assetClass);
        query = appendEquals(query, binds, 'Fund__r.LegalForm__c', 'legalForm', filters.legalForm);
        query = appendEquals(query, binds, 'Fund__r.VehicleType__c', 'fundType', filters.fundType);
        query = appendEquals(query, binds, 'Fund__r.SFDRcategory__c', 'sfdr', filters.sfdr);

        if (filters.hasSearch()) {
            query += ' AND (' + searchClause() + ')';
            binds.put('searchLike', '%' + filters.searchKey + '%');
        }
        return (List<Share_Class__c>) Database.queryWithBinds(query + SHARE_CLASS_ORDER, binds, AccessLevel.SYSTEM_MODE);
    }

    // Keep the existing Share Class status, currency, type, dividend and country filters.
    private static String shareClassFilterClause(CatalogFilters filters, Map<String, Object> binds) {
        binds.put('activeStatuses', ACTIVE_SHARE_CLASS_STATUSES);
        String clause = filters.isActive ? 'Status__c IN :activeStatuses' : 'Status__c NOT IN :activeStatuses';
        clause = appendEquals(clause, binds, 'Currency__c', 'selectedCurrency', filters.selectedCurrency);
        clause = appendEquals(clause, binds, 'Type__c', 'scType', filters.scType);
        clause = appendEquals(clause, binds, 'DividendPolicy__c', 'dividendPolicy', filters.dividendPolicy);

        if (filters.hasCountry()) {
            clause += ' AND Id IN (SELECT ShareClass__c FROM Country__c WHERE Country__c = :country)';
            binds.put('country', filters.country);
        }
        return clause;
    }

    // Every search checks the ISIN and all three Product fields, without classifying the input.
    private static String searchClause() {
        return 'ISIN__c LIKE :searchLike OR Fund__r.InternalShortName__c LIKE :searchLike ' +
               'OR Fund__r.ProductName__c LIKE :searchLike OR Fund__r.Name LIKE :searchLike';
    }

    private static String appendEquals(String query, Map<String, Object> binds, String field, String bindName, String value) {
        if (String.isBlank(value)) return query;
        binds.put(bindName, value);
        return query + ' AND ' + field + ' = :' + bindName;
    }

    // Reuse the queried parent records instead of querying Product__c separately.
    private static List<Product__c> fundsOf(List<Share_Class__c> sharesList) {
        Map<Id, Product__c> fundsById = new Map<Id, Product__c>();
        for (Share_Class__c share : sharesList) {
            if (!fundsById.containsKey(share.Fund__c)) fundsById.put(share.Fund__c, share.Fund__r);
        }
        return fundsById.values();
    }

    // Strategies are queried only for the unfiltered, grouped view.
    private static List<Strategy__c> queryStrategies(List<Product__c> funds) {
        Set<Id> strategyIds = new Set<Id>();
        for (Product__c fund : funds) {
            if (fund.FundStrategy__c != null) strategyIds.add(fund.FundStrategy__c);
        }
        if (strategyIds.isEmpty()) return new List<Strategy__c>();

        return [SELECT Id, Name, AssetClass__c
                FROM Strategy__c
                WHERE Id IN :strategyIds
                ORDER BY Name ASC];
    }

    // Preserve the existing flat Product view or grouped Strategy view.
    private static ItemDTO buildCatalog(CatalogFilters filters, List<Product__c> filteredFunds, List<Share_Class__c> sharesList) {
        Map<Id, List<Share_Class__c>> fundToSharesMap = ProductHierarchyHelper.setFundToSharesMap(sharesList);

        if (filters.isIS) return buildISProductHierarchy(filteredFunds, fundToSharesMap);

        if (filters.hasAnyFilter()) {
            List<ItemDTO> fundItems = ProductHierarchyHelper.getFundsItemsWithSharesReferential(filteredFunds, fundToSharesMap, true);
            return new ItemDTO('All Products', null, null, null, null, null, false, true, true, true, fundItems);
        }

        List<Strategy__c> strategies = queryStrategies(filteredFunds);
        Map<Id, List<Product__c>> strategyToFundsMap = ProductHierarchyHelper.setFundStrategyToFundsMap(filteredFunds);
        List<ItemDTO> strategyItems = ProductHierarchyHelper.getAllStrategywithFundsItems(strategyToFundsMap, strategies, fundToSharesMap);
        return new ItemDTO('All Strategies', null, null, null, null, null, false, true, true, true, strategyItems);
    }

    private class CatalogFilters {
        public String country;
        public String assetClass;
        public String scType;
        public String dividendPolicy;
        public String legalForm;
        public String fundType;
        public String selectedCurrency;
        public String searchKey;
        public String sfdr;
        public Boolean isActive;

        public CatalogFilters(String country, String assetClass, String SCType, String dividendPolicy, String legalForm, String fundType,
                              String selectedCurrency, String searchKey, Boolean isActiveProducts, String sfdr) {
            this.country = country;
            this.assetClass = assetClass;
            this.scType = SCType;
            this.dividendPolicy = dividendPolicy;
            this.legalForm = legalForm;
            this.fundType = fundType;
            this.selectedCurrency = selectedCurrency;
            this.sfdr = sfdr;
            this.isActive = isActiveProducts == true;
            this.searchKey = String.isBlank(searchKey) ? null : searchKey.trim();
        }

        public Boolean hasSearch() {
            return String.isNotBlank(searchKey);
        }

        public Boolean hasCountry() {
            return String.isNotBlank(country) && country != 'All countries';
        }

        public Boolean hasAnyFilter() {
            if (hasSearch() || hasCountry()) return true;
            for (String value : new List<String>{assetClass, legalForm, fundType, sfdr, scType, dividendPolicy, selectedCurrency}) {
                if (String.isNotBlank(value)) return true;
            }
            return false;
        }
    }

    /* ----------- DTO for product (moved from productHierarchyController) ----------- */
    public class ItemDTO {
        public String label {get; set;} // label is the name of the product (the shown title on tree)
        public String type {get; set;} // the record type of the product
        public String name {get; set;} // the name of the product
        public String href {get; set;} // link to the product page in the org
        public String investstyle {get; set;} // investment style for product of type strategy only
        public String isin {get; set;} // isin code for share classes
        public Boolean currentproduct {get; set;} // whether the selected product is the current product shown to the user or not
        public Boolean isvalid {get; set;} // whether the item is valid or not (Validty__c)
        public Boolean isproduct {get; set;} // whether the item is a product or a share class
        public Boolean expanded {get; set;} // whether the item is expanded (on tree) or not
        public List<ItemDTO> items {get; set;} // items related to the selected item (tree architecture)
        public Boolean ishighlevel {get; set;}
        public String regionalFocusId {get; set;}
        public String assetClassId {get; set;}
        public String id {get; set;}
        public String assetclass {get; set;}
        public String regionalfocus {get; set;}
        public String ytdnet {get; set;}
        public String aum {get; set;}
        public String lastaum {get; set;}

        public ItemDTO(){}

        public ItemDTO(String label, String type, String name, String href, String investstyle, String isin, Boolean currentproduct, Boolean isvalid, Boolean isproduct, Boolean expanded, List<ItemDTO> items) {
            this.label = label;
            this.type = type;
            this.name = name;
            this.href = href;
            this.investstyle = investstyle;
            this.isin = isin;
            this.currentproduct = currentproduct;
            this.isvalid = isvalid;
            this.isproduct = isproduct;
            this.expanded = expanded;
            this.items =  items;
        }
    }
}