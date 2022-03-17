public with sharing class ProductHierarchyHelper
{
    //#region Maps creation

    /**
     * creates a map of fund => shares
     * @param {List<Share_Class__c>} sharesList list of shares related to funds
     */
    public static Map<Id, List<Share_Class__c>> setFundToSharesMap(List<Share_Class__c> sharesList)
    {
        Map<Id, List<Share_Class__c>> shares = new Map<Id, List<Share_Class__c>>();

        for(Share_Class__c share : sharesList)
        {            
            if(shares.get(share.Fund__c) == null)
            {
                shares.put(share.Fund__c, new List<Share_Class__c>{share});
            }
            else
            {
                shares.get(share.Fund__c).add(share);
            }
        }
        return shares;
    }



    /**
     * creates a map of strategy => funds
     * @param {List<Product__c>} fundsList list of funds related to strategies
     */
    public static Map<Id, List<Product__c>> setStrategyToFundsMap(List<Product__c> fundsList)
    {
        Map<Id, List<Product__c>> strategyTofundsMap = new Map<Id, List<Product__c>>();

        for(Product__c fund : fundsList)
        {
			if(fund.Strategy__c != null)
            {
                if(strategyTofundsMap.get(fund.Strategy__c) == null)
                {
                    strategyTofundsMap.put(fund.Strategy__c, new List<Product__c>{fund});
                }
                else
                {
                    strategyTofundsMap.get(fund.Strategy__c).add(fund);
                }
            } 
        }
        return strategyTofundsMap;
    }


    /**
     * creates a map of Regional Focus => Strategies
     * @param {List<Product__c>} fundsList list of funds related to strategies
     */
    public static Map<Id, List<Product__c>> setRegionalFocusToStrategiesMap(List<Product__c> strategiesList)
    {
        Map<Id, List<Product__c>> regionalFocusToStrategiesMap = new Map<Id, List<Product__c>>();

        for(Product__c strategy : strategiesList)
        {            
            if(regionalFocusToStrategiesMap.get(strategy.Sub_Asset_Class__c) == null)
            {
                regionalFocusToStrategiesMap.put(strategy.Sub_Asset_Class__c, new List<Product__c>{strategy});
            }
            else
            {
                regionalFocusToStrategiesMap.get(strategy.Sub_Asset_Class__c).add(strategy);
            }
        }
        return regionalFocusToStrategiesMap;
    }

    /**
     * sets the Asset Class level Item
     * @param {Product__c} selectedProduct contains the selected product
     */
    public static productHierarchyController.ItemDTO setAssetClassItem(Product__c selectedProduct,
                                             productHierarchyController.ItemDTO strategyItem, productHierarchyController.ItemDTO regionalFocusItem,
                                             productHierarchyController.ItemDTO assetClassItem, boolean showAC, boolean showRF)
    {
        productHierarchyController.ItemDTO returnItem = strategyItem;

        if(selectedProduct.Sub_Asset_Class__c != null && showRF)
        {
            returnItem = new productHierarchyController.ItemDTO(selectedProduct.Sub_Asset_Class__r.Name, selectedProduct.Sub_Asset_Class__r.Record_Type_Name__c, selectedProduct.Sub_Asset_Class__r.Name,
            URL.getSalesforceBaseUrl().toExternalForm()+'/'+selectedProduct.Sub_Asset_Class__c, null, null, false, selectedProduct.Sub_Asset_Class__r.Validity__c,
            true, false, new List<productHierarchyController.ItemDTO>{strategyItem});
        }
        if(selectedProduct.Asset_Class__c != null && showAC)
        {
            returnItem = new productHierarchyController.ItemDTO(selectedProduct.Asset_Class__r.Name, selectedProduct.Asset_Class__r.Record_Type_Name__c, selectedProduct.Asset_Class__r.Name,
            URL.getSalesforceBaseUrl().toExternalForm()+'/'+selectedProduct.Asset_Class__c, null, null, false, selectedProduct.Asset_Class__r.Validity__c, true, false, new List<productHierarchyController.ItemDTO>{returnItem});  
        }

        return returnItem;
    }


    //#endregion

    //#region Set nested items


    /**
     * get a list of strategy items with funds and shares
     * @param {Map<Id, Product__c>} strategyTofundsMap a map of strategy => funds
     * @param {List<Id>} strategiesIds just a list of strategiesIds to iterate on
     * @param {Map<Id, List<Share_Class__c>>} shares a map of fund => shares
     */
    public static List<productHierarchyController.ItemDTO> getStrategywithFundsItems(Map<Id, List<Product__c>> strategyTofundsMap,
                                                           Map<Id, Product__c> strategies,
                                                           Map<Id, List<Share_Class__c>> fundToSharesMap,
                                                           boolean showSRI)
    {
        List<productHierarchyController.ItemDTO> strategyItems = new List<productHierarchyController.ItemDTO>();

        List<productHierarchyController.ItemDTO> SRIItems = new List<productHierarchyController.ItemDTO>();
            
        for(Id strategyId : strategyTofundsMap.keySet())
        {
            if(strategies.containsKey(strategyId) && strategies.get(strategyId).Record_Type_Name__c != null
               && strategies.get(strategyId).Name != null)
            {
                List<Product__c> fundsList =  strategyTofundsMap.get(strategyId);

                if(fundsList.size() > 0)
                {
                    productHierarchyController.ItemDTO strategy = new productHierarchyController.ItemDTO(strategies.get(strategyId).Name, strategies.get(strategyId).Record_Type_Name__c, strategies.get(strategyId).Name,
                    URL.getSalesforceBaseUrl().toExternalForm()+'/'+strategies.get(strategyId).Id, null, null, false, strategies.get(strategyId).Validity__c,
                    true, false, getFundsItemsWithShares(fundsList, fundToSharesMap));
        
                    strategy.regionalFocusId = strategies.get(strategyId).Sub_Asset_Class__c;
        
                    strategy.assetClassId = strategies.get(strategyId).Asset_Class__c;
        
                    strategy.id = strategyId;
        
                    strategy.assetclass = strategies.get(strategyId).Asset_Class__r.Name;
                    
                    strategy.regionalfocus = strategies.get(strategyId).Sub_Asset_Class__r.Name;
        
                    
                    if(strategy.items.size() > 0)
                    {
                        if(strategies.get(strategyId).SRI__c && showSRI)
                        {
                            SRIItems.add(strategy);
                        }
                        else
                        {
                            strategyItems.add(strategy);
                        }
                    }
                }
            }
        }
        if(SRIItems.size() != 0 && showSRI)
        {
            productHierarchyController.ItemDTO SRI = setItemSRI(SRIItems);

            strategyItems.add(SRI);
        } 
        return strategyItems;
    }


    /**
     * get a list of strategy items with funds and shares
     * @param {Map<Id, Product__c>} strategyTofundsMap a map of strategy => funds
     * @param {List<Id>} strategiesIds just a list of strategiesIds to iterate on
     * @param {Map<Id, List<Share_Class__c>>} shares a map of fund => shares
     */
    public static List<productHierarchyController.ItemDTO> getAllStrategywithFundsItems(Map<Id, List<Product__c>> strategyTofundsMap,
                                                           Map<Id, Product__c> strategies,
                                                           Map<Id, List<Share_Class__c>> fundToSharesMap,
                                                           boolean showSRI)
    {
        List<productHierarchyController.ItemDTO> strategyItems = new List<productHierarchyController.ItemDTO>();
            
        for(Id strategyId : strategyTofundsMap.keySet())
        {
            if(strategies.get(strategyId) != null)
            {
                if(strategies.get(strategyId).Record_Type_Name__c != null 
               && strategies.get(strategyId).Name != null)
                {
                    List<Product__c> fundsList =  strategyTofundsMap.get(strategyId);
    
                    if(fundsList.size() > 0)
                    {
                        productHierarchyController.ItemDTO strategy = new productHierarchyController.ItemDTO(strategies.get(strategyId).Name, strategies.get(strategyId).Record_Type_Name__c, strategies.get(strategyId).Name,
                        URL.getSalesforceBaseUrl().toExternalForm()+'/'+strategies.get(strategyId).Id, null, null, false, strategies.get(strategyId).Validity__c,
                        true, false, getFundsItemsWithShares(fundsList, fundToSharesMap));
            
                        strategy.regionalFocusId = strategies.get(strategyId).Sub_Asset_Class__c;
            
                        strategy.assetClassId = strategies.get(strategyId).Asset_Class__c;
            
                        strategy.id = strategyId;
            
                        strategy.assetclass = strategies.get(strategyId).Asset_Class__r.Name;
                        
                        strategy.regionalfocus = strategies.get(strategyId).Sub_Asset_Class__r.Name;

                        if(strategy.items.size() > 0)
                        {
                            strategyItems.add(strategy);
                        }
                    }                
                }
            }
        }
  
        return strategyItems;
    }




    /**
     * get the list of fund items with shares
     * @param {List<Product__c>} funds List of funds related to the strategies 
     * @param {Map<Id, List<Share_Class__c>>} shares Map of fund => shares (shares related to funds);
     */
    public static List<productHierarchyController.ItemDTO> getFundsItemsWithShares(List<Product__c> funds, Map<Id, List<Share_Class__c>> shares)
    {
        List<productHierarchyController.ItemDTO> fundItems = new List<productHierarchyController.ItemDTO>();

        for(Product__c fund : funds)
        {
            List<Share_Class__c> fundSharesList =  shares.get(fund.Id);

            System.debug('Size is '+ fundSharesList);
        
            if(fundSharesList != null)
            {
                //TODO add AUMs
                productHierarchyController.ItemDTO fundItem = new productHierarchyController.ItemDTO(fund.Name, fund.Record_Type_Name__c, fund.Name, URL.getSalesforceBaseUrl().toExternalForm()+'/'+fund.Id,
                null, null, false, fund.Validity__c, true, false, getShareItems(fundSharesList));

                if(fund.Last_AUM_Previous_Year__c != null) fundItem.aum = formatSharesAUM('(M€ ) - AUM : ', fund.Last_AUM_Previous_Year__c);
                if(fund.Last_AUM_Available__c != null) fundItem.lastaum = formatSharesAUM('- Last AUM : ', fund.Last_AUM_Available__c);
                if(fund.YTD_Net_Flows__c != null) fundItem.ytdnet = formatSharesAUM('- YTD Flows : ', fund.YTD_Net_Flows__c);
    
                fundItems.add(fundItem);
            }
        }
        return fundItems;
    }

    public static List<productHierarchyController.ItemDTO> getShareItems(List<Share_Class__c> fundSharesList)
    {
        List<productHierarchyController.ItemDTO> shareItems = new List<productHierarchyController.ItemDTO>();
        if(fundSharesList.size() > 0)
        {
            for(Share_Class__c share : fundSharesList)
            {
                productHierarchyController.ItemDTO shareItem = new productHierarchyController.ItemDTO(share.Name, null, share.Name, URL.getSalesforceBaseUrl().toExternalForm()+'/'+share.Id, null, share.ISIN_Code__c,
                false, share.Validity__c, false, false, null);

                if(share.Last_AUM_Previous_Year__c != null) shareItem.aum = formatSharesAUM('(M€ ) - AUM : ', share.Last_AUM_Previous_Year__c);
                if(share.Last_AUM_Available__c != null) shareItem.lastaum = formatSharesAUM('- Last AUM : ', share.Last_AUM_Available__c);
                if(share.YTD_Net_Flows__c != null) shareItem.ytdnet = formatSharesAUM('- YTD Flows : ', share.YTD_Net_Flows__c);

                shareItems.add(shareItem);
            }
        }
        return shareItems;
    }

    public static String formatSharesAUM(String label, String value){

        Integer million = 1000000;
        Integer decimalplace = 2;

        string cleanAum = value.replace(',','');

        System.debug('TRIMED '+cleanAum.trim());

        if(cleanAum.trim() != 'Not Available') cleanAum = String.valueOf((decimal.valueOf(cleanAum.trim())/million).setScale(decimalplace));

        return label + cleanAum;

    }

    public static productHierarchyController.ItemDTO setItemSRI(List<productHierarchyController.ItemDTO> currentStrategies)
    {
        // set a higher level item with type SRI
        productHierarchyController.ItemDTO SRI = new productHierarchyController.ItemDTO('SRI', null, null, null, null, null, false,
        true, true, false, currentStrategies);
                
        return SRI;
    }

    //#endregion


}