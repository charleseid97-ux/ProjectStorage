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
        Id assetClassId = String.isBlank(filter.assetClass) ? null : (Id) filter.assetClass.trim();
        Id strategyId = String.isBlank(filter.strategy) ? null : (Id) filter.strategy.trim();
        Boolean isOeic = filter.oeic == true;

        // Id subAssetClassId = String.isBlank(filter.subAssetClass) ? null : (Id) filter.subAssetClass.trim(); // Disabled: Sub_Asset_Class__c was removed.
        // Boolean isSri = filter.sri == true; // Disabled: SRI__c was removed.

        String targetRecordType = isOeic ? 'Fund' : 'Strategy';
        List<String> whereClauses = new List<String>{'RecordType.DeveloperName = :targetRecordType', 'Validity__c = true'};

        if (searchPattern != null) whereClauses.add('(Name LIKE :searchPattern OR Strategy__r.Name LIKE :searchPattern)');
        if (assetClassId != null) whereClauses.add('(Id = :assetClassId OR Asset_Class__c = :assetClassId)');
        // if (subAssetClassId != null) whereClauses.add('(Id = :subAssetClassId OR Sub_Asset_Class__c = :subAssetClassId)'); // Disabled: Sub_Asset_Class__c was removed.
        if (strategyId != null) whereClauses.add('(Id = :strategyId OR Strategy__c = :strategyId)');
        // if (isSri) whereClauses.add('SRI__c = true'); // Disabled: SRI__c was removed.

        String baseSoql = 'SELECT Id, Name, LegalForm__c, Asset_Class__c, Asset_Class__r.Name, ' +
                          'Strategy__c, Strategy__r.Name, RecordType.DeveloperName, RecordType.Name ' +
                          'FROM Product__c WHERE ' + String.join(whereClauses, ' AND ');
        String pagedSoql = baseSoql + ' ORDER BY Name ASC, Id ASC' +
                                      ' LIMIT :pSize OFFSET :queryOffset';

        System.debug(LoggingLevel.DEBUG, 'Product query: ' + pagedSoql);

        List<Product__c> totalProducts = Database.query(baseSoql);
        List<Product__c> pageProducts = Database.query(pagedSoql);

        Map<Id, Product__c> strategiesById = new Map<Id, Product__c>();
        Map<Id, Product__c> macroStrategiesById = new Map<Id, Product__c>();

        for (Product__c product : totalProducts) {
            if (strategyId != null && (product.Id == strategyId || product.Strategy__c == strategyId)) product.IsSelectedFilter__c = true;
            if (product.Strategy__c != null && product.Strategy__r != null) strategiesById.put(product.Strategy__c, product.Strategy__r);

            String recordTypeDeveloperName = product.RecordType.DeveloperName;
            if (recordTypeDeveloperName == 'Strategy') strategiesById.put(product.Id, product);
            if (recordTypeDeveloperName == 'Fund') macroStrategiesById.put(product.Id, product);
            // if (recordTypeDeveloperName == 'Asset_Class') assetClassesById.put(product.Id, product); // Disabled: this record type is not retrieved by the query.
            // if (recordTypeDeveloperName == 'Sub_Asset_Class') subAssetClassesById.put(product.Id, product); // Disabled: this record type is not retrieved by the query.
        }

        for (Product__c product : pageProducts) {
            if (strategyId != null && (product.Id == strategyId || product.Strategy__c == strategyId)) product.IsSelectedFilter__c = true;
        }

        result.products = pageProducts;
        result.asset_classes = new Set<Product__c>();
        result.sub_asset_classes = new Set<Product__c>();
        result.strategies = new Set<Product__c>(strategiesById.values());
        result.macro_strategies = new Set<Product__c>(macroStrategiesById.values());
        result.total = totalProducts.size();

        return result;
    }
    
    //changed from getFunds
    /*@AuraEnabled
    public static PagedResult getInvestmentStrategies(String filters, Decimal pageSize, Decimal pageNumber) {
        
        Filter filter = (Filter) JSON.deserializeStrict(filters, ProductSelectionCtrl.Filter.class);
        System.Debug('Filters: ' + filters);
        Integer pSize = (Integer)pageSize;
        Integer offset = ((Integer)pageNumber - 1) * pSize;
        PagedResult r =  new PagedResult();
        r.pageSize = pSize;
        r.page = (Integer) pageNumber;      
                
        String key =  filter.searchKey;
        
        String strategyID = filter.strategy; 
        
        //subqueries   
        String searchStringSubQuery = '';
        String strategySubQuery = '';

        
 		//added for Investment Divs
 		searchStringSubQuery = (key != '' ? '(Name LIKE \'%' + key + '%\' OR Strategy__r.Name LIKE \'%' + key + '%\' )' : '');        
 		
        strategySubQuery = (strategyID != '' ? '( Id = \'' +strategyID+ '\' ) ' : '');
        
        
        //added for Investment Divs
        map<String, Id> recordTypes = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Product__c.SObjectType);
        String strategyRecordTypeId = recordTypes.get('Strategy');
        
        String SOQLStrTotal = 'SELECT id, Name, Asset_Class__c, Asset_Class__r.Name, Strategy__c, Strategy__r.Name, RecordType.DeveloperName, RecordType.Name FROM Product__c '
            + 'WHERE RecordType.DeveloperName = \'Strategy\' '
            + (searchStringSubQuery == '' && strategySubQuery == '' ? '' : 'AND ' )
            + (searchStringSubQuery != '' ? searchStringSubQuery : '' )
            + (strategySubQuery != '' ? strategySubQuery : '');
            
            
        String SOQLStr = 'SELECT id, Name, Asset_Class__c, Asset_Class__r.Name, Strategy__c, Strategy__r.Name, RecordType.DeveloperName, RecordType.Name FROM Product__c '
             + 'WHERE RecordType.DeveloperName = \'Strategy\' '
            + (searchStringSubQuery == '' && strategySubQuery == '' ? '' : 'AND ' )
            + (searchStringSubQuery != '' ? searchStringSubQuery : '' )
            + (strategySubQuery != '' ? strategySubQuery : '')   
            + (' LIMIT :pSize OFFSET :offset' );
            
        System.debug('QUERY IS: ' + SOQLStr);
        
        list<Product__c> totalProds =  database.query(SOQLStrTotal);
        list<Product__c> pageProds =  database.query(SOQLStr);
        // list<Product__c> stratProds =  new list<Product__c>();
        
        
        map<id, product__c> sMap = new map<id, product__c>();
        
        
        for(Product__c prod : totalProds)
        {
            //let's check if it was the selected filter, if so set the IsSelectedFilter__c attribute
            String prodIdString = (String) prod.Id;
            if(prodIdString == strategySubQuery  ) 
            {
                prod.IsSelectedFilter__c = true;
                
            }
            
            if(prod.Strategy__c != null){
                sMap.put(prod.Strategy__c, prod.Strategy__r);
            }
            
            if (prod.RecordType.DeveloperName == 'Strategy'){
                sMap.put(prod.id, prod);
            }
            
            if (prod.RecordType.DeveloperName == 'Asset_Class'){
                sMap.put(prod.id, prod);
            }
            
        }   
        
        r.products = pageProds;       
        r.strategies = new Set <Product__c> (sMap.values());
        r.total = totalProds.size(); 
        
        return r;

    }*/
        
    @AuraEnabled
    public static List<Product__c> getStrategies() {
        
        map<String, Id> recordTypes = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Product__c.SObjectType);
        Product__c[] strategies = [Select Id, Name, RecordType.DeveloperName from Product__c where RecordTypeId = : recordTypes.get('Strategy')];
        return strategies; 
    }
    
    @AuraEnabled
    public static List<Product__c> getAssetClasses() {
        
        map<String, Id> recordTypes = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Product__c.SObjectType);
        
        Product__c[] assetClasses = [Select Id, Name from Product__c where RecordTypeId = : recordTypes.get('Asset_Class')];
        return assetClasses;
    }
    
    @AuraEnabled
    public static List<Product__c> getSubAssetClasses() {
        
        
        map<String, Id> recordTypes = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Product__c.SObjectType);
        Product__c[] subAssetClasses = [Select Id, Name from Product__c where RecordTypeId = : recordTypes.get('Sub_Asset_Class')];
        
        return subAssetClasses;
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
        return [SELECT Id, Name, LegalForm__c, Asset_Class__c, Asset_Class__r.Name, Strategy__c, Strategy__r.Name, RecordType.DeveloperName, RecordType.Name 
                FROM Product__c 
                WHERE RecordType.Name='Strategy' AND Validity__c = true]; //AND Dedicated_Fund__c = false];
    }    
    //END : JLC MODIFICATION : 14/06/2022
}