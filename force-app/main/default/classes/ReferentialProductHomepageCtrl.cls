/** ──────────────────────────────────────
 * @description Lightning Web Component controller for the Product Catalog (referentialProductHomepage).
 *              Retrieves the Funds and their Share Classes according to the selected filters and the search key,
 *                  and returns them as a hierarchy (flat list when a filter is active, grouped by Strategy otherwise).
 *              Works in conjunction with ProductHierarchyHelper for building the hierarchy items.
 * @testClass ReferentialProductHomepageCtrlTest
 * @coverage 96%   [21-09-26]
 * @changes [21-09-26] [Charles EID]
 * -> Refactored for better complexity handling.
 * -> Optimized
 * -> Adapted new fields (after the removal of legacy fields)
 * -> ItemDTO moved here from productHierarchyController (obsolete, to be deleted).
 * -> IS Products mode only: product label is ProductName__c (falls back to Name) and products are collapsed (Share Class level hidden until opened).
 * -> IS Products filter (isISProducts): scope on InvestSolutionScope__c (all Vehicle Types), funds not restricted to the Share Class funds, grouped by VehicleType__c (buildISProductHierarchy).
 ────────────────────────────────────── */
public class ReferentialProductHomepageCtrl {

    static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();

    private static final List<String> ACTIVE_SHARE_CLASS_STATUSES = new List<String>{'Active', 'Active - Lab'}; // Statuts considérés comme actifs pour remplacer TechIsActive__c.
    private static final String ISIN_PATTERN = '^[A-Z]{2}[0-9]{3,10}$'; // 2 lettres + au moins 3 chiffres pour ne pas confondre un Internal Short Name (ex: CC27) avec un ISIN

    private static final String SHARE_CLASS_SELECT = 'SELECT Id, Name, Fund__c, Status__c, ISIN__c, Primary_Portfolio_Share_Class__c, Fund__r.AssetClass__c, Fund__r.LaunchDate__c' +
                                                     ' FROM Share_Class__c WHERE ';
    private static final String SHARE_CLASS_ORDER = ' ORDER BY Primary_Portfolio_Share_Class__c desc';

    private static final String FUND_SELECT = 'SELECT Id, Name, ProductName__c, Record_Type_Name__c, RecordTypeId, LaunchDate__c, FundStrategy__c, AssetClass__c, Validity__c, VehicleType__c ' +
                                              ' FROM Product__c ' +
                                              ' WHERE Tech_NotDisplayedProductCatalog__c = false ';
    private static final String FUND_STANDARD_SCOPE = ' AND RecordTypeId = :fundRecordTypeId AND VehicleType__c = \'Funds\' '; // Le catalogue standard ne retourne que les Funds de type 'Funds'
    private static final String FUND_IS_SCOPE = ' AND InvestSolutionScope__c = true '; // Le catalogue IS accepte tous les Vehicle Types

    @AuraEnabled
    public static string getAllProducts(Boolean showSRI, Boolean showRF, Boolean showAC, String country, String assetClass, String SCType, String dividendPolicy,
                                        String legalForm, String fundType, String selectedCurrency, String searchKey, Boolean isActiveProducts, Boolean isISProducts, String sfdr) {

        CatalogFilters filters = new CatalogFilters(country, assetClass, SCType, dividendPolicy, legalForm, fundType, selectedCurrency, searchKey, isActiveProducts, isISProducts, sfdr);

        // Step 1: Share_Class__c selon les filtres et l'ISIN. Une recherche texte est résolue directement sur les Products (step 2).
        List<Share_Class__c> sharesList = new List<Share_Class__c>();
        Set<Id> fundIdsFromShares = new Set<Id>();
        if (!filters.isTextSearch()) {
            sharesList = queryShareClasses(filters);
            fundIdsFromShares = fundIdsOf(sharesList);
            if (!sharesList.isEmpty() && fundIdsFromShares.isEmpty()) return null;
        }

        // Step 2: Product__c (Funds) correspondants
        List<Product__c> filteredFunds = queryFunds(filters, fundIdsFromShares);
        if (filteredFunds.isEmpty()) return null;

        // Step 3: Recharge les Share Classes de tous les Funds trouvés par nom
        Set<Id> fundsIds = fundRecordIdsOf(filteredFunds);
        if ((sharesList.isEmpty() || filters.isTextSearch()) && !fundsIds.isEmpty()) {
            sharesList = queryShareClassesByFunds(filters, fundsIds);
        }
        if (sharesList.isEmpty()) return null;

        // Step 4: Build mappings and output
        return JSON.serialize(buildCatalog(filters, filteredFunds, sharesList));
    }

    @AuraEnabled
    public static void logClick(String buttonType) {
        UserInteractionLog__c  log = new UserInteractionLog__c(
            User__c = UserInfo.getUserId(),
            ClickDate__c = System.now(),
            ButtonType__c = buttonType
        );
        insert log;
    }

    // Share Classes filtrées, avec recherche sur l'ISIN
    private static List<Share_Class__c> queryShareClasses(CatalogFilters filters) {
        Map<String, Object> binds = new Map<String, Object>();
        String query = SHARE_CLASS_SELECT + shareClassFilterClause(filters, binds);

        if (filters.isIsin) {
            query += ' AND ISIN__c LIKE :searchLike';
            binds.put('searchLike', '%' + filters.searchKey.toUpperCase() + '%');
        }
        return (List<Share_Class__c>) Database.queryWithBinds(query + SHARE_CLASS_ORDER, binds, AccessLevel.SYSTEM_MODE);
    }

    // Share Classes (mêmes filtres, sans la recherche) des Funds donnés
    private static List<Share_Class__c> queryShareClassesByFunds(CatalogFilters filters, Set<Id> fundsIds) {
        Map<String, Object> binds = new Map<String, Object>{'fundsIds' => fundsIds};
        String query = SHARE_CLASS_SELECT + 'Fund__c IN :fundsIds AND ' + shareClassFilterClause(filters, binds);
        return (List<Share_Class__c>) Database.queryWithBinds(query + SHARE_CLASS_ORDER, binds, AccessLevel.SYSTEM_MODE);
    }

    private static List<Product__c> queryFunds(CatalogFilters filters, Set<Id> fundIdsFromShares) {
        Map<String, Object> binds = new Map<String, Object>();
        String query = FUND_SELECT;

        if (filters.isIS) {
            query += FUND_IS_SCOPE;
        } else {
            query += FUND_STANDARD_SCOPE;
            binds.put('fundRecordTypeId', fundRecordTypeId);
        }

        // Recherche texte : correspondance directe sur le Product. Sinon, en mode standard, limite aux fonds issus des Share Classes.
        if (filters.isTextSearch()) {
            query += ' AND (' + textSearchClause() + ')';
            binds.put('searchLike', '%' + filters.searchKey + '%');
        } else if (!filters.isIS && !fundIdsFromShares.isEmpty()) {
            query += ' AND Id IN :fundIdsFromShares';
            binds.put('fundIdsFromShares', fundIdsFromShares);
        }
        query = appendEquals(query, binds, 'FundStrategy__r.AssetClass__c', 'assetClass', filters.assetClass);
        query = appendEquals(query, binds, 'LegalForm__c', 'legalForm', filters.legalForm);
        query = appendEquals(query, binds, 'VehicleType__c', 'fundType', filters.fundType);
        query = appendEquals(query, binds, 'SFDRcategory__c', 'sfdr', filters.sfdr);

        return (List<Product__c>) Database.queryWithBinds(query, binds, AccessLevel.SYSTEM_MODE);
    }

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

    // Statut + filtres communs aux requêtes de Share Class
    private static String shareClassFilterClause(CatalogFilters filters, Map<String, Object> binds) {
        binds.put('activeStatuses', ACTIVE_SHARE_CLASS_STATUSES);
        String clause = filters.isActive ? 'Status__c IN :activeStatuses' : 'Status__c NOT IN :activeStatuses';
        clause = appendEquals(clause, binds, 'Currency__c', 'selectedCurrency', filters.selectedCurrency);
        clause = appendEquals(clause, binds, 'Type__c', 'scType', filters.scType);
        clause = appendEquals(clause, binds, 'DividendPolicy__c', 'dividendPolicy', filters.dividendPolicy);

        // Ne garde que les Share Classes rattachées au pays sélectionné
        if (filters.hasCountry()) {
            clause += ' AND Id IN (SELECT ShareClass__c FROM Country__c WHERE Country__c = :country)';
            binds.put('country', filters.country);
        }
        return clause;
    }

    // Recherche sur l'Internal Short Name, le Product Name ou le Name du Product (bind :searchLike)
    private static String textSearchClause() {
        return 'InternalShortName__c LIKE :searchLike OR ProductName__c LIKE :searchLike OR Name LIKE :searchLike';
    }

    // Ajoute ' AND field = :bindName' uniquement si la valeur est renseignée
    private static String appendEquals(String query, Map<String, Object> binds, String field, String bindName, String value) {
        if (String.isBlank(value)) return query;
        binds.put(bindName, value);
        return query + ' AND ' + field + ' = :' + bindName;
    }

    private static Set<Id> fundIdsOf(List<Share_Class__c> sharesList) {
        Set<Id> fundIds = new Set<Id>();
        for (Share_Class__c share : sharesList) {
            if (share.Fund__c != null) fundIds.add(share.Fund__c);
        }
        return fundIds;
    }

    private static Set<Id> fundRecordIdsOf(List<Product__c> products) {
        Set<Id> fundIds = new Set<Id>();
        for (Product__c product : products) {
            if (product.RecordTypeId == fundRecordTypeId) fundIds.add(product.Id);
        }
        return fundIds;
    }

    // Le mode IS regroupe les produits par Vehicle Type. Sinon, un filtre actif affiche la liste plate des produits, sinon l'arbre par Strategy
    private static ItemDTO buildCatalog(CatalogFilters filters, List<Product__c> filteredFunds, List<Share_Class__c> sharesList) {
        Map<Id, List<Share_Class__c>> fundToSharesMap = ProductHierarchyHelper.setFundToSharesMap(sharesList);

        if (filters.isIS) return buildISProductHierarchy(filteredFunds, fundToSharesMap);

        if (filters.hasAnyFilter()) {
            List<ItemDTO> fundItems = ProductHierarchyHelper.getFundsItemsWithSharesReferential(filteredFunds, fundToSharesMap, true);
            return new ItemDTO('All Products', null, null, null, null, null, false, true, true, true, fundItems);
        }

        // Les Strategies ne servent qu'à la vue groupée par Strategy
        List<Strategy__c> strategies = queryStrategies(filteredFunds);
        Map<Id, List<Product__c>> strategyToFundsMap = ProductHierarchyHelper.setFundStrategyToFundsMap(filteredFunds);
        List<ItemDTO> strategyItems = ProductHierarchyHelper.getAllStrategywithFundsItems(strategyToFundsMap, strategies, fundToSharesMap);
        return new ItemDTO('All Strategies', null, null, null, null, null, false, true, true, true, strategyItems);
    }

    // Construit la hiérarchie IS en regroupant les produits par Vehicle Type
    private static ItemDTO buildISProductHierarchy(List<Product__c> products, Map<Id, List<Share_Class__c>> fundToSharesMap) {
        Map<String, List<Product__c>> vehicleTypeToProducts = new Map<String, List<Product__c>>();

        // Regroupe chaque produit IS selon son VehicleType__c
        for (Product__c product : products) {
            String vehicleType = String.isBlank(product.VehicleType__c) ? 'Other' : product.VehicleType__c;

            if (!vehicleTypeToProducts.containsKey(vehicleType)) {
                vehicleTypeToProducts.put(vehicleType, new List<Product__c>());
            }
            vehicleTypeToProducts.get(vehicleType).add(product);
        }

        List<String> vehicleTypes = new List<String>(vehicleTypeToProducts.keySet());
        vehicleTypes.sort();

        // Construit un niveau de hiérarchie pour chaque Vehicle Type
        List<ItemDTO> vehicleTypeItems = new List<ItemDTO>();
        for (String vehicleType : vehicleTypes) {
            List<Product__c> vehicleProducts = vehicleTypeToProducts.get(vehicleType);
            List<ItemDTO> productItems = ProductHierarchyHelper.getFundsItemsWithSharesReferential(vehicleProducts, fundToSharesMap, false);

            for (Integer i = 0; i < productItems.size(); i++) {
                if (String.isNotBlank(vehicleProducts[i].ProductName__c)) productItems[i].label = vehicleProducts[i].ProductName__c;
            }
            vehicleTypeItems.add(new ItemDTO(vehicleType, null, null, null, null, null, false, true, true, true, productItems));
        }

        // Retourne la racine spécifique au catalogue IS
        return new ItemDTO('IS Products', null, null, null, null, null, false, true, true, true, vehicleTypeItems);
    }

    // Filtres du catalogue et dérivés de la recherche (ISIN ou texte)
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
        public Boolean isIS;
        public Boolean isIsin = false;

        public CatalogFilters(String country, String assetClass, String scType, String dividendPolicy, String legalForm, String fundType,
                              String selectedCurrency, String searchKey, Boolean isActiveProducts, Boolean isISProducts, String sfdr) {
            this.country = country;
            this.assetClass = assetClass;
            this.scType = scType;
            this.dividendPolicy = dividendPolicy;
            this.legalForm = legalForm;
            this.fundType = fundType;
            this.selectedCurrency = selectedCurrency;
            this.sfdr = sfdr;
            this.isActive = isActiveProducts == true;
            this.isIS = isISProducts == true;
            if (String.isNotBlank(searchKey)) {
                this.searchKey = searchKey.trim();
                this.isIsin = Pattern.matches(ISIN_PATTERN, this.searchKey.toUpperCase());
            }
        }

        public Boolean hasSearch() {
            return String.isNotBlank(searchKey);
        }

        public Boolean isTextSearch() {
            return hasSearch() && !isIsin;
        }

        public Boolean hasCountry() {
            return String.isNotBlank(country) && country != 'All countries';
        }

        // Vrai dès qu'un filtre ou une recherche est actif (vue liste plate plutôt que par Strategy)
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