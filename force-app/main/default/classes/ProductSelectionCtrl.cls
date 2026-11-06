/*************************************************************************************************************************
Class Name      :   ProductSelectionCtrl
Class Desc.     :   Controller Class for Lightning Component ProductTileList to handle search criteria            
Author          :   Alpha FMC

Change History
Date             Author         version             Description                                 Requested By           Tag
--------------------------------------------------------------------------------------------------------------------------
May-2018         Alpha FMC       0.01            Initial build of lightning version of class       Internal            None
***************************************************************************************************************************/

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
    
    //USED START ???
    @AuraEnabled
    public static List<Opportunity> confirmLinkedProductToOpportunity(String currentOppId) {
        String soqlQuery = 'SELECT Product_Strategy__c FROM Opportunity WHERE Id = \'' + currentOppId + '\'';
        Opportunity[] linkedProduct = Database.query(soqlQuery);
        return linkedProduct;
    }
    
    @AuraEnabled
    public static void  linkProductToOpportunity(String selectedProdId, String oppId){
        
        Opportunity opp = new Opportunity();
        opp.Product_Strategy__c =  selectedProdId;
        opp.Id = oppId;
        
        try{
            update opp;
            System.debug('SUCCESS: opp '+ opp);
        }
        catch(DMLException ex){
            AuraHandledException e = new AuraHandledException(ex.getMessage());
            throw e;
        }
    }
    //USED END ???
    
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
    
    @AuraEnabled
    public static List<Work_Together_Process_Product__c> confirmLinkedProductsToWTP(String currentWTPId){
        String soqlQuery = 'SELECT Id, Work_Together_Process__c, Product__c, Product__r.Name, Product__r.RecordType.Name FROM Work_Together_Process_Product__c WHERE Work_Together_Process__c = \'' + currentWTPId + '\'';
        Work_Together_Process_Product__c[] linkedProducts = Database.query(soqlQuery);
        System.debug('linkedProducts to WTP: ' + linkedProducts);
        return linkedProducts;
    }
    
    @AuraEnabled
    public static void  linkProductsToWTP(
            List<Work_Together_Process_Product__c> insertProductList,
            List<Work_Together_Process_Product__c> deleteProductList,
            List<Id> selectedShares,
            Id wtpId){
        System.debug('SelectedShares '+ selectedShares);
        System.debug('BP ' + insertProductList);
        System.debug('wtpId ' + wtpId);
        List<Work_Together_Process_Product__c> insertProducts = new List<Work_Together_Process_Product__c>();
        List<Work_Together_Process_Product__c> deleteProducts = new List<Work_Together_Process_Product__c>();
        insertProducts.addAll(insertProductList);
        deleteProducts.addAll(deleteProductList);

        try{
            delete deleteProductList;
            insert insertProducts;
            updateShareProducts(selectedShares, wtpId);
        }
        catch(DMLException ex){
            AuraHandledException e = new AuraHandledException(ex.getMessage());
            system.debug('AuraEx : '+ ex.getMessage());
            throw e;
        } 
    }

    public static void updateShareProducts(List<Id> sharesIds, Id wtpId)
    {
        Set<Id> currentShares = getCurrentShares(wtpId);

        List<Case_Share__c> shareToDelete = itemsToDelete(currentShares, sharesIds, wtpId);

        List<Case_Share__c> shareToInsert = itemsToInsert(currentShares, sharesIds, wtpId);

        insert shareToInsert;
        delete shareToDelete;
    }

    public static Set<Id> getCurrentShares(Id wtpId)
    {
        Set<Id> currentSharesIds = new Set<Id>();

        Case caseWithShares = [
                SELECT Id, (SELECT Share_Class__c FROM Case_Shares__r)
                FROM Case
                WHERE Id = : wtpId
        ];

        for(Case_Share__c share : caseWithShares.Case_Shares__r)
        {
            currentSharesIds.add(share.Share_Class__c);
        }

        return currentSharesIds;
    }

    public static List<Case_Share__c> itemsToDelete(Set<Id> currentSharesIds, List<Id> sharesIds, Id wtpId)
    {
        Set<Id> sharesSet = new Set<Id>(sharesIds);
        List<Id> sharesToDelete = new List<Id>();

        for(Id shareId : currentSharesIds)
        {
            if(!sharesSet.contains(shareId))
            {
                sharesToDelete.add(shareId);
            }
        }

        List<Case_Share__c> itemsToDelete = [
                SELECT Id
                FROM Case_Share__c
                WHERE Share_Class__c IN : sharesToDelete
                AND Work_Together_Process__c = : wtpId
        ];

        return itemsToDelete;
    }

    public static List<Case_Share__c> itemsToInsert(Set<Id> currentSharesIds, List<Id> sharesIds, Id wtpId)
    {
        List<Case_Share__c> sharesToInsert = new List<Case_Share__c>();

        for(Id shareId : sharesIds)
        {
            if(!currentSharesIds.contains(shareId))
            {
                sharesToInsert.add(createShareProduct(shareId, wtpId));
            }
        }

        return sharesToInsert;
    }

    public static Case_Share__c createShareProduct(Id shareClassId, Id wtpId)
    {
        Case_Share__c shareProduct = new Case_Share__c(
                Share_Class__c = shareClassId,
                Work_Together_Process__c = wtpId);

        return shareProduct;
    }
    //START : JLC MODIFICATION : 14/06/2022 
    //Description: This method returns the list of all products without the filters. 
    @AuraEnabled
    public static List<Product__c> getProductListUnfiltered(){
        return [SELECT Id, Name, LegalForm__c, /*Asset_Class__c, Asset_Class__r.Name, Strategy__c, Strategy__r.Name,*/ RecordType.DeveloperName, RecordType.Name 
                FROM Product__c 
                WHERE Validity__c = true]; //AND RecordType.Name='Strategy' AND Dedicated_Fund__c = false];
    }    
    //END : JLC MODIFICATION : 14/06/2022
}