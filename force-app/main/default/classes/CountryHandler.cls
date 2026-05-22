public with sharing class CountryHandler {

    private static final String COUNTRY_IT = 'IT';
    private static final String COUNTRY_BE = 'BE';

    private static final String TYPE_TRANSPARENCY = 'Transparency';
    private static final String TYPE_BELGIUM_SIMULATOR = 'Belgium Simulator';

    private static final String STATUS_YES = 'Yes';
    private static final String STATUS_NO = 'No';

    private static final String SOURCE_MANUAL = 'Manual';

    private static final Set<String> VALID_REGISTRATION_STATUSES =
        new Set<String>{ 'REG', 'INSTITUTIONAL_ONLY' };

    public static void syncItalianTaxData(List<Country__c> newList, Map<Id, Country__c> oldMap) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        Map<Id, Country__c> toActivateByShareClass = new Map<Id, Country__c>();
        Set<Id> toDeactivateShareClassIds = new Set<Id>();

        collectItalianTaxActions(newList, oldMap, toActivateByShareClass, toDeactivateShareClassIds);

        Set<Id> allShareClassIds = new Set<Id>();
        allShareClassIds.addAll(toActivateByShareClass.keySet());
        allShareClassIds.addAll(toDeactivateShareClassIds);

        if (allShareClassIds.isEmpty()) {
            return;
        }

        Map<Id, Share_Class__c> shareClassMap = getShareClasses(allShareClassIds);
        Map<Id, TaxData__c> taxByShareClassId = getExistingItalianTaxData(allShareClassIds);

        List<TaxData__c> toInsert = new List<TaxData__c>();
        List<TaxData__c> toUpdate = new List<TaxData__c>();

        prepareActivationRecords(toActivateByShareClass, shareClassMap, taxByShareClassId, toInsert, toUpdate);
        prepareDeactivationRecords(toDeactivateShareClassIds, taxByShareClassId, toUpdate);

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public static void createBelgiumSimulatorTaxData(List<Country__c> newList) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        Set<Id> belgiumShareClassIds = collectBelgiumShareClassIds(newList);

        if (belgiumShareClassIds.isEmpty()) {
            return;
        }

        Map<Id, Share_Class__c> shareClassMap = getBelgiumSimulatorShareClasses(belgiumShareClassIds);

        List<TaxData__c> taxDataToInsert = new List<TaxData__c>();

        for (Share_Class__c sc : shareClassMap.values()) {
            if (shouldCreateBelgiumSimulator(sc)) {
                taxDataToInsert.add(buildBelgiumSimulatorTaxData(sc));
            }
        }

        if (!taxDataToInsert.isEmpty()) {
            insert taxDataToInsert;
        }
    }

    private static Set<Id> collectBelgiumShareClassIds(List<Country__c> newList) {
        Set<Id> shareClassIds = new Set<Id>();

        for (Country__c countryRecord : newList) {
            if (isBelgiumShareClassCountry(countryRecord)) {
                shareClassIds.add(countryRecord.ShareClass__c);
            }
        }

        return shareClassIds;
    }

    private static Boolean isBelgiumShareClassCountry(Country__c countryRecord) {
        return countryRecord != null
            && countryRecord.ShareClass__c != null
            && countryRecord.Country__c == COUNTRY_BE;
    }

    private static Map<Id, Share_Class__c> getBelgiumSimulatorShareClasses(Set<Id> shareClassIds) {
        return new Map<Id, Share_Class__c>([
            SELECT Id, Fund__c, DividendPolicy__c, Fund__r.LegalForm__c, LaunchDate__c
            FROM Share_Class__c
            WHERE Id IN :shareClassIds
        ]);
    }

    private static Boolean shouldCreateBelgiumSimulator(Share_Class__c sc) {
        return sc != null
            && sc.DividendPolicy__c == 'Accumulating'
            && sc.Fund__r != null
            && sc.Fund__r.LegalForm__c == 'FCP';
    }

    private static TaxData__c buildBelgiumSimulatorTaxData(Share_Class__c sc) {
        TaxData__c td = new TaxData__c();
        td.ShareClass__c = sc.Id;
        td.Product__c = sc.Fund__c;
        td.Country__c = COUNTRY_BE;
        td.Type__c = TYPE_BELGIUM_SIMULATOR;
        td.Status__c = STATUS_YES;
        td.Source__c = SOURCE_MANUAL;
        td.StartDate__c = sc.LaunchDate__c;
        td.EndDate__c = null;

        return td;
    }

    private static void collectItalianTaxActions(
        List<Country__c> newList,
        Map<Id, Country__c> oldMap,
        Map<Id, Country__c> toActivateByShareClass,
        Set<Id> toDeactivateShareClassIds
    ) {
        for (Country__c c : newList) {
            if (!isItalianShareClassCountry(c)) {
                continue;
            }

            Boolean isNowEligible = isEligible(c);

            if (oldMap == null || !oldMap.containsKey(c.Id)) {
                if (isNowEligible) {
                    toActivateByShareClass.put(c.ShareClass__c, c);
                }
                continue;
            }

            collectUpdateAction(c, oldMap.get(c.Id), isNowEligible, toActivateByShareClass, toDeactivateShareClassIds);
        }
    }

    private static void collectUpdateAction(
        Country__c newCountry,
        Country__c oldCountry,
        Boolean isNowEligible,
        Map<Id, Country__c> toActivateByShareClass,
        Set<Id> toDeactivateShareClassIds
    ) {
        if (oldCountry == null) {
            return;
        }

        Boolean wasEligible = isEligible(oldCountry);

        if (!wasEligible && isNowEligible) {
            toActivateByShareClass.put(newCountry.ShareClass__c, newCountry);
        } else if (wasEligible && !isNowEligible) {
            toDeactivateShareClassIds.add(newCountry.ShareClass__c);
        } else if (isNowEligible && newCountry.RegistrationDate__c != oldCountry.RegistrationDate__c) {
            toActivateByShareClass.put(newCountry.ShareClass__c, newCountry);
        }
    }

    private static Boolean isItalianShareClassCountry(Country__c countryRecord) {
        return countryRecord != null
            && countryRecord.ShareClass__c != null
            && countryRecord.Country__c == COUNTRY_IT;
    }

    private static Boolean isEligible(Country__c countryRecord) {
        return countryRecord != null
            && VALID_REGISTRATION_STATUSES.contains(countryRecord.RegistrationStatus__c);
    }

    private static Map<Id, Share_Class__c> getShareClasses(Set<Id> shareClassIds) {
        return new Map<Id, Share_Class__c>([
            SELECT Id, Fund__c
            FROM Share_Class__c
            WHERE Id IN :shareClassIds
        ]);
    }

    private static Map<Id, TaxData__c> getExistingItalianTaxData(Set<Id> shareClassIds) {
        Map<Id, TaxData__c> taxByShareClassId = new Map<Id, TaxData__c>();

        for (TaxData__c td : [
            SELECT Id, ShareClass__c, Country__c, Type__c, Status__c, StartDate__c, EndDate__c, Source__c
            FROM TaxData__c
            WHERE ShareClass__c IN :shareClassIds
            AND Country__c = :COUNTRY_IT
            AND Type__c = :TYPE_TRANSPARENCY
        ]) {
            if (!taxByShareClassId.containsKey(td.ShareClass__c)) {
                taxByShareClassId.put(td.ShareClass__c, td);
            }
        }

        return taxByShareClassId;
    }

    private static void prepareActivationRecords(
        Map<Id, Country__c> toActivateByShareClass,
        Map<Id, Share_Class__c> shareClassMap,
        Map<Id, TaxData__c> taxByShareClassId,
        List<TaxData__c> toInsert,
        List<TaxData__c> toUpdate
    ) {
        for (Id shareClassId : toActivateByShareClass.keySet()) {
            Country__c countryRecord = toActivateByShareClass.get(shareClassId);
            TaxData__c existing = taxByShareClassId.get(shareClassId);

            if (existing == null) {
                TaxData__c newTaxData = buildItalianTaxData(shareClassId, shareClassMap.get(shareClassId), countryRecord);
                if (newTaxData != null) {
                    toInsert.add(newTaxData);
                }
            } else if (activateExistingTaxData(existing, countryRecord)) {
                toUpdate.add(existing);
            }
        }
    }

    private static TaxData__c buildItalianTaxData(
        Id shareClassId,
        Share_Class__c shareClassRecord,
        Country__c countryRecord
    ) {
        if (shareClassRecord == null) {
            return null;
        }

        TaxData__c td = new TaxData__c();
        td.ShareClass__c = shareClassId;
        td.Product__c = shareClassRecord.Fund__c;
        td.Country__c = COUNTRY_IT;
        td.Type__c = TYPE_TRANSPARENCY;
        td.Status__c = STATUS_YES;
        td.Source__c = SOURCE_MANUAL;
        td.StartDate__c = countryRecord.RegistrationDate__c;
        td.EndDate__c = null;

        return td;
    }

    private static Boolean activateExistingTaxData(TaxData__c existing, Country__c countryRecord) {
        Boolean changed = false;

        if (existing.Status__c != STATUS_YES) {
            existing.Status__c = STATUS_YES;
            changed = true;
        }

        if (existing.StartDate__c != countryRecord.RegistrationDate__c) {
            existing.StartDate__c = countryRecord.RegistrationDate__c;
            changed = true;
        }

        if (existing.EndDate__c != null) {
            existing.EndDate__c = null;
            changed = true;
        }

        return changed;
    }

    private static void prepareDeactivationRecords(
        Set<Id> toDeactivateShareClassIds,
        Map<Id, TaxData__c> taxByShareClassId,
        List<TaxData__c> toUpdate
    ) {
        for (Id shareClassId : toDeactivateShareClassIds) {
            TaxData__c existing = taxByShareClassId.get(shareClassId);

            if (existing != null && deactivateExistingTaxData(existing)) {
                toUpdate.add(existing);
            }
        }
    }

    private static Boolean deactivateExistingTaxData(TaxData__c existing) {
        Boolean changed = false;

        if (existing.Status__c != STATUS_NO) {
            existing.Status__c = STATUS_NO;
            changed = true;
        }

        if (existing.EndDate__c != Date.today()) {
            existing.EndDate__c = Date.today();
            changed = true;
        }

        return changed;
    }
}