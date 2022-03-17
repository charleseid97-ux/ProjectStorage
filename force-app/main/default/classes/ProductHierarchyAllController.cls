public with sharing class ProductHierarchyAllController 
{
    //#region called methods

    /**
     * construct a JSON of items to send to front
     * JSON must be adapted to be used in the tree component
     * (The used tree component is a custom)
     * @param {Id} productId 
     */
    @AuraEnabled
    public static string getProductHierarchy(Id productId, boolean showSRI, boolean showRF, boolean showAC, string country)
    {
    	return getAllProducts(showSRI, showRF, showAC, country);
    }

    //#endregion


    //#region Hierarchy levels methods

    private static string getAllProducts(boolean showSRI, boolean showRF, boolean showAC, string country)
    {

        productHierarchyController.ItemDTO allStratgies = new productHierarchyController.ItemDTO();

        Map<Id,Product__c> products = new Map<Id, Product__c>([SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name,
                                        Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__c,
                                        Asset_Class__r.Record_Type_Name__c, Asset_Class__c, Asset_Class__r.Name,
                                        Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c,
                                        Strategy__r.Investment_Style__c, Investment_Style__c, Validity__c,
                                        Strategy__r.Validity__c, Asset_Class__r.Validity__c, Sub_Asset_Class__r.Validity__c,
                                        Last_AUM_Previous_Year__c, Last_AUM_Available__c, YTD_Net_Flows__c
                                        FROM Product__c 
                                        WHERE Validity__c = TRUE]);
                                       

        Map<Id, Product__c> strategies = new Map<Id, Product__c>();

        Map<Id, Product__c> funds = new Map<Id, Product__c>();

        Map<Id, Product__c> assetClasses = new Map<Id, Product__c>();

        Map<Id, Product__c> regionalFocuses = new Map<Id, Product__c>();

        
        for(Id productId : products.keyset())
        {
            switch on products.get(productId).Record_Type_Name__c 
            {
                when 'Strategy' 
                {	
                    if(products.get(productId).Sub_Asset_Class__c != null && products.get(productId).Asset_Class__c != null)
                    {	
                        strategies.put(productId, products.get(productId));
                    }
            	}
                when 'Fund' 
                {		
                    // because some funds don't have a value in Strategy__c field
                    if(products.get(productId).Strategy__c != null)
                    {
                        funds.put(productId, products.get(productId));
                    }
                }                      
                when 'Asset Class' 
                {	
                    assetClasses.put(productId, products.get(productId));
                }
                when 'Regional Focus' 
                {	
                    regionalFocuses.put(productId, products.get(productId));
                }
            }
        }

        List<Share_Class__c> sharesList = new List<Share_Class__c>();

        if(country == null || country == 'All countries')
        {
            sharesList = [SELECT Id, Name, Fund__c, Validity__c, ISIN_Code__c, Last_AUM_Previous_Year__c,
                            Last_AUM_Available__c, YTD_Net_Flows__c
                            FROM Share_Class__c
                            WHERE Fund__c IN :funds.keySet()
                            AND Validity__c = TRUE];
        }
        else
        {
            sharesList = [SELECT Id, Name, Fund__c, Validity__c, ISIN_Code__c, Last_AUM_Previous_Year__c,
                            Last_AUM_Available__c, YTD_Net_Flows__c
                            FROM Share_Class__c
                            WHERE Fund__c IN :funds.keySet()
                            AND Country__c INCLUDES (:country)
                            AND Validity__c = TRUE];
        }
        

        // put shares in a map of Fund => Shares 
        Map<Id, List<Share_Class__c>> fundToSharesMap = ProductHierarchyHelper.setFundToSharesMap(sharesList);

        // put funds in a map of Strategy => Funds                                                                    
        Map<Id, List<Product__c>> strategyTofundsMap = ProductHierarchyHelper.setStrategyToFundsMap(funds.values());

        List<productHierarchyController.ItemDTO> highLevelItems = new List<productHierarchyController.ItemDTO>();

        if(!showAC && !showRF && showSRI)
        {
            highLevelItems = ProductHierarchyHelper.getStrategywithFundsItems(strategyTofundsMap, strategies, fundToSharesMap, showSRI);
        }
        else
        {
            highLevelItems = ProductHierarchyHelper.getAllStrategywithFundsItems(strategyTofundsMap, strategies, fundToSharesMap, showSRI);
        }
        allStratgies = new productHierarchyController.ItemDTO('All Strategies', null, null, null, null, null, false,
        true, true, true, highLevelItems);

        if(showRF && !showAC)
        {
            List<productHierarchyController.ItemDTO> regionalFocusItems = getRegionalFocuswithStrategiesItems(highLevelItems, regionalFocuses, strategies, showSRI);

            allStratgies = new productHierarchyController.ItemDTO('All Regional Focuses', null, null, null, null, null, false,
                true, true, true, regionalFocusItems);
        }

        if(!showRF && showAC)
        {
            List<productHierarchyController.ItemDTO> assetClassItems = getAssetClassWithStrategiesItems(highLevelItems, assetClasses, strategies, showSRI);

            allStratgies = new productHierarchyController.ItemDTO('All Asset Classes', null, null, null, null, null, false,
                true, true, true, assetClassItems);
        }

        if(showRF && showAC)
        {
            List<productHierarchyController.ItemDTO> regionalFocusItems = getRegionalFocuswithStrategiesItems(highLevelItems, regionalFocuses, strategies, showSRI);

            List<productHierarchyController.ItemDTO> items =  addAssetClassToRegionalFocus(regionalFocusItems, strategies, assetClasses);

            allStratgies = new productHierarchyController.ItemDTO('All Asset Classes', null, null, null, null, null, false,
                true, true, true, items);
        }

        return JSON.serialize(allStratgies);
    }

    //#endregion

    //#region Get and Set nested items

    private static List<productHierarchyController.ItemDTO> getRegionalFocuswithStrategiesItems(List<productHierarchyController.ItemDTO> highLevelItems,
                                                           Map<Id, Product__c> regionalFocuses,
                                                           Map<Id, Product__c> strategiesMap, 
                                                           boolean showSRI)
    {
        List<productHierarchyController.ItemDTO> regionalFocuswithStrategiesItems = new List<productHierarchyController.ItemDTO>();

        for(Id regionalFocusId : regionalFocuses.keySet())
        {
            //strategies to add to each regional focus
            List<productHierarchyController.ItemDTO> strategiesItems = new List<productHierarchyController.ItemDTO>();
            //strategies that have SRI = true 
            List<productHierarchyController.ItemDTO> SRIItems = new List<productHierarchyController.ItemDTO>();
            // add strategy items to regional focus
            for(productHierarchyController.ItemDTO item : highLevelItems)
            {
                if(regionalFocusId == item.regionalFocusId)
                {
                    // check if strategy is a SRI product
                    if(strategiesMap.get(item.id).SRI__c && showSRI)
                    {
                        // if SRI add it to the SRI items
                        SRIItems.add(item);
                    }
                    else
                    {
                        // otherwise add it with other strategies
                        strategiesItems.add(item);
                    }
                }
            }
            // add SRI item (which contains strategie items that are SRI = true) to the other strategies
            if(SRIItems.size() != 0 && showSRI)
            {
                System.debug('SRI Items size '+ SRIItems.size());

                productHierarchyController.ItemDTO SRI = ProductHierarchyHelper.setItemSRI(SRIItems);

                strategiesItems.add(SRI);
            } 

            productHierarchyController.ItemDTO regionalFocus = new productHierarchyController.ItemDTO(regionalFocuses.get(regionalFocusId).Name, regionalFocuses.get(regionalFocusId).Record_Type_Name__c, regionalFocuses.get(regionalFocusId).Name,
            URL.getSalesforceBaseUrl().toExternalForm()+'/'+regionalFocuses.get(regionalFocusId).Id, null, null, false, regionalFocuses.get(regionalFocusId).Validity__c,
            true, false, strategiesItems);

            regionalFocus.id = regionalFocusId;

            System.debug('reg foc '+regionalFocus);

            if(regionalFocus.items.size() > 0)
            {
                regionalFocuswithStrategiesItems.add(regionalFocus);
            }
        }

        return regionalFocuswithStrategiesItems;
    }

    private static List<productHierarchyController.ItemDTO> getAssetClassWithStrategiesItems(List<productHierarchyController.ItemDTO> highLevelItems,
                                                           Map<Id, Product__c> assetClasses,
                                                           Map<Id, Product__c> strategiesMap, 
                                                           boolean showSRI)
    {
        List<productHierarchyController.ItemDTO> assetClassWithStrategiesItems = new List<productHierarchyController.ItemDTO>();

        for(Id assetClassId : assetClasses.keySet())
        {
            //strategies to add to each asset class
            List<productHierarchyController.ItemDTO> strategiesItems = new List<productHierarchyController.ItemDTO>();
            //strategies that have SRI = true 
            List<productHierarchyController.ItemDTO> SRIItems = new List<productHierarchyController.ItemDTO>();
            // add strategy items to asset class
            for(productHierarchyController.ItemDTO item : highLevelItems)
            {
                if(assetClassId == item.assetClassId)
                {
                    // check if strategy is a SRI product
                    if(strategiesMap.get(item.id).SRI__c && showSRI)
                    {
                        // if SRI add it to the SRI items
                        SRIItems.add(item);
                    }
                    else
                    {
                        // otherwise add it with other strategies
                        strategiesItems.add(item);
                    }
                }
            }
            // add SRI item (which contains strategie items that are SRI = true) to the other strategies
            if(SRIItems.size() != 0 && showSRI)
            {
                System.debug('SRI Items size '+ SRIItems.size());

                productHierarchyController.ItemDTO SRI = ProductHierarchyHelper.setItemSRI(SRIItems);

                strategiesItems.add(SRI);
            } 
            productHierarchyController.ItemDTO assetClass = new productHierarchyController.ItemDTO(assetClasses.get(assetClassId).Name, assetClasses.get(assetClassId).Record_Type_Name__c, assetClasses.get(assetClassId).Name,
            URL.getSalesforceBaseUrl().toExternalForm()+'/'+assetClasses.get(assetClassId).Id, null, null, false, assetClasses.get(assetClassId).Validity__c,
            true, false, strategiesItems);

            if(assetClass.items.size() > 0)
            {
                assetClassWithStrategiesItems.add(assetClass);
            }
        }

        return assetClassWithStrategiesItems;
    }


    private static List<productHierarchyController.ItemDTO> addAssetClassToRegionalFocus(List<productHierarchyController.ItemDTO> regionalFocusItems,
                                                                                         Map<Id, Product__c> strategiesMap,
                                                                                         Map<Id, Product__c> assetClassesMap)
    {
        List<productHierarchyController.ItemDTO> assetClassItems = new List<productHierarchyController.ItemDTO>();

        Map<String, List<productHierarchyController.ItemDTO>> relatedAssetClasses = new Map<String, List<productHierarchyController.ItemDTO>>();

        for(productHierarchyController.ItemDTO item : regionalFocusItems)
        {
            for(productHierarchyController.ItemDTO lowerItem : item.items)
            {
                if(lowerItem.assetClassId != null)
                {
                    if(!relatedAssetClasses.keyset().contains(lowerItem.assetClassId))
                    {
                        relatedAssetClasses.put(lowerItem.assetClassId, new List<productHierarchyController.ItemDTO>{item});
                    }
                    else
                    {
                        if(!getListOfRegionalFocusIds(relatedAssetClasses.get(lowerItem.assetClassId)).contains(lowerItem.regionalFocusId))
                        {
                            relatedAssetClasses.get(lowerItem.assetClassId).add(item);
                        }
                    }
                }
                else
                {
                    for(productHierarchyController.ItemDTO lowestItem : lowerItem.items)
                    {
                        if(!relatedAssetClasses.keyset().contains(lowestItem.assetClassId))
                        {
                            relatedAssetClasses.put(lowestItem.assetClassId, new List<productHierarchyController.ItemDTO>{item});
                        }
                        else
                        {
                            if(!getListOfRegionalFocusIds(relatedAssetClasses.get(lowestItem.assetClassId)).contains(lowestItem.regionalFocusId))
                            {
                                relatedAssetClasses.get(lowestItem.assetClassId).add(item);
                            }
                        }
                    }
                }
            }
        }
        System.debug('assets '+relatedAssetClasses.keyset());

        for(String assetClassId : relatedAssetClasses.keyset())
        {
            productHierarchyController.ItemDTO assetClass = new productHierarchyController.ItemDTO(assetClassesMap.get(assetClassId).Name,
            assetClassesMap.get(assetClassId).Record_Type_Name__c, assetClassesMap.get(assetClassId).Name,
            URL.getSalesforceBaseUrl().toExternalForm()+'/'+assetClassId, null, null, false, assetClassesMap.get(assetClassId).Validity__c,
            true, false, relatedAssetClasses.get(assetClassId));
            assetClassItems.add(assetClass);
        }

        return assetClassItems;
    }

    private static List<String> getListOfRegionalFocusIds(List<productHierarchyController.ItemDTO> regionalFocusItems)
    {
        List<String> regionalFocusIds = new List<String>();
        
        for(productHierarchyController.ItemDTO item : regionalFocusItems)
        {
            regionalFocusIds.add(item.id);
        }
        return regionalFocusIds;
    }

    //#endregion
}