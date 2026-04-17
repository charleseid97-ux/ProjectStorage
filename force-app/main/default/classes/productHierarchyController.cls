public with sharing class productHierarchyController 
{
    //#region called methods

    /**
     * construct a JSON of items to send to front
     * JSON must be adapted to be used in the tree component
     * (The used tree component is a custom)
     * @param {Id} productId 
     */
    @AuraEnabled
    public static string getProductHierarchy(Id productId, boolean showSRI, boolean showRF, boolean showAC)
    {
        System.debug('Product ID '+productId);
        
        // get the selected product with all the necessary fields
        Product__c selectedProduct = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name,
                                        Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__c,
                                        Asset_Class__r.Record_Type_Name__c, Asset_Class__c, Asset_Class__r.Name,
                                        Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c,
                                        Strategy__r.Investment_Style__c, Investment_Style__c, Validity__c,
                                        Strategy__r.Validity__c, Asset_Class__r.Validity__c, Sub_Asset_Class__r.Validity__c
                                        FROM Product__c
                                        WHERE Id =: productId
                                        AND Validity__c = TRUE
                                     ];
       // checks the record type of the selected product to decide on which
       // hierarchical we are
        if(selectedProduct.Record_Type_Name__c == 'Asset Class' 
        || selectedProduct.Record_Type_Name__c == 'Regional Focus')
        {
            // construct a JSON of items containing all products that are ralated
            // to the higher levels (Asset Class or Regional Focus)
            return getHigherHierarchy(productId, showSRI, showRF, showAC);
        }
        else if (selectedProduct.Record_Type_Name__c == 'Strategy')
        {
            // construct a JSON of items containing all products that are ralated
            // to the middle level (Strategy)
            return getMidHierarchy(selectedProduct, showSRI, showRF, showAC);
        }
        else if (selectedProduct.Record_Type_Name__c == 'Fund')
        {
            // construct a JSON of items containing all products that are ralated
            // to the lower level (Fund)
            return getLowHierarchy(selectedProduct, showSRI, showRF, showAC);
        }
        return null;
    }

    //#endregion
    
    //#region Hierarchy levels methods


    /**
     * get JSON items for Asset Class and Regional Focus
     * @param {Id} productId 
     */
    private static string getHigherHierarchy(Id productId, boolean showSRI, boolean showRF, boolean showAC) 
    {
        // get the product 
        Map<Id,Product__c> products = new Map<Id, Product__c>([SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name,
                                        Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__c,
                                        Asset_Class__r.Record_Type_Name__c, Asset_Class__c, Asset_Class__r.Name,
                                        Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c,
                                        Strategy__r.Investment_Style__c, Investment_Style__c, Validity__c,
                                        Strategy__r.Validity__c, Asset_Class__r.Validity__c, Sub_Asset_Class__r.Validity__c
                                        FROM Product__c
                                        WHERE (Id =: productId
                                        OR Asset_Class__c =:productId
                                        OR Sub_Asset_Class__c =:productId) 
                                        AND Validity__c = TRUE]);

        Map<Id, Product__c> strategies = products.deepClone();

        // remove the selected product from strategies map
        strategies.remove(productId);

        Map<Id, Product__c> fundsMap = new Map<Id, Product__c> ([SELECT Id, Name, SRI__c, Strategy__c, Record_Type_Name__c, Fund__c, Validity__c,
                                                                 Last_AUM_Previous_Year__c,Last_AUM_Available__c, YTD_Net_Flows__c
                                                                 FROM Product__c
                                                                 WHERE Strategy__c IN :strategies.keySet()
                                                                 AND Validity__c = TRUE]);

        System.debug('fundsMap size :'+ fundsMap.keySet().size());
           
        List<Share_Class__c> sharesList = [SELECT Id, Name, Fund__c, ISIN_Code__c, Validity__c, Last_AUM_Previous_Year__c,
                                            Last_AUM_Available__c, YTD_Net_Flows__c
                                               FROM Share_Class__c
                                               WHERE Fund__c IN :fundsMap.keySet()
                                               AND Validity__c = TRUE];

        System.debug('sharesList size :'+ sharesList.size());
        // put shares in a map of Fund => Shares 
        Map<Id, List<Share_Class__c>> fundToSharesMap = ProductHierarchyHelper.setFundToSharesMap(sharesList);

        // put funds in a map of Strategy => Funds                                                                    
        Map<Id, List<Product__c>> strategyTofundsMap = ProductHierarchyHelper.setStrategyToFundsMap(fundsMap.values());
        
        // Set final DTO object to send to front
        ItemDTO highLevelItem = new ItemDTO(products.get(productId).Name, products.get(productId).Record_Type_Name__c,
        products.get(productId).Name, URL.getSalesforceBaseUrl().toExternalForm()+'/'+products.get(productId).Id, null, null, true,
        products.get(productId).Validity__c, true, true, ProductHierarchyHelper.getStrategywithFundsItems(strategyTofundsMap, strategies, fundToSharesMap, showSRI));
        
        highLevelItem.ishighlevel = true;

        return JSON.serialize(highLevelItem);
    }



    /**
     * get JSON items for Strategy
     * @param {Product__c} selectedProduct 
     */
    private static string getMidHierarchy(Product__c selectedProduct, boolean showSRI, boolean showRF, boolean showAC)
    {
        // gets funds related to the selected product in a map of Id => Fund
        Map<Id,Product__c> fundsMap = new Map<Id, Product__c>([SELECT Id, Name, Strategy__c, Record_Type_Name__c,
                                        Asset_Class__c, Sub_Asset_Class__c, Fund__c, Validity__c, Investment_Style__c,
                                        Last_AUM_Previous_Year__c, Last_AUM_Available__c, YTD_Net_Flows__c
                                        FROM Product__c
                                        WHERE Strategy__c =: selectedProduct.Id
                                        AND Validity__c = TRUE]);

        System.debug('fundsMap size :'+ fundsMap.keySet().size());
        // get shares related to funds 
        List<Share_Class__c> sharesList = [SELECT Id, Name, Fund__c, Validity__c, ISIN_Code__c, Last_AUM_Previous_Year__c,
                                            Last_AUM_Available__c, YTD_Net_Flows__c
                                          FROM Share_Class__c
                                          WHERE Fund__c IN :fundsMap.keySet()
                                          AND Validity__c = TRUE];

        System.debug('sharesList size :'+ sharesList.size());
        // put shares in a map of Fund => Shares 
        Map<Id, List<Share_Class__c>> shares = productHierarchyHelper.setFundToSharesMap(sharesList);

        ItemDTO strategyItem = new ItemDTO(selectedProduct.Name, selectedProduct.Record_Type_Name__c, selectedProduct.Name, 
        URL.getSalesforceBaseUrl().toExternalForm()+'/'+selectedProduct.Id, selectedProduct.Investment_Style__c, null, true, selectedProduct.Validity__c,
        true, true, ProductHierarchyHelper.getFundsItemsWithShares(fundsMap.values(), shares));

        ItemDTO regionalFocusItem = null;

        ItemDTO assetClassItem = null;

        if(showSRI && selectedProduct.SRI__c)
        {
            strategyItem = ProductHierarchyHelper.setItemSRI(new List<ItemDTO>{strategyItem});
        }
        
        
        if(showAC || showRF)
        {
            assetClassItem = ProductHierarchyHelper.setAssetClassItem(selectedProduct, strategyItem,
                                                regionalFocusItem, assetClassItem,
                                                showAC, showRF);

            return JSON.serialize(assetClassItem);
        }
        return JSON.serialize(strategyItem);
    }




    /**
     * get JSON items for Fund
     * @param {Product__c} selectedProduct 
     */
    private static string getLowHierarchy(Product__c selectedProduct, boolean showSRI, boolean showRF, boolean showAC)
    {
        List<Share_Class__c> sharesList = [SELECT Id, Name, Fund__c, Validity__c, ISIN_Code__c,Last_AUM_Previous_Year__c,
                                            Last_AUM_Available__c, YTD_Net_Flows__c
                                          FROM Share_Class__c
                                          WHERE Fund__c =:selectedProduct.Id
                                          AND Validity__c = TRUE];
                                    
        ItemDTO fundItem = new ItemDTO(selectedProduct.Name, selectedProduct.Record_Type_Name__c, selectedProduct.Name,
        URL.getSalesforceBaseUrl().toExternalForm()+'/'+selectedProduct.Id, null, null, true, selectedProduct.Validity__c, true,
        true, ProductHierarchyHelper.getShareItems(sharesList));

        // set strategy level item for the selected fund product
        ItemDTO strategyItem = new ItemDTO(selectedProduct.Strategy__r.Name, selectedProduct.Strategy__r.Record_Type_Name__c,
        selectedProduct.Strategy__r.Name, URL.getSalesforceBaseUrl().toExternalForm()+'/'+selectedProduct.Strategy__c, selectedProduct.Strategy__r.Investment_Style__c,
        null, false, selectedProduct.Strategy__r.Validity__c, true, true, new List<ItemDTO>{fundItem});


        if(showSRI && selectedProduct.Strategy__r.SRI__c)
        {
            strategyItem = ProductHierarchyHelper.setItemSRI(new List<ItemDTO>{strategyItem});
        }

        ItemDTO regionalFocusItem = null;

        ItemDTO assetClassItem = null;
        
        List<Product__c> strategyProducts = new List<Product__c>();

        if(selectedProduct.Strategy__c != null)
        {
            strategyProducts = [SELECT Id, Name, Strategy__r.SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name,
                                        Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__c, Investment_Style__c,
                                        Asset_Class__r.Record_Type_Name__c, Asset_Class__c, Asset_Class__r.Name,
                                        Strategy__c, Strategy__r.Name, Strategy__r.Record_Type_Name__c, Validity__c,
                                        Strategy__r.Validity__c, Asset_Class__r.Validity__c, Sub_Asset_Class__r.Validity__c
                                        FROM Product__c
                                        WHERE Id =: selectedProduct.Strategy__c
                                        AND Validity__c = TRUE
                                     ];
        }

        if(strategyProducts.size() > 0 && (showAC || showRF))
        {
            assetClassItem = ProductHierarchyHelper.setAssetClassItem(strategyProducts[0], strategyItem,
                                            regionalFocusItem, assetClassItem,
                                            showAC, showRF);

            return JSON.serialize(assetClassItem);
        }
        return JSON.serialize(strategyItem);

    }
    //#endregion


    //#region DTO Class

    /**
    * DTO for product
    */
    public class ItemDTO
    {
        // label is the name of the product (the shown title on tree)
        public string label {get; set;}
        // the record type of the product
        public string type {get; set;}
        // the name of the product 
        public string name {get; set;}
        // link to the product page in the org
        public string href {get; set;}
        // investment style for product of type strategy only
        public string investstyle {get; set;}
        // isin code for share classes
        public string isin {get; set;}
        // whether the selected product is the current product shown to the user or not
        public boolean currentproduct {get; set;}
        // whether the item is valid or not (Validty__c)
        public boolean isvalid {get; set;}
        // whether the item is a product or a share class 
        public boolean isproduct {get; set;}
        // whether the item is expanded (on tree) or not
        public boolean expanded {get; set;}
        // items related to the selected item (tree architecture)
        public List<ItemDTO> items {get; set;}

        public boolean ishighlevel {get; set;}

        public string regionalFocusId {get; set;}

        public string assetClassId {get; set;}

        public string id {get; set;}

        public string assetclass {get; set;}

        public string regionalfocus {get; set;}

        public string ytdnet {get; set;}

        public string aum {get; set;}

        public string lastaum {get; set;}
        
        // default constructor
        public ItemDTO(){}
        // all attributs constructor
        public ItemDTO(string label, string type, string name, string href,
        string investstyle, string isin, boolean currentproduct, boolean isvalid,
        boolean isproduct, boolean expanded, List<ItemDTO> items)
        {
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
    //#endregion
}