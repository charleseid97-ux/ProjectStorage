/*************************************************************************************************************************
Class Name      :   ProductSelectionCtrl
Class Desc.     :   Controller Class for Lightning Component ProductTileList to handle search criteria            
Author          :   Alpha FMC

Change History
Date             Author         version             Description                                 Requested By           Tag
--------------------------------------------------------------------------------------------------------------------------
May-2018         Alpha FMC       0.01            Initial build of lightning version of class       Internal            None
Nov-2026         Charles EID     0.02            WTP methods out (WTP products are picked in the WTP_Product_Selector flow), unused Product_Strategy__c methods out    Internal    US-20300
***************************************************************************************************************************/
/** ──────────────────────────────────────
 * @testClass ProductSelectionCtrlTest
 * @coverage 85%   [25-11-26]
 * @lastModifiedBy Charles EID   [25-11-26]
 ────────────────────────────────────── */

global with sharing class ProductSelectionCtrl {
    
    public class PagedResult {
        @AuraEnabled
        public Integer pageSize { get;set; }
        @AuraEnabled
        public Integer page { get;set; }
        @AuraEnabled
        public Integer total { get;set; }
        @AuraEnabled
        public List<Product__c> products { get;set; }
        @AuraEnabled
        public Set<Product__c> macro_strategies { get;set; }
        @AuraEnabled
        public Set<Product__c> strategies { get;set; }
        @AuraEnabled
        public Set<Product__c> asset_classes { get;set; }
        @AuraEnabled
        public Set<Product__c> sub_asset_classes { get;set; }
    }
    
    public class Filter {
        @AuraEnabled
        public String searchKey { get;set; }
        @AuraEnabled
        public String assetClass { get;set; }
        @AuraEnabled
        public String subAssetClass { get;set; }
        @AuraEnabled
        public String strategy { get;set; }
        @AuraEnabled
        public Boolean sri { get;set; }
        @AuraEnabled
        public Boolean oeic { get;set; }
    }

    //changed from getFunds
    @AuraEnabled
    public static PagedResult getProducts(String filters, Decimal pageSize, Decimal pageNumber) {
        if (pageSize == null || pageSize <= 0 || pageNumber == null || pageNumber <= 0) {
            throw new AuraHandledException('pageSize and pageNumber must be greater than zero.');
        }

        Filter filter = (Filter) JSON.deserializeStrict(filters, ProductSelectionCtrl.Filter.class);
        Integer pSize = (Integer) pageSize;
        Integer currentPage = (Integer) pageNumber;
        Integer queryOffset = (currentPage - 1) * pSize;

        PagedResult result = new PagedResult();
        result.pageSize = pSize;
        result.page = currentPage;

        String searchKey = String.isBlank(filter.searchKey) ? null : filter.searchKey.trim();
        String searchPattern = searchKey == null ? null : '%' + searchKey + '%';

        List<String> whereClauses = new List<String>{'RecordType.DeveloperName = \'Fund\'', 'Validity__c = true'};
        if (searchPattern != null) whereClauses.add('Name LIKE :searchPattern');

        String baseSoql = 'SELECT Id, Name, LegalForm__c, RecordType.DeveloperName, RecordType.Name ' +
                          'FROM Product__c WHERE ' + String.join(whereClauses, ' AND ');
        String pagedSoql = baseSoql + ' ORDER BY Name ASC, Id ASC' +
                                      ' LIMIT :pSize OFFSET :queryOffset';

        List<Product__c> totalProducts = Database.query(baseSoql);
        List<Product__c> pageProducts = Database.query(pagedSoql);

        Map<Id, Product__c> macroStrategiesById = new Map<Id, Product__c>();

        for (Product__c product : totalProducts) {
            String recordTypeDeveloperName = product.RecordType.DeveloperName;
            if (recordTypeDeveloperName == 'Fund') macroStrategiesById.put(product.Id, product);
        }

        result.products = pageProducts;
        result.macro_strategies = new Set<Product__c>(macroStrategiesById.values());
        result.total = totalProducts.size();

        return result;
    }
    
    @AuraEnabled
    public static List<Opportunity_Product__c> confirmLinkedProductsToOpp(String currentOppId){
        String soqlQuery = 'SELECT Id, Opportunity__c, Product__c, Product__r.Name, Product__r.RecordType.Name FROM Opportunity_Product__c WHERE Opportunity__c = \'' + currentOppId + '\'';
        Opportunity_Product__c[] linkedProducts = Database.query(soqlQuery);
        System.debug('linkedProducts to Opp: ' + linkedProducts);
        return linkedProducts;
    }
    
    @AuraEnabled
    public static void  linkProductsToOpp(list<Opportunity_Product__c> insertProductList, list<Opportunity_Product__c> deleteProductList){
        
        List<Opportunity_Product__c> insertProducts = new List<Opportunity_Product__c>();
        List<Opportunity_Product__c> deleteProducts = new List<Opportunity_Product__c>();
        insertProducts.addAll(insertProductList);
        deleteProducts.addAll(deleteProductList);

        try{
            delete deleteProductList;
            insert insertProducts;
        }catch(DMLException ex){
            AuraHandledException e = new AuraHandledException(ex.getMessage());
            system.debug('AuraEx : '+ ex.getMessage());
            throw e;
        } 
    }
}