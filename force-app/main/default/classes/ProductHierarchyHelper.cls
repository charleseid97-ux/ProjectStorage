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

    public static Map<Id, List<Product__c>> setFundStrategyToFundsMap(List<Product__c> fundsList)
    {
        Map<Id, List<Product__c>> strategyTofundsMap = new Map<Id, List<Product__c>>();

        for(Product__c fund : fundsList)
        {
			if(fund.FundStrategy__c != null)
            {
                if(strategyTofundsMap.get(fund.FundStrategy__c) == null)
                {
                    strategyTofundsMap.put(fund.FundStrategy__c, new List<Product__c>{fund});
                }
                else
                {
                    strategyTofundsMap.get(fund.FundStrategy__c).add(fund);
                }
            } 
        }
        return strategyTofundsMap;
    }
    //#endregion

    public static List<productHierarchyController.ItemDTO> getAllStrategywithFundsItems(Map<Id, List<Product__c>> strategyTofundsMap, List<Strategy__c> strategies, Map<Id, List<Share_Class__c>> fundToSharesMap) {
        List<productHierarchyController.ItemDTO> strategyItems = new List<productHierarchyController.ItemDTO>();
        for(Strategy__c str: strategies) {
            if( str.Name != null) {
                List<Product__c> fundsList =  strategyTofundsMap.get(str.Id);
                if(fundsList.size() > 0) {
                    productHierarchyController.ItemDTO strategy = new productHierarchyController.ItemDTO(str.Name, null, str.Name, null, null, null, false, true, true, false, getFundsItemsWithSharesReferential(fundsList, fundToSharesMap, false));
                    strategy.id = str.Id;
                    strategy.assetclass = str.AssetClass__c;

                    if(strategy.items.size() > 0) strategyItems.add(strategy);
                }  
            }
        }
  
        return strategyItems;
    }

    public static List<productHierarchyController.ItemDTO> getFundsItemsWithSharesReferential(List<Product__c> funds, Map<Id, List<Share_Class__c>> shares, Boolean expanded)
    {
        List<productHierarchyController.ItemDTO> fundItems = new List<productHierarchyController.ItemDTO>();

        for(Product__c fund : funds)
        {
            List<Share_Class__c> fundSharesList =  shares.get(fund.Id);

            System.debug('Size is '+ fundSharesList);
        
            if(fundSharesList != null)
            {
                //TODO add AUMs
                productHierarchyController.ItemDTO fundItem = new productHierarchyController.ItemDTO(fund.Name, null, fund.Name, URL.getSalesforceBaseUrl().toExternalForm()+'/'+fund.Id,
                null, null, false, fund.Validity__c, true, expanded, getShareItemsReferential(fundSharesList));

                //if(fund.Last_AUM_Previous_Year__c != null) fundItem.aum = formatSharesAUM('(M€ ) - AUM : ', fund.Last_AUM_Previous_Year__c);
                //if(fund.Last_AUM_Available__c != null) fundItem.lastaum = formatSharesAUM('- Last AUM : ', fund.Last_AUM_Available__c);
                //if(fund.YTD_Net_Flows__c != null) fundItem.ytdnet = formatSharesAUM('- YTD Flows : ', fund.YTD_Net_Flows__c);
				fundItem.assetclass = fund.AssetClass__c;
                fundItem.regionalfocus = String.valueOf(fund.LaunchDate__c);
                fundItems.add(fundItem);
            }else{
                productHierarchyController.ItemDTO fundItem = new productHierarchyController.ItemDTO(fund.Name, fund.Record_Type_Name__c, fund.Name, URL.getSalesforceBaseUrl().toExternalForm()+'/'+fund.Id,
                null, null, false, fund.Validity__c, true, false, null);

                //if(fund.Last_AUM_Previous_Year__c != null) fundItem.aum = formatSharesAUM('(M€ ) - AUM : ', fund.Last_AUM_Previous_Year__c);
                //if(fund.Last_AUM_Available__c != null) fundItem.lastaum = formatSharesAUM('- Last AUM : ', fund.Last_AUM_Available__c);
                //if(fund.YTD_Net_Flows__c != null) fundItem.ytdnet = formatSharesAUM('- YTD Flows : ', fund.YTD_Net_Flows__c);
				fundItem.assetclass = fund.AssetClass__c;
                fundItem.regionalfocus = String.valueOf(fund.LaunchDate__c);
                fundItems.add(fundItem);

            }
        }
        return fundItems;
    }

    public static List<productHierarchyController.ItemDTO> getShareItemsReferential(List<Share_Class__c> fundSharesList)
    {
        List<productHierarchyController.ItemDTO> shareItems = new List<productHierarchyController.ItemDTO>();
        if(fundSharesList.size() > 0)
        {
            for(Share_Class__c share : fundSharesList)
            {
                productHierarchyController.ItemDTO shareItem = new productHierarchyController.ItemDTO(share.Name, null, share.Name, URL.getSalesforceBaseUrl().toExternalForm()+'/'+share.Id, null, share.ISIN__c,
                false, isActiveShareClass(share), false, false, null);

                //if(share.Last_AUM_Previous_Year__c != null) shareItem.aum = formatSharesAUM('(M€ ) - AUM : ', share.Last_AUM_Previous_Year__c);
                //if(share.Last_AUM_Available__c != null) shareItem.lastaum = formatSharesAUM('- Last AUM : ', share.Last_AUM_Available__c);
                //if(share.YTD_Net_Flows__c != null) shareItem.ytdnet = formatSharesAUM('- YTD Flows : ', share.YTD_Net_Flows__c);
                shareItem.assetclass = share.Fund__r.AssetClass__c;
                shareItem.regionalfocus = String.valueOf(share.Fund__r.LaunchDate__c);
                shareItems.add(shareItem);
            }
        }
        return shareItems;
    }
    // Retourne true si la share class est considérée active selon la nouvelle règle métier.
    private static Boolean isActiveShareClass(Share_Class__c share)
    {
        return share.Status__c == 'Active' || share.Status__c == 'Active - Lab';
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