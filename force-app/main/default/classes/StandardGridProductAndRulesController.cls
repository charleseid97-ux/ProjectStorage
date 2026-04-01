/** ──────────────────────────────────────
 * @description Controller for the standardGridProductsAndRules LWC.
 *              Returns Standard Grid groups (with products and hover data) for a given Grid__c record.
 *              Also provides share class composition data (restricted/unrestricted types, excluded funds)
 *              for the right-column "Share Class Overview" panel.
 * @author Charles EID
 * Test Class: StdGridProductAndRulesControllerTest
 * Coverage: 100%   [27-02-26]
────────────────────────────────────── */
public with sharing class StandardGridProductAndRulesController {

    @AuraEnabled(cacheable=true)
    public static List<GridRecapHelper.StandardGridGroup> getStandardGridData(Id gridId) {
        return GridRecapHelper.buildStandardGridGroups(gridId, true);
    }

    @AuraEnabled(cacheable=true)
    public static ShareClassComposition getShareClassComposition(String gridId) {
        GridBuilderSetting__mdt setting = [SELECT DefaultShareTypeInclusion__c FROM GridBuilderSetting__mdt WHERE DeveloperName = 'CustomGridBuilderSetting' LIMIT 1];
        Set<String> defaultTypes = new Set<String>(GridBuilderHelper.stringToList(setting.DefaultShareTypeInclusion__c, ','));

        Map<String, Set<String>> restrictedMap   = new Map<String, Set<String>>();
        Map<String, Set<String>> unrestrictedMap = new Map<String, Set<String>>();
        Set<String> inGridShortNames = new Set<String>();

        for (GridDetail__c detail : [SELECT ShareClass__r.Type__c, ShareClass__r.Fund__r.InternalShortName__c,
                                            GridCriteria__r.SelectedShareTypes__c 
                                     FROM GridDetail__c 
                                     WHERE Grid__c = :gridId 
                                     AND ShareClass__c != null]) {
            String type = detail.ShareClass__r.Type__c;
            String shortName = detail.ShareClass__r.Fund__r?.InternalShortName__c;
            Set<String> criteriaTypes = new Set<String>(GridBuilderHelper.stringToList(detail.GridCriteria__r?.SelectedShareTypes__c, ','));

            if (String.isNotBlank(shortName)) {
                inGridShortNames.add(shortName);
            }
            if (String.isBlank(type)) continue;

            if (!defaultTypes.contains(type)) {
                if (!restrictedMap.containsKey(type)) {
                    restrictedMap.put(type, new Set<String>());
                }
                if (String.isNotBlank(shortName)) {
                    restrictedMap.get(type).add(shortName);
                }
            } 
            else if (criteriaTypes.contains(type)) {
                if (!unrestrictedMap.containsKey(type)) {
                    unrestrictedMap.put(type, new Set<String>());
                }
                if (String.isNotBlank(shortName)) {
                    unrestrictedMap.get(type).add(shortName);
                }
            }
        }

        List<String> excludedFundShortNames = new List<String>();
        try {
            List<Convention__c> agreements = [SELECT Countries_of_Distribution__c 
                                              FROM Convention__c 
                                              WHERE (Grid__c = :gridId OR Grid_Request__c = :gridId) 
                                              AND Countries_of_Distribution__c != null LIMIT 1];
            String countries = agreements.isEmpty() ? null : agreements[0].Countries_of_Distribution__c;
            GridBuilderController.AvailableGridsResult gridsResult = GridBuilderController.getAvailableGrids(countries, '');
            List<String> availableGridIds = new List<String>(gridsResult.gridShareClassIds.keySet());
            GridBuilderHelper.ProductSelectionResult allProducts = GridBuilderHelper.buildProductSelectionResult('CustomGridBuilderSetting', countries, null, null, new Set<Id>(), null, new Map<Id, String>(), false, null, false, availableGridIds);
            for (GridBuilderHelper.ProductWrapper product : allProducts.products) {
                String label     = product.productLabel;
                Integer openIdx  = label != null ? label.lastIndexOf('(') : -1;
                Integer closeIdx = label != null ? label.lastIndexOf(')') : -1;
                String shortName = (openIdx >= 0 && closeIdx > openIdx) ? label.substring(openIdx + 1, closeIdx) : null;
                if (String.isNotBlank(shortName) && !inGridShortNames.contains(shortName)) {
                    excludedFundShortNames.add(shortName);
                }
            }
            excludedFundShortNames.sort();
        } 
        catch (Exception e) {
            System.debug('No agreement or no available grids — Section 3 stays empty');
        }

        ShareClassComposition result = new ShareClassComposition();
        result.defaultShareTypeInclusion = setting.DefaultShareTypeInclusion__c;
        result.restricted                = toShareTypeGroupList(restrictedMap, inGridShortNames);
        result.unrestricted              = toShareTypeGroupList(unrestrictedMap, inGridShortNames);
        result.excludedFundShortNames    = excludedFundShortNames;
        return result;
    }

    private static List<ShareTypeGroup> toShareTypeGroupList(Map<String, Set<String>> typeMap, Set<String> allShortNames) {
        List<String> sortedTypes = new List<String>(typeMap.keySet());
        sortedTypes.sort();
        List<ShareTypeGroup> groups = new List<ShareTypeGroup>();
        for (String type : sortedTypes) {
            Set<String> present = typeMap.get(type);
            Set<String> missing = new Set<String>(allShortNames);
            missing.removeAll(present);
            ShareTypeGroup g = new ShareTypeGroup();
            g.shareType         = type;
            g.isAllFunds        = missing.isEmpty();
            g.productShortNames = new List<String>(present);
            g.productShortNames.sort();
            g.missingShortNames = new List<String>(missing);
            g.missingShortNames.sort();
            groups.add(g);
        }
        return groups;
    }

    public class ShareClassComposition {
        @AuraEnabled public List<ShareTypeGroup> restricted            { get; set; }
        @AuraEnabled public List<ShareTypeGroup> unrestricted          { get; set; }
        @AuraEnabled public List<String>         excludedFundShortNames { get; set; }
        @AuraEnabled public String               defaultShareTypeInclusion { get; set; }
    }

    public class ShareTypeGroup {
        @AuraEnabled public String       shareType         { get; set; }
        @AuraEnabled public List<String> productShortNames { get; set; }
        @AuraEnabled public List<String> missingShortNames { get; set; }
        @AuraEnabled public Boolean      isAllFunds        { get; set; }
    }
}