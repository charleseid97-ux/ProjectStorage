/**
 * @description Dedicated controller for Product Catalog Excel exports.
 *              Applies record sharing and masks fields not readable by the current user.
 */
public with sharing class ReferentialProductExportCtrl {

    private static final String MASKED_VALUE = '***';
    private static final List<String> ACTIVE_SHARE_CLASS_STATUSES = new List<String>{'Active', 'Active - Lab'};
    private static final Id FUND_RECORD_TYPE_ID = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();

    /**
     * Returns the Share Classes matching the Product Catalog filters for Excel export.
     */
    @AuraEnabled
    public static List<ExportRow> getExportRows(String country, String assetClass, String scType, String dividendPolicy,
                                                 String legalForm, String fundType, String selectedCurrency, String searchKey,
                                                 Boolean isActiveProducts, String sfdr) {
        ExportFilters filters = new ExportFilters(country, assetClass, scType, dividendPolicy, legalForm, fundType,
                                                  selectedCurrency, searchKey, isActiveProducts, sfdr);
        List<Share_Class__c> shareClasses = queryShareClasses(filters);
        List<ExportRow> rows = new List<ExportRow>();

        for (Share_Class__c shareClassRecord : shareClasses) {
            rows.add(new ExportRow(shareClassRecord));
        }
        return rows;
    }

    /**
     * Queries the same Share Class population as the Product Catalog while respecting record sharing.
     */
    private static List<Share_Class__c> queryShareClasses(ExportFilters filters) {
        Map<String, Object> binds = new Map<String, Object>{'fundRecordTypeId' => FUND_RECORD_TYPE_ID};
        String query = 'SELECT Id, Name, ISIN__c, Type__c, InvestorType__c, Currency__c, SRI__c, SRRI__c, ' +
                       'Share_Class_Inception_Date__c, BloombergCode__c, WKNCode__c, CUSIPCode__c, CITICode__c, ' +
                       'ValorenCode__c, SEDOLCode__c, MorningstarCode__c, Status__c, ' +
                       'Fund__c, Fund__r.ProductName__c, Fund__r.InternalShortName__c, Fund__r.LegalForm__c, ' +
                       'Fund__r.LaunchDate__c, Fund__r.CutOffTime__c, Fund__r.SFDRcategory__c, ' +
                       'Fund__r.FundStrategy__r.Name, Fund__r.FundStrategy__r.AssetClass__c, ' +
                       'Fund__r.FundStrategy__r.SubAssetClass__c ' +
                       'FROM Share_Class__c WHERE ';

        binds.put('activeStatuses', ACTIVE_SHARE_CLASS_STATUSES);
        query += filters.isActive ? 'Status__c IN :activeStatuses' : 'Status__c NOT IN :activeStatuses';
        query = appendEquals(query, binds, 'Currency__c', 'selectedCurrency', filters.selectedCurrency);
        query = appendEquals(query, binds, 'Type__c', 'scType', filters.scType);
        query = appendEquals(query, binds, 'DividendPolicy__c', 'dividendPolicy', filters.dividendPolicy);

        if (filters.hasCountry()) {
            query += ' AND Id IN (SELECT ShareClass__c FROM Country__c WHERE Country__c = :country)';
            binds.put('country', filters.country);
        }

        query += ' AND Fund__c != null';
        query += ' AND Fund__r.Tech_NotDisplayedProductCatalog__c = false';
        query += ' AND Fund__r.RecordTypeId = :fundRecordTypeId';
        query += ' AND Fund__r.VehicleType__c = \'Funds\'';
        query = appendEquals(query, binds, 'Fund__r.FundStrategy__r.AssetClass__c', 'assetClass', filters.assetClass);
        query = appendEquals(query, binds, 'Fund__r.LegalForm__c', 'legalForm', filters.legalForm);
        query = appendEquals(query, binds, 'Fund__r.VehicleType__c', 'fundType', filters.fundType);
        query = appendEquals(query, binds, 'Fund__r.SFDRcategory__c', 'sfdr', filters.sfdr);

        if (filters.hasSearch()) {
            query += ' AND (ISIN__c LIKE :searchLike OR Fund__r.InternalShortName__c LIKE :searchLike ' +
                     'OR Fund__r.ProductName__c LIKE :searchLike OR Fund__r.Name LIKE :searchLike)';
            binds.put('searchLike', '%' + filters.searchKey + '%');
        }
        return (List<Share_Class__c>) Database.queryWithBinds(query + ' ORDER BY Primary_Portfolio_Share_Class__c DESC', binds, AccessLevel.SYSTEM_MODE);
    }

    /**
     * Adds an equality filter only when the filter has a value.
     */
    private static String appendEquals(String query, Map<String, Object> binds, String fieldName, String bindName, String value) {
        if (String.isBlank(value)) return query;
        binds.put(bindName, value);
        return query + ' AND ' + fieldName + ' = :' + bindName;
    }

    /**
     * Returns a Share Class value when readable, otherwise masks it.
     */
    private static Object getShareClassValue(Share_Class__c record, Schema.SObjectField fieldToken) {
        if (!fieldToken.getDescribe().isAccessible()) return MASKED_VALUE;
        return record.get(fieldToken);
    }

    /**
     * Returns a Product value when readable, otherwise masks it.
     */
    private static Object getProductValue(Product__c record, Schema.SObjectField fieldToken) {
        if (!fieldToken.getDescribe().isAccessible()) return MASKED_VALUE;
        if (record == null) return null;
        return record.get(fieldToken);
    }

    /**
     * Returns a Strategy value when readable, otherwise masks it.
     */
    private static Object getStrategyValue(Strategy__c record, Schema.SObjectField fieldToken) {
        if (!fieldToken.getDescribe().isAccessible()) return MASKED_VALUE;
        if (record == null) return null;
        return record.get(fieldToken);
    }

    /**
     * Holds the Product Catalog filters used by the export query.
     */
    private class ExportFilters {
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

        /**
         * Builds a normalized filter set from the LWC parameters.
         */
        public ExportFilters(String country, String assetClass, String scType, String dividendPolicy, String legalForm,
                             String fundType, String selectedCurrency, String searchKey, Boolean isActiveProducts, String sfdr) {
            this.country = country;
            this.assetClass = assetClass;
            this.scType = scType;
            this.dividendPolicy = dividendPolicy;
            this.legalForm = legalForm;
            this.fundType = fundType;
            this.selectedCurrency = selectedCurrency;
            this.searchKey = String.isBlank(searchKey) ? null : searchKey.trim();
            this.sfdr = sfdr;
            this.isActive = isActiveProducts == true;
        }

        /**
         * Indicates whether a text search must be applied.
         */
        public Boolean hasSearch() {
            return String.isNotBlank(searchKey);
        }

        /**
         * Indicates whether a country filter must be applied.
         */
        public Boolean hasCountry() {
            return String.isNotBlank(country) && country != 'All countries';
        }
    }

    /**
     * Represents one Excel row and applies FLS masking to every exported field.
     */
    public class ExportRow {
        @AuraEnabled public Object fund;
        @AuraEnabled public Object internalShortName;
        @AuraEnabled public Object legalForm;
        @AuraEnabled public Object assetClass;
        @AuraEnabled public Object subAssetClass;
        @AuraEnabled public Object strategy;
        @AuraEnabled public Object isin;
        @AuraEnabled public Object shareClassName;
        @AuraEnabled public Object shareClassType;
        @AuraEnabled public Object investorType;
        @AuraEnabled public Object currencyValue;
        @AuraEnabled public Object sri;
        @AuraEnabled public Object srri;
        @AuraEnabled public Object fundInceptionDate;
        @AuraEnabled public Object shareClassInceptionDate;
        @AuraEnabled public Object cutOffTime;
        @AuraEnabled public Object bloombergCode;
        @AuraEnabled public Object wknCode;
        @AuraEnabled public Object cusipCode;
        @AuraEnabled public Object citiCode;
        @AuraEnabled public Object valorenCode;
        @AuraEnabled public Object sedolCode;
        @AuraEnabled public Object morningstarCode;
        @AuraEnabled public Object sfdrCategory;
        @AuraEnabled public Object lifecycleStatus;

        /**
         * Builds a secured export row from a Share Class and its related Fund and Strategy.
         */
        public ExportRow(Share_Class__c shareClassRecord) {
            Product__c fundRecord = shareClassRecord.Fund__r;
            Strategy__c strategyRecord = fundRecord == null ? null : fundRecord.FundStrategy__r;

            fund = getProductValue(fundRecord, Product__c.ProductName__c);
            internalShortName = getProductValue(fundRecord, Product__c.InternalShortName__c);
            legalForm = getProductValue(fundRecord, Product__c.LegalForm__c);
            assetClass = getStrategyValue(strategyRecord, Strategy__c.AssetClass__c);
            subAssetClass = getStrategyValue(strategyRecord, Strategy__c.SubAssetClass__c);
            strategy = getStrategyValue(strategyRecord, Strategy__c.Name);
            isin = getShareClassValue(shareClassRecord, Share_Class__c.ISIN__c);
            shareClassName = getShareClassValue(shareClassRecord, Share_Class__c.Name);
            shareClassType = getShareClassValue(shareClassRecord, Share_Class__c.Type__c);
            investorType = getShareClassValue(shareClassRecord, Share_Class__c.InvestorType__c);
            currencyValue = getShareClassValue(shareClassRecord, Share_Class__c.Currency__c);
            sri = getShareClassValue(shareClassRecord, Share_Class__c.SRI__c);
            srri = getShareClassValue(shareClassRecord, Share_Class__c.SRRI__c);
            fundInceptionDate = getProductValue(fundRecord, Product__c.LaunchDate__c);
            shareClassInceptionDate = getShareClassValue(shareClassRecord, Share_Class__c.Share_Class_Inception_Date__c);
            cutOffTime = getProductValue(fundRecord, Product__c.CutOffTime__c);
            bloombergCode = getShareClassValue(shareClassRecord, Share_Class__c.BloombergCode__c);
            wknCode = getShareClassValue(shareClassRecord, Share_Class__c.WKNCode__c);
            cusipCode = getShareClassValue(shareClassRecord, Share_Class__c.CUSIPCode__c);
            citiCode = getShareClassValue(shareClassRecord, Share_Class__c.CITICode__c);
            valorenCode = getShareClassValue(shareClassRecord, Share_Class__c.ValorenCode__c);
            sedolCode = getShareClassValue(shareClassRecord, Share_Class__c.SEDOLCode__c);
            morningstarCode = getShareClassValue(shareClassRecord, Share_Class__c.MorningstarCode__c);
            sfdrCategory = getProductValue(fundRecord, Product__c.SFDRcategory__c);
            lifecycleStatus = getShareClassValue(shareClassRecord, Share_Class__c.Status__c);
        }
    }
}
