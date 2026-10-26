/** ──────────────────────────────────────
 * @description Builds the ItemDTO hierarchy items (Strategies, Funds, Share Classes) shown by the Product Catalog tree (referentialProductHomepage).
 *              Used by ReferentialProductHomepageCtrl.
 * @testClass ReferentialProductHomepageCtrlTest
 * @coverage 96%   [13-10-26]
 * @lastModifiedBy Charles EID   [13-10-26]
 ────────────────────────────────────── */
public with sharing class ProductHierarchyHelper {

    // Fund => Share Classes
    public static Map<Id, List<Share_Class__c>> setFundToSharesMap(List<Share_Class__c> sharesList) {
        Map<Id, List<Share_Class__c>> shares = new Map<Id, List<Share_Class__c>>();
        for (Share_Class__c share : sharesList) {
            if (shares.get(share.Fund__c) == null) {
                shares.put(share.Fund__c, new List<Share_Class__c>{share});
            }
            else {
                shares.get(share.Fund__c).add(share);
            }
        }
        return shares;
    }

    /* Plus appelée nulle part (vérifié le 13-10-26) : à supprimer une fois confirmé dans l'org
    // Strategy (Strategy__c) => Funds
    public static Map<Id, List<Product__c>> setStrategyToFundsMap(List<Product__c> fundsList) {
        return groupFundsByStrategy(fundsList, Product__c.Strategy__c);
    }
    */

    // Strategy (FundStrategy__c) => Funds
    public static Map<Id, List<Product__c>> setFundStrategyToFundsMap(List<Product__c> fundsList) {
        return groupFundsByStrategy(fundsList, Product__c.FundStrategy__c);
    }

    // Regroupe les Funds selon le champ Strategy donné, en ignorant ceux qui n'en ont pas
    private static Map<Id, List<Product__c>> groupFundsByStrategy(List<Product__c> fundsList, Schema.SObjectField strategyField) {
        Map<Id, List<Product__c>> strategyTofundsMap = new Map<Id, List<Product__c>>();
        for (Product__c fund : fundsList) {
            Id strategyId = (Id) fund.get(strategyField);
            if (strategyId == null) continue;

            if (strategyTofundsMap.get(strategyId) == null) {
                strategyTofundsMap.put(strategyId, new List<Product__c>{fund});
            }
            else {
                strategyTofundsMap.get(strategyId).add(fund);
            }
        }
        return strategyTofundsMap;
    }

    public static List<ReferentialProductHomepageCtrl.ItemDTO> getAllStrategywithFundsItems(Map<Id, List<Product__c>> strategyTofundsMap, List<Strategy__c> strategies, Map<Id, List<Share_Class__c>> fundToSharesMap) {
        List<ReferentialProductHomepageCtrl.ItemDTO> strategyItems = new List<ReferentialProductHomepageCtrl.ItemDTO>();
        for (Strategy__c str : strategies) {
            if (str.Name != null) {
                List<Product__c> fundsList = strategyTofundsMap.get(str.Id);
                if (fundsList.size() > 0) {
                    ReferentialProductHomepageCtrl.ItemDTO strategy = new ReferentialProductHomepageCtrl.ItemDTO(str.Name, null, str.Name, null, null, null, false, true, true, false, getFundsItemsWithSharesReferential(fundsList, fundToSharesMap, false));
                    strategy.id = str.Id;
                    strategy.assetclass = str.AssetClass__c;
                    if (strategy.items.size() > 0) strategyItems.add(strategy);
                }
            }
        }
        return strategyItems;
    }

    public static List<ReferentialProductHomepageCtrl.ItemDTO> getFundsItemsWithSharesReferential(List<Product__c> funds, Map<Id, List<Share_Class__c>> shares, Boolean expanded) {
        List<ReferentialProductHomepageCtrl.ItemDTO> fundItems = new List<ReferentialProductHomepageCtrl.ItemDTO>();
        for (Product__c fund : funds) {
            // Un produit sans Share Class (ex: catalogue IS en inactif) reste affiché, replié et sans enfants. Le type reste vide : le tree l'affiche devant le label.
            List<Share_Class__c> fundSharesList = shares.get(fund.Id);
            Boolean hasShares = fundSharesList != null;

            ReferentialProductHomepageCtrl.ItemDTO fundItem = new ReferentialProductHomepageCtrl.ItemDTO(fund.Name, null, fund.Name, recordUrl(fund.Id), null, null, false, fund.Validity__c, true, hasShares && expanded, hasShares ? getShareItemsReferential(fundSharesList) : null);
            fundItem.assetclass = fund.AssetClass__c;
            fundItem.regionalfocus = String.valueOf(fund.LaunchDate__c);
            fundItems.add(fundItem);
        }
        return fundItems;
    }

    public static List<ReferentialProductHomepageCtrl.ItemDTO> getShareItemsReferential(List<Share_Class__c> fundSharesList) {
        List<ReferentialProductHomepageCtrl.ItemDTO> shareItems = new List<ReferentialProductHomepageCtrl.ItemDTO>();
        for (Share_Class__c share : fundSharesList) {
            ReferentialProductHomepageCtrl.ItemDTO shareItem = new ReferentialProductHomepageCtrl.ItemDTO(share.Name, null, share.Name, recordUrl(share.Id), null, share.ISIN__c, false, isActiveShareClass(share), false, false, null);
            shareItem.assetclass = share.Fund__r.AssetClass__c;
            shareItem.regionalfocus = String.valueOf(share.Fund__r.LaunchDate__c);
            shareItems.add(shareItem);
        }
        return shareItems;
    }

    // Retourne true si la share class est considérée active selon la nouvelle règle métier
    private static Boolean isActiveShareClass(Share_Class__c share) {
        return share.Status__c == 'Active' || share.Status__c == 'Active - Lab';
    }

    /* Plus appelées nulle part (vérifié le 13-10-26) : à supprimer une fois confirmé dans l'org
    // Fund items avec leurs Share Classes et AUMs (les Funds sans Share Class sont ignorés)
    public static List<ReferentialProductHomepageCtrl.ItemDTO> getFundsItemsWithShares(List<Product__c> funds, Map<Id, List<Share_Class__c>> shares) {
        List<ReferentialProductHomepageCtrl.ItemDTO> fundItems = new List<ReferentialProductHomepageCtrl.ItemDTO>();
        for (Product__c fund : funds) {
            List<Share_Class__c> fundSharesList = shares.get(fund.Id);
            if (fundSharesList == null) continue;

            ReferentialProductHomepageCtrl.ItemDTO fundItem = new ReferentialProductHomepageCtrl.ItemDTO(fund.Name, fund.Record_Type_Name__c, fund.Name, recordUrl(fund.Id), null, null, false, fund.Validity__c, true, false, getShareItems(fundSharesList));
            if (fund.Last_AUM_Previous_Year__c != null) fundItem.aum = formatSharesAUM('(M€ ) - AUM : ', fund.Last_AUM_Previous_Year__c);
            if (fund.Last_AUM_Available__c != null) fundItem.lastaum = formatSharesAUM('- Last AUM : ', fund.Last_AUM_Available__c);
            if (fund.YTD_Net_Flows__c != null) fundItem.ytdnet = formatSharesAUM('- YTD Flows : ', fund.YTD_Net_Flows__c);
            fundItems.add(fundItem);
        }
        return fundItems;
    }

    public static List<ReferentialProductHomepageCtrl.ItemDTO> getShareItems(List<Share_Class__c> fundSharesList) {
        List<ReferentialProductHomepageCtrl.ItemDTO> shareItems = new List<ReferentialProductHomepageCtrl.ItemDTO>();
        for (Share_Class__c share : fundSharesList) {
            ReferentialProductHomepageCtrl.ItemDTO shareItem = new ReferentialProductHomepageCtrl.ItemDTO(share.Name, null, share.Name, recordUrl(share.Id), null, share.ISIN_Code__c, false, share.Validity__c, false, false, null);
            if (share.Last_AUM_Previous_Year__c != null) shareItem.aum = formatSharesAUM('(M€ ) - AUM : ', share.Last_AUM_Previous_Year__c);
            if (share.Last_AUM_Available__c != null) shareItem.lastaum = formatSharesAUM('- Last AUM : ', share.Last_AUM_Available__c);
            if (share.YTD_Net_Flows__c != null) shareItem.ytdnet = formatSharesAUM('- YTD Flows : ', share.YTD_Net_Flows__c);
            shareItems.add(shareItem);
        }
        return shareItems;
    }

    // Convertit un AUM texte (ex: "1,234,567") en millions à 2 décimales, "Not Available" reste tel quel
    public static String formatSharesAUM(String label, String value) {
        Integer million = 1000000;
        Integer decimalplace = 2;
        String cleanAum = value.replace(',', '').trim();
        if (cleanAum != 'Not Available') cleanAum = String.valueOf((Decimal.valueOf(cleanAum) / million).setScale(decimalplace));
        return label + cleanAum;
    }

    // Niveau supérieur de type SRI regroupant les Strategies données
    public static ReferentialProductHomepageCtrl.ItemDTO setItemSRI(List<ReferentialProductHomepageCtrl.ItemDTO> currentStrategies) {
        return new ReferentialProductHomepageCtrl.ItemDTO('SRI', null, null, null, null, null, false, true, true, false, currentStrategies);
    }
    */

    private static String recordUrl(Id recordId) {
        return URL.getSalesforceBaseUrl().toExternalForm() + '/' + recordId;
    }
}