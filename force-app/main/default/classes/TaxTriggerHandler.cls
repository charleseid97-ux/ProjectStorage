public with sharing class TaxTriggerHandler {

    private static final String STATUS_REQUESTED = 'Requested';
    private static final String STATUS_YES = 'Yes';
    private static final String STATUS_NO = 'No';

    private static final String COUNTRY_BE = 'BE';

    private static final String TYPE_TRANSPARENCY = 'Transparency';
    private static final String TYPE_BE_ASSET_TEST = 'BE Asset Test';
    private static final String TYPE_BE_TIS = 'BE TIS';
    private static final String TYPE_BELGIUM_SIMULATOR = 'Belgium Simulator';

    private static final Decimal BE_ASSET_TEST_THRESHOLD = 10;

    private static final Set<String> BLOCKING_STATUSES =
        new Set<String>{ STATUS_REQUESTED, STATUS_YES };

    private static final Set<String> BE_TYPES =
        new Set<String>{ TYPE_BE_ASSET_TEST, TYPE_BE_TIS };

    public static void preventDuplicates(List<TaxData__c> newList, Map<Id, TaxData__c> oldMap) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        DuplicateContext ctx = buildDuplicateContext(newList, oldMap);

        if (ctx.incomingByKey.isEmpty()) {
            return;
        }

        Map<String, List<TaxData__c>> existingByKey = getExistingTaxDataByKey(ctx);

        addSameTransactionDuplicateErrors(ctx.incomingByKey);

        Map<Id, String> shareClassNameMap = getShareClassNames(ctx.recordsToValidate);
        Map<Id, String> projectShareClassNameMap = getProjectShareClassNames(ctx.recordsToValidate);

        addExistingDuplicateErrors(
            ctx.incomingByKey,
            existingByKey,
            shareClassNameMap,
            projectShareClassNameMap
        );
    }

    private class DuplicateContext {
        Set<String> incomingTypes = new Set<String>();
        Set<String> incomingCountries = new Set<String>();
        Set<Id> incomingEffectiveShareClassIds = new Set<Id>();
        Map<String, List<TaxData__c>> incomingByKey = new Map<String, List<TaxData__c>>();
        Set<TaxData__c> recordsToValidate = new Set<TaxData__c>();
    }

    private static DuplicateContext buildDuplicateContext(
        List<TaxData__c> newList,
        Map<Id, TaxData__c> oldMap
    ) {
        DuplicateContext ctx = new DuplicateContext();

        for (TaxData__c taxData : newList) {
            if (!shouldValidateDuplicate(taxData, oldMap)) {
                continue;
            }

            Id effectiveShareClassId = getEffectiveShareClassId(taxData);
            String key = buildKey(taxData, effectiveShareClassId);

            if (!ctx.incomingByKey.containsKey(key)) {
                ctx.incomingByKey.put(key, new List<TaxData__c>());
            }

            ctx.incomingByKey.get(key).add(taxData);

            if (taxData.Type__c != null) {
                ctx.incomingTypes.add(normalize(taxData.Type__c));
            }

            if (taxData.Country__c != null) {
                ctx.incomingCountries.add(normalize(taxData.Country__c));
            }

            if (effectiveShareClassId != null) {
                ctx.incomingEffectiveShareClassIds.add(effectiveShareClassId);
            }

            ctx.recordsToValidate.add(taxData);
        }

        return ctx;
    }

    private static Boolean shouldValidateDuplicate(TaxData__c taxData, Map<Id, TaxData__c> oldMap) {
        if (taxData == null) {
            return false;
        }

        if (oldMap == null || !oldMap.containsKey(taxData.Id)) {
            return true;
        }

        TaxData__c oldTaxData = oldMap.get(taxData.Id);
        if (oldTaxData == null) {
            return false;
        }

        Boolean isReopening =
            !BLOCKING_STATUSES.contains(oldTaxData.Status__c)
            && BLOCKING_STATUSES.contains(taxData.Status__c);

        Boolean isBlockingKeyChanged =
            BLOCKING_STATUSES.contains(oldTaxData.Status__c)
            && BLOCKING_STATUSES.contains(taxData.Status__c)
            && hasDuplicateKeyChanged(taxData, oldTaxData);

        return isReopening || isBlockingKeyChanged;
    }

    private static Boolean hasDuplicateKeyChanged(TaxData__c newTaxData, TaxData__c oldTaxData) {
        return String.valueOf(newTaxData.Type__c) != String.valueOf(oldTaxData.Type__c)
            || String.valueOf(newTaxData.Country__c) != String.valueOf(oldTaxData.Country__c)
            || String.valueOf(newTaxData.ShareClass__c) != String.valueOf(oldTaxData.ShareClass__c)
            || String.valueOf(newTaxData.ProjectShareclass__c) != String.valueOf(oldTaxData.ProjectShareclass__c);
    }

    private static Id getEffectiveShareClassId(TaxData__c taxData) {
        return taxData.ShareClass__c != null
            ? taxData.ShareClass__c
            : taxData.ProjectShareclass__c;
    }

    private static Map<String, List<TaxData__c>> getExistingTaxDataByKey(DuplicateContext ctx) {
        Map<String, List<TaxData__c>> existingByKey = new Map<String, List<TaxData__c>>();

        if (
            ctx.incomingTypes.isEmpty()
            || ctx.incomingCountries.isEmpty()
            || ctx.incomingEffectiveShareClassIds.isEmpty()
        ) {
            return existingByKey;
        }

        for (TaxData__c existing : [
            SELECT Id, Type__c, Country__c, ShareClass__c, ProjectShareclass__c, Status__c
            FROM TaxData__c
            WHERE Type__c IN :ctx.incomingTypes
            AND Country__c IN :ctx.incomingCountries
            AND Status__c IN :BLOCKING_STATUSES
            AND (
                ShareClass__c IN :ctx.incomingEffectiveShareClassIds
                OR ProjectShareclass__c IN :ctx.incomingEffectiveShareClassIds
            )
        ]) {
            String key = buildKey(existing, getEffectiveShareClassId(existing));

            if (!existingByKey.containsKey(key)) {
                existingByKey.put(key, new List<TaxData__c>());
            }

            existingByKey.get(key).add(existing);
        }

        return existingByKey;
    }

    private static void addSameTransactionDuplicateErrors(Map<String, List<TaxData__c>> incomingByKey) {
        for (String key : incomingByKey.keySet()) {
            List<TaxData__c> records = incomingByKey.get(key);

            if (records.size() <= 1) {
                continue;
            }

            for (TaxData__c taxData : records) {
                taxData.addError(
                    'Multiple Tax records with the same Type, Country and Share Class are being created in the same transaction. This is not allowed.'
                );
            }
        }
    }

    private static Map<Id, String> getShareClassNames(Set<TaxData__c> recordsToValidate) {
        Set<Id> ids = new Set<Id>();

        for (TaxData__c taxData : recordsToValidate) {
            if (taxData.ShareClass__c != null) {
                ids.add(taxData.ShareClass__c);
            }
        }

        Map<Id, String> result = new Map<Id, String>();

        if (ids.isEmpty()) {
            return result;
        }

        for (Share_Class__c sc : [
            SELECT Id, Name
            FROM Share_Class__c
            WHERE Id IN :ids
        ]) {
            result.put(sc.Id, sc.Name);
        }

        return result;
    }

    private static Map<Id, String> getProjectShareClassNames(Set<TaxData__c> recordsToValidate) {
        Set<Id> ids = new Set<Id>();

        for (TaxData__c taxData : recordsToValidate) {
            if (taxData.ProjectShareclass__c != null) {
                ids.add(taxData.ProjectShareclass__c);
            }
        }

        Map<Id, String> result = new Map<Id, String>();

        if (ids.isEmpty()) {
            return result;
        }

        for (ProjectShareclass__c psc : [
            SELECT Id, Name
            FROM ProjectShareclass__c
            WHERE Id IN :ids
        ]) {
            result.put(psc.Id, psc.Name);
        }

        return result;
    }

    private static void addExistingDuplicateErrors(
        Map<String, List<TaxData__c>> incomingByKey,
        Map<String, List<TaxData__c>> existingByKey,
        Map<Id, String> shareClassNameMap,
        Map<Id, String> projectShareClassNameMap
    ) {
        for (String key : incomingByKey.keySet()) {
            if (!existingByKey.containsKey(key)) {
                continue;
            }

            addDuplicateErrorsForKey(
                incomingByKey.get(key),
                existingByKey.get(key),
                shareClassNameMap,
                projectShareClassNameMap
            );
        }
    }

    private static void addDuplicateErrorsForKey(
        List<TaxData__c> incomingRecords,
        List<TaxData__c> existingRecords,
        Map<Id, String> shareClassNameMap,
        Map<Id, String> projectShareClassNameMap
    ) {
        for (TaxData__c taxData : incomingRecords) {
            if (!hasConflictWithExisting(taxData, existingRecords)) {
                continue;
            }

            taxData.addError(buildDuplicateErrorMessage(
                taxData,
                shareClassNameMap,
                projectShareClassNameMap
            ));
        }
    }

    private static Boolean hasConflictWithExisting(
        TaxData__c incoming,
        List<TaxData__c> existingRecords
    ) {
        for (TaxData__c existing : existingRecords) {
            if (incoming.Id != null && incoming.Id == existing.Id) {
                continue;
            }

            return true;
        }

        return false;
    }

    private static String buildDuplicateErrorMessage(
        TaxData__c taxData,
        Map<Id, String> shareClassNameMap,
        Map<Id, String> projectShareClassNameMap
    ) {
        String nameToShow = getEffectiveShareClassName(
            taxData,
            shareClassNameMap,
            projectShareClassNameMap
        );

        return 'A Tax record already exists for Share Class "' + nameToShow
            + '" with Type "' + (taxData.Type__c == null ? '' : taxData.Type__c)
            + '" and Country "' + (taxData.Country__c == null ? '' : taxData.Country__c)
            + '" in Requested or Yes status. Duplicate records are not allowed.';
    }

    private static String getEffectiveShareClassName(
        TaxData__c taxData,
        Map<Id, String> shareClassNameMap,
        Map<Id, String> projectShareClassNameMap
    ) {
        if (taxData.ShareClass__c != null && shareClassNameMap.containsKey(taxData.ShareClass__c)) {
            return shareClassNameMap.get(taxData.ShareClass__c);
        }

        if (
            taxData.ProjectShareclass__c != null
            && projectShareClassNameMap.containsKey(taxData.ProjectShareclass__c)
        ) {
            return projectShareClassNameMap.get(taxData.ProjectShareclass__c);
        }

        return 'Unknown';
    }

    /*public static void validateBelgiumSimulator(List<TaxData__c> newList, Map<Id, TaxData__c> oldMap) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        List<TaxData__c> recordsToValidate = new List<TaxData__c>();
        Set<Id> shareClassIds = new Set<Id>();

        for (TaxData__c taxData : newList) {
            Boolean shouldValidate = oldMap == null || !oldMap.containsKey(taxData.Id);

            if (!shouldValidate) {
                continue;
            }

            if (taxData.Type__c == TYPE_BELGIUM_SIMULATOR && taxData.Country__c == COUNTRY_BE) {
                recordsToValidate.add(taxData);

                if (taxData.ShareClass__c != null) {
                    shareClassIds.add(taxData.ShareClass__c);
                }
            }
        }

        if (recordsToValidate.isEmpty()) {
            return;
        }

        Map<Id, Share_Class__c> shareClassMap = new Map<Id, Share_Class__c>();
        if (!shareClassIds.isEmpty()) {
            shareClassMap = new Map<Id, Share_Class__c>([
                SELECT Id, Name, DividendPolicy__c, Fund__r.LegalForm__c
                FROM Share_Class__c
                WHERE Id IN :shareClassIds
            ]);
        }

        Set<Id> beRegisteredShareClassIds = new Set<Id>();
        if (!shareClassIds.isEmpty()) {
            for (Country__c c : [
                SELECT Id, ShareClass__c, Country__c
                FROM Country__c
                WHERE ShareClass__c IN :shareClassIds
                AND Country__c = :COUNTRY_BE
            ]) {
                beRegisteredShareClassIds.add(c.ShareClass__c);
            }
        }

        for (TaxData__c taxData : recordsToValidate) {
            if (taxData.ShareClass__c == null) {
                continue;
            }

            Share_Class__c sc = shareClassMap.get(taxData.ShareClass__c);

            Boolean isAccumulating = sc != null && sc.DividendPolicy__c == 'Accumulating';
            Boolean isFcp = sc != null && sc.Fund__r != null && sc.Fund__r.LegalForm__c == 'FCP';
            Boolean isRegisteredInBe = sc != null && beRegisteredShareClassIds.contains(sc.Id);

            if (!(isAccumulating && isFcp && isRegisteredInBe)) {
                taxData.addError(
                    'Belgium Simulator can only be created for Acc share classes of FCP funds registered in Belgium.'
                );
            }
        }
    }*/

    public static void handleDates(List<TaxData__c> newList, Map<Id, TaxData__c> oldMap) {
        if (newList == null || newList.isEmpty() || oldMap == null) {
            return;
        }

        for (TaxData__c taxData : newList) {
            TaxData__c oldTaxData = oldMap.get(taxData.Id);

            if (oldTaxData == null) {
                continue;
            }

            if (!BE_TYPES.contains(taxData.Type__c)) {
                applyStandardDateRules(taxData, oldTaxData);
            }

            if (taxData.Type__c == TYPE_BE_ASSET_TEST
                && taxData.Value__c != null
                && taxData.Value__c != oldTaxData.Value__c) {
                applyBeAssetTestValueRule(taxData);
            }

            if (taxData.Type__c == TYPE_BE_TIS
                && taxData.Value__c != null
                && taxData.Value__c != oldTaxData.Value__c) {
                taxData.Status__c = STATUS_YES;
            }
        }
    }

    private static void applyStandardDateRules(TaxData__c taxData, TaxData__c oldTaxData) {
        if (taxData.StartDate__c != oldTaxData.StartDate__c && taxData.StartDate__c != null) {
            taxData.Status__c = STATUS_YES;
        }

        if (taxData.EndDate__c != oldTaxData.EndDate__c && taxData.EndDate__c != null) {
            taxData.Status__c = STATUS_NO;
        }
    }

    private static void applyBeAssetTestValueRule(TaxData__c taxData) {
        Date today = Date.today();
        Integer fiscalYearStart = today.year();

        taxData.Status__c = STATUS_YES;
        taxData.StartDate__c = Date.newInstance(fiscalYearStart, 5, 1);
        taxData.EndDate__c = Date.newInstance(fiscalYearStart + 1, 4, 30);
    }

    public static void archiveHistory(List<TaxData__c> newList, Map<Id, TaxData__c> oldMap) {
        if (newList == null || newList.isEmpty() || oldMap == null) {
            return;
        }

        List<TaxDataHistory__c> historiesToInsert = new List<TaxDataHistory__c>();

        for (TaxData__c newRec : newList) {
            TaxData__c oldRec = oldMap.get(newRec.Id);

            if (oldRec == null) {
                continue;
            }

            if (shouldArchiveHistory(newRec, oldRec)) {
                historiesToInsert.add(buildHistory(newRec, oldRec));
            }
        }

        if (!historiesToInsert.isEmpty()) {
            insert historiesToInsert;
        }
    }

    private static Boolean shouldArchiveHistory(TaxData__c newRec, TaxData__c oldRec) {
        return newRec.Value__c != oldRec.Value__c
            && oldRec.Value__c != null
            && (newRec.Type__c == TYPE_BE_TIS || newRec.Type__c == TYPE_BE_ASSET_TEST);
    }

    private static TaxDataHistory__c buildHistory(TaxData__c newRec, TaxData__c oldRec) {
        TaxDataHistory__c hist = new TaxDataHistory__c();
        hist.TaxData__c = oldRec.Id;
        hist.Value__c = oldRec.Value__c;
        hist.StartDate__c = newRec.Type__c == TYPE_BE_ASSET_TEST ? oldRec.StartDate__c : null;
        hist.EndDate__c = newRec.Type__c == TYPE_BE_ASSET_TEST ? oldRec.EndDate__c : null;
        hist.NAV_Date__c = newRec.Type__c == TYPE_BE_TIS ? oldRec.NAV_Date__c : null;
        hist.ArchivedOn__c = System.now();
        hist.ArchivedBy__c = UserInfo.getUserId();

        return hist;
    }

    private static String buildKey(TaxData__c taxData, Id effectiveShareClassId) {
        String typePart = taxData.Type__c == null ? '' : normalize(taxData.Type__c);
        String countryPart = taxData.Country__c == null ? '' : normalize(taxData.Country__c);
        String scPart = effectiveShareClassId == null ? '' : String.valueOf(effectiveShareClassId);

        return typePart + '|' + countryPart + '|' + scPart;
    }

    private static String normalize(String value) {
        if (value == null) {
            return '';
        }

        return value.trim().toLowerCase();
    }

    public static void populateTaxDataName(List<TaxData__c> newList) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        Set<Id> shareClassIds = new Set<Id>();
        Set<Id> projectShareclassIds = new Set<Id>();

        for (TaxData__c rec : newList) {
            if (rec.ShareClass__c != null) {
                shareClassIds.add(rec.ShareClass__c);
            } else if (rec.ProjectShareclass__c != null) {
                projectShareclassIds.add(rec.ProjectShareclass__c);
            }
        }

        Map<Id, Share_Class__c> shareClassMap = getShareClassesForNames(shareClassIds);
        Map<Id, ProjectShareclass__c> projectShareclassMap = getProjectShareClassesForNames(projectShareclassIds);

        for (TaxData__c rec : newList) {
            populateSingleTaxDataName(rec, shareClassMap, projectShareclassMap);
        }
    }

    private static Map<Id, Share_Class__c> getShareClassesForNames(Set<Id> shareClassIds) {
        if (shareClassIds.isEmpty()) {
            return new Map<Id, Share_Class__c>();
        }

        return new Map<Id, Share_Class__c>([
            SELECT Id, Name__c, Fund__r.Name
            FROM Share_Class__c
            WHERE Id IN :shareClassIds
        ]);
    }

    private static Map<Id, ProjectShareclass__c> getProjectShareClassesForNames(Set<Id> projectShareclassIds) {
        if (projectShareclassIds.isEmpty()) {
            return new Map<Id, ProjectShareclass__c>();
        }

        return new Map<Id, ProjectShareclass__c>([
            SELECT Id, Name__c, ProjectProduct__r.InternalShortName__c
            FROM ProjectShareclass__c
            WHERE Id IN :projectShareclassIds
        ]);
    }

    private static void populateSingleTaxDataName(
        TaxData__c rec,
        Map<Id, Share_Class__c> shareClassMap,
        Map<Id, ProjectShareclass__c> projectShareclassMap
    ) {
        String fundName = '';
        String shareClassName = '';

        if (rec.ShareClass__c != null && shareClassMap.containsKey(rec.ShareClass__c)) {
            Share_Class__c sc = shareClassMap.get(rec.ShareClass__c);
            shareClassName = sc.Name__c;
            fundName = sc.Fund__r != null ? sc.Fund__r.Name : '';
        } else if (rec.ProjectShareclass__c != null && projectShareclassMap.containsKey(rec.ProjectShareclass__c)) {
            ProjectShareclass__c psc = projectShareclassMap.get(rec.ProjectShareclass__c);
            shareClassName = psc.Name__c;
            fundName = psc.ProjectProduct__r != null ? psc.ProjectProduct__r.InternalShortName__c : '';
        }

        rec.Name = buildRequestName(
            rec.Type__c,
            rec.Country__c,
            fundName,
            shareClassName
        );
    }

    public static String buildRequestName(
        String typeValue,
        String country,
        String fundName,
        String shareClassName
    ) {
        String namePart = getNamePart(fundName, shareClassName);
        List<String> parts = getRequestNamePrefixParts(typeValue, country);

        String prefix = String.join(parts, ' - ') + ' - ';
        String dateStr = formatTodayIso();
        String suffix = buildNameSuffix(namePart, dateStr);

        Integer maxLength = 80;
        Integer remaining = maxLength - prefix.length();

        if (remaining <= 0) {
            return prefix.substring(0, maxLength);
        }

        if (suffix.length() > remaining) {
            suffix = trimSuffixKeepingDate(namePart, dateStr, remaining);
        }

        return prefix + suffix;
    }

    private static String getNamePart(String fundName, String shareClassName) {
        if (!String.isBlank(fundName) && !String.isBlank(shareClassName)) {
            return fundName + ' ' + shareClassName;
        }

        if (!String.isBlank(shareClassName)) {
            return shareClassName;
        }

        if (!String.isBlank(fundName)) {
            return fundName;
        }

        return '';
    }

    private static List<String> getRequestNamePrefixParts(String typeValue, String country) {
        List<String> parts = new List<String>();

        if (country == COUNTRY_BE) {
            String typeLabel = normalizeBEType(typeValue);
            if (!String.isBlank(typeLabel)) {
                parts.add(typeLabel);
            }
        } else if (typeValue == TYPE_TRANSPARENCY) {
            parts.add(TYPE_TRANSPARENCY);
        }

        if (!String.isBlank(country)) {
            parts.add(country);
        }

        return parts;
    }

    private static String formatTodayIso() {
        Date d = Date.today();

        return String.valueOf(d.year()) + '-'
            + String.valueOf(d.month()).leftPad(2, '0') + '-'
            + String.valueOf(d.day()).leftPad(2, '0');
    }

    private static String buildNameSuffix(String namePart, String dateStr) {
        if (String.isBlank(dateStr)) {
            return namePart;
        }

        return namePart + ' – ' + dateStr;
    }

    private static String trimSuffixKeepingDate(String namePart, String dateStr, Integer remaining) {
        Integer dateLength = dateStr.length() + 3;
        Integer maxNameLength = remaining - dateLength;

        if (maxNameLength <= 0) {
            return dateStr;
        }

        String trimmedName = namePart;

        if (trimmedName.length() > maxNameLength) {
            trimmedName = trimmedName.substring(0, maxNameLength);
        }

        return trimmedName + ' – ' + dateStr;
    }

    public static String normalizeBEType(String typeValue) {
        if (typeValue == TYPE_BE_TIS) {
            return 'TIS';
        }

        if (typeValue == TYPE_BE_ASSET_TEST) {
            return 'Asset Test';
        }

        if (typeValue == TYPE_BELGIUM_SIMULATOR) {
            return 'Simulator';
        }

        return '';
    }

    public static void createBeTisWhenAssetTestExceedsThreshold(
        List<TaxData__c> newList,
        Map<Id, TaxData__c> oldMap
    ) {
        if (newList == null || newList.isEmpty() || oldMap == null) {
            return;
        }

        Set<Id> shareClassIds = new Set<Id>();

        for (TaxData__c taxData : newList) {
            TaxData__c oldTaxData = oldMap.get(taxData.Id);

            if (shouldCreateBeTis(taxData, oldTaxData)) {
                shareClassIds.add(taxData.ShareClass__c);
            }
        }

        if (shareClassIds.isEmpty()) {
            return;
        }

        Map<Id, TaxData__c> existingBeTisByShareClassId = getExistingBeTisTaxData(shareClassIds);

        List<TaxData__c> beTisToInsert = new List<TaxData__c>();

        for (TaxData__c taxData : newList) {
            TaxData__c oldTaxData = oldMap.get(taxData.Id);

            if (!shouldCreateBeTis(taxData, oldTaxData)) {
                continue;
            }

            if (existingBeTisByShareClassId.containsKey(taxData.ShareClass__c)) {
                continue;
            }

            beTisToInsert.add(buildBeTisTaxData(taxData));
        }

        if (!beTisToInsert.isEmpty()) {
            insert beTisToInsert;
        }
    }

    private static Boolean shouldCreateBeTis(TaxData__c taxData, TaxData__c oldTaxData) {
        return taxData != null
            && oldTaxData != null
            && taxData.Type__c == TYPE_BE_ASSET_TEST
            && taxData.Country__c == COUNTRY_BE
            && taxData.ShareClass__c != null
            && taxData.Value__c != null
            && taxData.Value__c > BE_ASSET_TEST_THRESHOLD
            && taxData.Value__c != oldTaxData.Value__c;
    }

    private static Map<Id, TaxData__c> getExistingBeTisTaxData(Set<Id> shareClassIds) {
        Map<Id, TaxData__c> result = new Map<Id, TaxData__c>();

        for (TaxData__c taxData : [
            SELECT Id, ShareClass__c
            FROM TaxData__c
            WHERE ShareClass__c IN :shareClassIds
            AND Country__c = :COUNTRY_BE
            AND Type__c = :TYPE_BE_TIS
            AND Status__c IN :BLOCKING_STATUSES
        ]) {
            if (!result.containsKey(taxData.ShareClass__c)) {
                result.put(taxData.ShareClass__c, taxData);
            }
        }

        return result;
    }

    private static TaxData__c buildBeTisTaxData(TaxData__c assetTest) {
        TaxData__c beTis = new TaxData__c();
        beTis.ShareClass__c = assetTest.ShareClass__c;
        //beTis.ProjectShareclass__c = assetTest.ProjectShareclass__c;
        beTis.Product__c = assetTest.Product__c;
        beTis.Country__c = COUNTRY_BE;
        beTis.Type__c = TYPE_BE_TIS;
        beTis.Status__c = STATUS_YES;

        return beTis;
    }   
    
}