/** ──────────────────────────────────────
 * @description Apex controller for the gridSimulation LWC.
 *              Fetches AUM (filtered by agreements), current RebateRate (from GridDetail__c via
 *              shareClass→gridId map), and ShareClass metadata for the simulation table.
 *              All derived values (GrossFees, Rebates, NetFees, AUM evolution) are computed
 *              client-side; this controller only provides the raw base data.
 * @author Charles EID
 * @testClass GridSimulationControllerTest
 * @testCoverage GridSimulationController (100%)   [27-03-26]
────────────────────────────────────── */
public with sharing class GridSimulationController {

    @AuraEnabled(cacheable=false)
    public static List<SimulationRow> getSimulationData(List<Id>  shareClassIds, List<Id>  agreementIds, String shareClassGridIdMapJson) {
        if (shareClassIds == null || shareClassIds.isEmpty()) return new List<SimulationRow>();

        // ── 1. AUM map ───────────────────────────────────────────────────────
        Map<Id, Decimal> aumByScId = buildAumMap(shareClassIds, agreementIds);

        // ── 2. RebateRate map ────────────────────────────────────────────────
        Map<Id, Decimal> rebateByScId = buildRebateMap(shareClassIds, shareClassGridIdMapJson);

        // ── 3. ShareClass info ───────────────────────────────────────────────
        Map<Id, Share_Class__c> scById = new Map<Id, Share_Class__c>([SELECT Id, Name, Name__c, ISIN__c, EffectiveManagementFees__c, Fund__r.InternalShortName__c, Fund__r.ProductName__c, Fund__r.FundStrategy__r.AssetClass__c
                                                                      FROM Share_Class__c
                                                                      WHERE Id IN :shareClassIds
                                                                      ORDER BY Fund__r.InternalShortName__c ASC, ISIN__c ASC]);

        // ── 4. Build rows ────────────────────────────────────────────────────
        List<SimulationRow> rows = new List<SimulationRow>();
        for (Id scId : shareClassIds) {
            Share_Class__c sc = scById.get(scId);
            if (sc == null) continue;

            SimulationRow row = new SimulationRow();
            row.shareClassId   = scId;
            row.shareClassName = sc.Name;
            row.shareClassType = sc.Name__c;
            row.range          = sc.Fund__r?.FundStrategy__r?.AssetClass__c;
            row.ptfCode        = sc.Fund__r?.InternalShortName__c;
            row.name           = sc.Fund__r?.ProductName__c;
            row.isin           = sc.ISIN__c;
            row.effMgtFees     = sc.EffectiveManagementFees__c;
            row.aum            = aumByScId.containsKey(scId) ? aumByScId.get(scId) : 0;
            row.rebateRate     = rebateByScId.containsKey(scId) ? rebateByScId.get(scId) : 0;
            rows.add(row);
        }

        return rows;
    }

    // ── Private helpers ───────────────────────────────────────────────────────
    private static Map<Id, Decimal> buildAumMap(List<Id> shareClassIds, List<Id> agreementIds) {
        Map<Id, Decimal> result = new Map<Id, Decimal>();
        Set<Id> scIdSet  = new Set<Id>(shareClassIds);
        Set<Id> agrIdSet = (agreementIds != null && !agreementIds.isEmpty()) ? new Set<Id>(agreementIds) : new Set<Id>();

        String q = 'SELECT ShareClass__c scId, SUM(AmountEUR__c) totalAmount' +
                   ' FROM AUM__c' +
                   ' WHERE ShareClass__c IN :scIdSet';
        q += (!agrIdSet.isEmpty())? ' AND Convention__c IN :agrIdSet' : '';
        q += ' AND Last_AUM__c = true';
        q += ' GROUP BY ShareClass__c';

        for (AggregateResult ar : Database.query(q)) {
            result.put((Id)ar.get('scId'), (Decimal)ar.get('totalAmount'));
        }
        return result;
    }

    private static Map<Id, Decimal> buildRebateMap(List<Id> shareClassIds, String shareClassGridIdMapJson) {
        Map<Id, Decimal> result = new Map<Id, Decimal>();
        if (String.isBlank(shareClassGridIdMapJson)) return result;

        Map<String, Object> rawMap = (Map<String, Object>) JSON.deserializeUntyped(shareClassGridIdMapJson);
        Set<Id> gridIds = new Set<Id>();
        for (Object val : rawMap.values()) {
            if (val != null) gridIds.add((Id)String.valueOf(val));
        }
        if (gridIds.isEmpty()) return result;

        Set<Id> scIdSet = new Set<Id>(shareClassIds);
        for (GridDetail__c gd : [SELECT ShareClass__c, RebateRate__c, GridRule__r.FinalRebateRate__c
                                 FROM GridDetail__c
                                 WHERE Grid__c IN :gridIds
                                 AND ShareClass__c IN :scIdSet
                                 AND (EndDate__c = null OR EndDate__c >= :Date.today())]) {
            Decimal rate = (gd.GridRule__r?.FinalRebateRate__c != null) ? gd.GridRule__r.FinalRebateRate__c : gd.RebateRate__c;
            if (rate != null) result.put(gd.ShareClass__c, rate);
        }
        return result;
    }

    @AuraEnabled(cacheable=false)
    public static SimulationInitData getSimulationInitData(Id gridId) {
        List<Id> shareClassIds = new List<Id>();
        Map<String, Object> scGridMap = new Map<String, Object>();
        fillShareClassToGridInfo(shareClassIds, scGridMap, gridId);

        List<Id> agreementIds = new List<Id>();
        String region = null;
        for (Grid__c grid : [SELECT Id, Agreement__c, Agreement__r.Business_Region__c FROM Grid__c WHERE Id = :gridId]) {
            if(String.isBlank(grid.Agreement__c)) continue;
            agreementIds.add(grid.Agreement__c);
            region = grid.Agreement__r.Business_Region__c;
        }

        SimulationInitData result = new SimulationInitData();
        result.rows            = getSimulationData(shareClassIds, agreementIds, JSON.serialize(scGridMap));
        result.agreementRegion = region;
        return result;
    }

    @AuraEnabled(cacheable=false)
    public static List<SimulationRow> getActiveGridSimulationData(Id agreementId) {
        if (agreementId == null) return new List<SimulationRow>();
        List<Convention__c> convs = [SELECT Grid__c FROM Convention__c WHERE Id = :agreementId LIMIT 1];
        if (convs.isEmpty() || convs[0].Grid__c == null) return new List<SimulationRow>();
        Id gridId = convs[0].Grid__c;

        List<Id> shareClassIds = new List<Id>();
        Map<String, Object> scGridMap = new Map<String, Object>();
        fillShareClassToGridInfo(shareClassIds, scGridMap, gridId);

        if (shareClassIds.isEmpty()) return new List<SimulationRow>();
        return getSimulationData(shareClassIds, new List<Id>{ agreementId }, JSON.serialize(scGridMap));
    }

    @AuraEnabled(cacheable=true)
    public static String getAgreementRegion(List<Id> agreementIds) {
        if (agreementIds == null || agreementIds.isEmpty()) return null;
        List<Convention__c> convs = [SELECT Business_Region__c FROM Convention__c WHERE Id IN :agreementIds LIMIT 1];
        return convs.isEmpty() ? null : convs[0].Business_Region__c;
    }

    private static void fillShareClassToGridInfo(List<Id> shareClassIds, Map<String, Object> scGridMap, Id gridId) {
        for (GridDetail__c gd : [SELECT ShareClass__c FROM GridDetail__c
                                 WHERE Grid__c = :gridId
                                 AND ShareClass__c != null
                                 AND (EndDate__c = null OR EndDate__c >= :Date.today())]) {
            shareClassIds.add(gd.ShareClass__c);
            scGridMap.put(String.valueOf(gd.ShareClass__c), String.valueOf(gridId));
        }
    }

    // ── Wrappers ───────────────────────────────────────────────────────────
    public class SimulationInitData {
        @AuraEnabled public List<SimulationRow> rows;
        @AuraEnabled public String agreementRegion;
    }

    public class SimulationRow {
        @AuraEnabled public Id      shareClassId;
        @AuraEnabled public String  shareClassName;
        @AuraEnabled public String  shareClassType;
        @AuraEnabled public String  range;
        @AuraEnabled public String  ptfCode;
        @AuraEnabled public String  name;
        @AuraEnabled public String  isin;
        @AuraEnabled public Decimal effMgtFees;
        @AuraEnabled public Decimal aum;
        @AuraEnabled public Decimal rebateRate;
    }
}