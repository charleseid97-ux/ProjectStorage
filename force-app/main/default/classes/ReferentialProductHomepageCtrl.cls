public class ReferentialProductHomepageCtrl {

    static final Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();  
    static final Id assetClassRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Asset_Class').getRecordTypeId();  
    static final Id regionalRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Sub_Asset_Class').getRecordTypeId();  
    
    /*@AuraEnabled
    public static string getAllProducts(boolean showSRI, boolean showRF, boolean showAC, string country, String assetClass,String SCType, String legalForm, String fundType, String selectedCurrency, String searchKey,
    Boolean isActiveProducts, Boolean isRI)
    {

        productHierarchyController.ItemDTO allStratgies = new productHierarchyController.ItemDTO();

        String baseQuery = 'SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name,RecordTypeId, ' +
        'Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, ' +
        'Asset_Class__c, Asset_Class__r.Name, FundStrategy__c, FundStrategy__r.Name,AssetClass__c,SubAssetClass__c, ' +
        'FundStrategy__r.InvestmentStyle__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, ' +
        'Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Investment_Style__c, ' +
        'Validity__c, Strategy__r.Validity__c, Asset_Class__r.Validity__c, Sub_Asset_Class__r.Validity__c, ' +
        'Last_AUM_Previous_Year__c, Last_AUM_Available__c, YTD_Net_Flows__c, LegalForm__c, VehicleType__c, SFDRcategory__c ' +
        'FROM Product__c ';

        // Appliquer les filtres
        if (isActiveProducts) {
            baseQuery += ' WHERE Validity__c = TRUE';
        }else{
            baseQuery += ' WHERE Validity__c = FALSE';
        }
        if (String.isNotBlank(assetClass)) {
            baseQuery += ' AND FundStrategy__r.AssetClass__c = :assetClass';
        }
        if (String.isNotBlank(legalForm)) {
            system.debug('legalForm :'+ legalForm);
            baseQuery += ' AND (LegalForm__c = :legalForm OR Legal_Status__c = :legalForm)';
        }
        if (String.isNotBlank(fundType)) {
            system.debug('fundType :'+ fundType);
            baseQuery += ' AND VehicleType__c = :fundType';
        }
        Boolean isIsin = false;
        if (String.isNotBlank(searchKey)) {
            if (Pattern.matches('^[A-Z]{2}[0-9]{1,10}$', searchKey.trim().toUpperCase())) {
                isIsin = true;
            }
        }
        system.debug('isIsin '+isIsin);
        system.debug('searchKey '+searchKey);
        if (String.isNotBlank(searchKey) && (isIsin == false || searchKey.length()<2)) {
            system.debug('product');
            baseQuery += ' AND (Name LIKE \'%'+  searchKey + '%\' OR Product_Name__c LIKE \'%'+  searchKey + '%\')';
        }
        if (isRI) {
            baseQuery += ' AND (SFDRcategory__c  IN (\'8\', \'9\') OR ESGLabel__c!= NULL OR  ESGMainFocus__c!= NULL)';
        }
        List<Product__c> productList = Database.query(baseQuery);                                       
        system.debug('productList :'+ productList);
        Map<Id, Strategy__c> strategies = new Map<Id, Strategy__c>();

        Map<Id, Product__c> funds = new Map<Id, Product__c>();

        Map<Id, Product__c> assetClasses = new Map<Id, Product__c>();

        Map<Id, Product__c> regionalFocuses = new Map<Id, Product__c>();

        Set<ID> strategyIds = new Set<ID>();
        Set<ID> fundsIds = new Set<ID>();

        for (Product__c p : productList) {
            if (p.FundStrategy__c != null) {
                strategyIds.add(p.FundStrategy__c);
            }
            if(p.RecordTypeId == fundRecordTypeId && p.FundStrategy__c != null){
                funds.put(p.Id, p);
                fundsIds.add(p.Id);
            }else if(p.RecordTypeId == assetClassRecordTypeId){
                assetClasses.put(p.Id, p);
            }else if(p.RecordTypeId == regionalRecordTypeId){
                regionalFocuses.put(p.Id, p);
            }
        }

        strategies =  new Map<Id, Strategy__c>([SELECT Id, Name, InvestmentStyle__c,AssetClass__c,SubAssetClass__c FROM Strategy__c Where Id IN :strategyIds ]);
        system.debug('strategies : '+strategies);
        List<Share_Class__c> sharesList = new List<Share_Class__c>();
        
        String shareQuery = 'SELECT Id, Name, Fund__c, Validity__c, ISIN__c, ' +
        'Last_AUM_Previous_Year__c, Last_AUM_Available__c, YTD_Net_Flows__c, CurrencyIsoCode ' +
        'FROM Share_Class__c WHERE Fund__c IN :fundsIds ';

        if (isActiveProducts) {
            system.debug('active');
            shareQuery += ' AND Validity__c = TRUE';
        }else{
            system.debug('not active');
            shareQuery += ' AND Validity__c = FALSE';
        }
        if (String.isNotBlank(country) && country != 'All countries') {
            shareQuery += ' AND Country__c INCLUDES (:country)';
        }
        if (String.isNotBlank(selectedCurrency)) {
            shareQuery += ' AND CurrencyIsoCode = :selectedCurrency';
        }
        if (String.isNotBlank(SCType)) {
            shareQuery += ' AND Share_Class_Type__c = :SCType';
        }
        if (String.isNotBlank(searchKey) && (isIsin || searchKey.length()<2) ) {
            shareQuery += ' AND ISIN__c LIKE \'%' + String.escapeSingleQuotes(searchKey.trim().toUpperCase()) + '%\'';
        }
        system.debug('fundsId : '+fundsIds);
        system.debug('shareQuery : '+shareQuery);
        sharesList = Database.query(shareQuery);
        system.debug('sharesList : '+sharesList);
        // put shares in a map of Fund => Shares 
        Map<Id, List<Share_Class__c>> fundToSharesMap = ProductHierarchyHelper.setFundToSharesMap(sharesList);
        system.debug('fundToSharesMap : '+fundToSharesMap);
        // put funds in a map of Strategy => Funds                                                                    
        Map<Id, List<Product__c>> strategyTofundsMap = ProductHierarchyHelper.setFundStrategyToFundsMap(funds.values());
        system.debug('strategyTofundsMap : '+strategyTofundsMap);
        List<productHierarchyController.ItemDTO> highLevelItems = new List<productHierarchyController.ItemDTO>();

        if(String.isNotBlank(searchKey)){
            highLevelItems = ProductHierarchyHelper.getFundsItemsWithSharesReferential(funds.values(), fundToSharesMap, true);
        
            allStratgies = new productHierarchyController.ItemDTO('All Products', null, null, null, null, null, false,
            true, true, true, highLevelItems);
        }
       else{
            highLevelItems = ProductHierarchyHelper.getAllStrategywithFundsItems(strategyTofundsMap, strategies, fundToSharesMap);
            
            allStratgies = new productHierarchyController.ItemDTO('All Strategies', null, null, null, null, null, false,
            true, true, true, highLevelItems);
       }
        

        system.debug('allStratgies :' +JSON.serialize(allStratgies));
        if(fundsIds.size()>0){
            return JSON.serialize(allStratgies);
        }else{
            return null;
        }
        
    }*/

    @AuraEnabled
    public static string getAllProducts(
                                        Boolean showSRI, Boolean showRF, Boolean showAC,
                                        String country, String assetClass, String SCType,
                                        String dividendPolicy,
                                        String legalForm, String fundType, String selectedCurrency,
                                        String searchKey, Boolean isActiveProducts, String sfdr) {

        productHierarchyController.ItemDTO allStrategies = new productHierarchyController.ItemDTO();

        // Step 1: Query Share_Class__c based on filters
        String shareQuery = 'SELECT Id, Name, Fund__c, Status__c,TechIsActive__c, ISIN__c, Fund__r.AssetClass__c, Fund__r.SubAssetClass__c, ' +
        'Last_AUM_Previous_Year__c, Last_AUM_Available__c, YTD_Net_Flows__c, CurrencyIsoCode,Currency__c, Country__c, Type__c ' +
        ', (SELECT Id,Country__c FROM Countries__r) '+
        'FROM Share_Class__c WHERE TechIsActive__c =:isActiveProducts';

        /*if (String.isNotBlank(country) && country != 'All countries') {
            shareQuery += ' AND Country__c INCLUDES (:country)';
        }*/
        if (String.isNotBlank(selectedCurrency)) {
            shareQuery += ' AND Currency__c = :selectedCurrency';
        }
        if (String.isNotBlank(SCType)) {
            shareQuery += ' AND Type__c = :SCType';
        }
        if (String.isNotBlank(dividendPolicy)) {
            shareQuery += ' AND DividendPolicy__c = :dividendPolicy';
        }
        
        Boolean isIsin = false;
        if (String.isNotBlank(searchKey)) {
            isIsin = Pattern.matches('^[A-Z]{2}[0-9]{1,10}$', searchKey.trim().toUpperCase());
        if (String.isNotBlank(searchKey) ){
            system.debug('here share classe '+searchKey);
            shareQuery += ' AND ISIN__c LIKE \'%' + String.escapeSingleQuotes(searchKey.trim().toUpperCase()) + '%\'';
        }
        }
        shareQuery += ' ORDER BY Primary_Portfolio_Share_Class__c desc';
        List<Share_Class__c> sharesList = new List<Share_Class__c>();
        sharesList = Database.query(shareQuery);
        system.debug('sharesList : '+sharesList);
        List<Share_Class__c> filteredSharesList = new List<Share_Class__c>();

        if (String.isNotBlank(country) && country != 'All countries') {
            for (Share_Class__c share : sharesList) {
                for (Country__c c : share.Countries__r) {
                    if(c.Country__c == country){
                        filteredSharesList.add(share);
                        break;
                    }
                }
            }
            sharesList = filteredSharesList;
        }

        Set<Id> fundIdsFromShares = new Set<Id>();
        String fundQuery = '';

        if (!sharesList.isEmpty()){
            for (Share_Class__c s : sharesList) {
                if (s.Fund__c != null) {
                    fundIdsFromShares.add(s.Fund__c);
                }
            }
            system.debug('fundIdsFromShares : '+fundIdsFromShares);
            if (fundIdsFromShares.isEmpty()) return null;
        } 

        
        
        
        
            fundQuery = 'SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name,RecordTypeId, ' +
                    'Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, ' +
                    'Asset_Class__c, Asset_Class__r.Name, FundStrategy__c, FundStrategy__r.Name,AssetClass__c,SubAssetClass__c, ' +
                    'FundStrategy__r.InvestmentStyle__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, ' +
                    'Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Investment_Style__c, ' +
                    'Validity__c, Strategy__r.Validity__c, Asset_Class__r.Validity__c, Sub_Asset_Class__r.Validity__c, ' +
                    'Last_AUM_Previous_Year__c, Last_AUM_Available__c, YTD_Net_Flows__c, LegalForm__c, VehicleType__c, SFDRcategory__c ' +
            'FROM Product__c WHERE Tech_NotDisplayedProductCatalog__c = false AND RecordTypeId = :fundRecordTypeId AND VehicleType__c =\'Funds\' ';
        
            if(fundIdsFromShares.size() > 0){
                fundQuery += ' AND Id IN :fundIdsFromShares';
            }
        
        
        //fundQuery += ' AND Validity__c = :isActiveProducts';

        if (String.isNotBlank(assetClass)) {
            fundQuery += ' AND FundStrategy__r.AssetClass__c = :assetClass';
        }
        if (String.isNotBlank(legalForm)) {
            fundQuery += ' AND LegalForm__c = :legalForm';
        }
        if (String.isNotBlank(fundType)) {
            fundQuery += ' AND VehicleType__c = :fundType';
        }
        if (String.isNotBlank(searchKey) && sharesList.isEmpty()) {
            system.debug('here product '+searchKey);
            fundQuery += ' AND (Name LIKE \'%'+  searchKey + '%\' OR ProductName__c LIKE \'%'+  searchKey + '%\')';
        }
        if (String.isNotBlank(sfdr)) {
            fundQuery += ' AND (SFDRcategory__c =: sfdr )';
        }

        List<Product__c> filteredFunds = Database.query(fundQuery);
        system.debug('filteredFunds '+filteredFunds);
        if (filteredFunds.isEmpty()) return null;

        // Step 3: Extract Strategy Ids
        Set<Id> strategyIds = new Set<Id>();
        Set<Id> fundsIds = new Set<Id>();
        for (Product__c fund : filteredFunds) {
            if (fund.FundStrategy__c != null) {
                strategyIds.add(fund.FundStrategy__c);
            }
            if(fund.RecordTypeId == fundRecordTypeId && fund.FundStrategy__c != null){
                //funds.put(fund.Id, fund);
                fundsIds.add(fund.Id);
            }
        }

        List<Strategy__c> strategies = new List<Strategy__c>();
        if (!strategyIds.isEmpty()) {
        strategies = new List<Strategy__c>([
        SELECT Id, Name, InvestmentStyle__c, AssetClass__c, SubAssetClass__c
        FROM Strategy__c
        WHERE Id IN :strategyIds
        order by Name ASC
        ]);
        }
        String otherShareQuery = '';
        if(sharesList.isEmpty() && !fundsIds.isEmpty()){
            system.debug('empty share '+searchKey);
            otherShareQuery= 'SELECT Id, Name, Fund__c, Fund__r.AssetClass__c, Fund__r.SubAssetClass__c, Status__c,TechIsActive__c, ISIN__c, ' +
            'Last_AUM_Previous_Year__c, Last_AUM_Available__c, YTD_Net_Flows__c, CurrencyIsoCode, Country__c, Type__c ' +
            ', (SELECT Id,Country__c FROM Countries__r) ' +
            'FROM Share_Class__c WHERE Fund__c IN :fundsIds AND TechIsActive__c = :isActiveProducts';

            /*if (String.isNotBlank(country) && country != 'All countries') {
                otherShareQuery += ' AND Country__c INCLUDES (:country)';
            }*/
            if (String.isNotBlank(selectedCurrency)) {
                otherShareQuery += ' AND Currency__c = :selectedCurrency';
            }
            if (String.isNotBlank(SCType)) {
                otherShareQuery += ' AND Type__c = :SCType';
            }
            if (String.isNotBlank(dividendPolicy)) {
                otherShareQuery += ' AND DividendPolicy__c = :dividendPolicy';
            }
            otherShareQuery += ' ORDER BY Primary_Portfolio_Share_Class__c desc';
            sharesList = new List<Share_Class__c>();
            sharesList = Database.query(otherShareQuery);

            system.debug('otherShareQuery '+otherShareQuery);
            system.debug('sharesList '+sharesList);

            filteredSharesList = new List<Share_Class__c>();

            if (String.isNotBlank(country) && country != 'All countries') {
                for (Share_Class__c share : sharesList) {
                    for (Country__c c : share.Countries__r) {
                        if(c.Country__c == country){
                            filteredSharesList.add(share);
                            break;
                        }
                    }
                }
                sharesList = filteredSharesList;
            }
        }
        if (sharesList.isEmpty()) return null;
        // Step 4: Build mappings and output
        Map<Id, List<Share_Class__c>> fundToSharesMap = ProductHierarchyHelper.setFundToSharesMap(sharesList);
        Map<Id, List<Product__c>> strategyToFundsMap = ProductHierarchyHelper.setFundStrategyToFundsMap(filteredFunds);

        List<productHierarchyController.ItemDTO> highLevelItems = new List<productHierarchyController.ItemDTO>();

        if (String.isNotBlank(searchKey) || String.isNotBlank(assetClass) || String.isNotBlank(legalForm) || String.isNotBlank(fundType) || String.isNotBlank(sfdr) || String.isNotBlank(SCType) || String.isNotBlank(dividendPolicy) || String.isNotBlank(selectedCurrency) || (String.isNotBlank(country) && country != 'All countries')) {
        system.debug('<<<<here 1');
        highLevelItems = ProductHierarchyHelper.getFundsItemsWithSharesReferential(filteredFunds, fundToSharesMap, true);
        allStrategies = new productHierarchyController.ItemDTO('All Products', null, null, null, null, null, false,
        true, true, true, highLevelItems);
        } else {
            system.debug('<<<<here 2');
        highLevelItems = ProductHierarchyHelper.getAllStrategywithFundsItems(strategyToFundsMap, strategies, fundToSharesMap);
        allStrategies = new productHierarchyController.ItemDTO('All Strategies', null, null, null, null, null, false,
        true, true, true, highLevelItems);
        }

        return JSON.serialize(allStrategies);
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

}