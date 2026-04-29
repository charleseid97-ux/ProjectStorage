public with sharing class TaxDataActionController {
    private static final String COUNTRY_ALL = 'ALL';
    private static final String SCENARIO_INTERNAL_TAX_NOTIFICATION = 'InternalTaxTransparencyNotification';

    public class Pair {
        @AuraEnabled public String country;
        @AuraEnabled public String typeValue;
    }

    public class CreateResult {
        @AuraEnabled public Integer createdCount;
        @AuraEnabled public Map<String, String> failedByCountry;
        @AuraEnabled public List<Id> createdIds;
        @AuraEnabled public String message;

        public CreateResult() {
            createdCount = 0;
            failedByCountry = new Map<String, String>();
            createdIds = new List<Id>();
            message = '';
        }
    }

    public class UpdateResult {
        @AuraEnabled public Integer updatedCount;
        @AuraEnabled public Map<String, String> failedByCountry;
        @AuraEnabled public List<Id> updatedIds;
        @AuraEnabled public String message;

        public UpdateResult() {
            updatedCount = 0;
            failedByCountry = new Map<String, String>();
            updatedIds = new List<Id>();
            message = '';
        }
    }

    public class ClosableOption {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String country;
        @AuraEnabled public String typeValue;
    }

    @AuraEnabled(cacheable=true)
    public static Share_Class__c getContext(Id shareClassId) {
        if (shareClassId == null) return null;

        return [
            SELECT Id, Name, Fund__c
            FROM Share_Class__c
            WHERE Id = :shareClassId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static CreateResult createTaxDataPairs(Id shareClassId, String pairsJson, String comment) {
        CreateResult res = new CreateResult();

        if (shareClassId == null) {
            res.message = 'Missing Share Class Id.';
            return res;
        }

        if (String.isBlank(pairsJson)) {
            res.message = 'No countries provided (empty payload).';
            return res;
        }

        List<Pair> pairs;
        try {
            pairs = (List<Pair>) JSON.deserialize(pairsJson, List<Pair>.class);
        } catch (Exception e) {
            res.message = 'Invalid payload: ' + e.getMessage();
            return res;
        }

        if (pairs == null || pairs.isEmpty()) {
            res.message = 'No countries provided.';
            return res;
        }

        Share_Class__c sc;
        try {
            sc = [
                SELECT Id, Fund__c, Name
                FROM Share_Class__c
                WHERE Id = :shareClassId
                LIMIT 1
            ];
        } catch (Exception e) {
            res.message = 'Share Class not found.';
            return res;
        }

        List<TaxData__c> toInsert = new List<TaxData__c>();

        for (Pair p : pairs) {
            if (p == null || String.isBlank(p.country) || String.isBlank(p.typeValue)) {
                String key = (p == null || String.isBlank(p.country)) ? 'UNKNOWN' : p.country;
                res.failedByCountry.put(key, 'Missing country or type');
                continue;
            }

            if (p.country != 'BE' && p.typeValue != 'Transparency') {
                p.typeValue = 'Transparency';
            }

            TaxData__c td = new TaxData__c();
            td.ShareClass__c = shareClassId;
            td.Product__c = sc.Fund__c;
            td.Type__c = p.typeValue;
            td.Country__c = p.country;
            td.Status__c = 'Requested';
            td.Source__c = 'Manual';

            if (!String.isBlank(comment) && Schema.sObjectType.TaxData__c.fields.getMap().containsKey('Comment__c')) {
                td.Comment__c = comment;
            }

            toInsert.add(td);
        }

        if (toInsert.isEmpty()) {
            res.message = 'No valid records to insert.';
            return res;
        }

        Database.SaveResult[] srs = Database.insert(toInsert, false);

        for (Integer i = 0; i < srs.size(); i++) {
            Database.SaveResult sr = srs[i];
            String country = (String) toInsert[i].get('Country__c');
            String typeValue = (String) toInsert[i].get('Type__c');
            String key = country == 'BE' ? country + ' - ' + typeValue : country;

            if (sr.isSuccess()) {
                res.createdCount++;
                res.createdIds.add(sr.getId());
            } else {
                List<String> errors = new List<String>();
                for (Database.Error err : sr.getErrors()) {
                    errors.add(err.getMessage());
                }
                res.failedByCountry.put(key, String.join(errors, '; '));
            }
        }

        res.message = 'Processed ' + String.valueOf(pairs.size()) + ' request(s).';

        if (res.createdCount > 0) {
            try {
                sendTaxNotification(shareClassId, sc.Name, pairs, comment);
            } catch (EmailException e) {
                // Intentionally ignored
            }
        }

        return res;
    }

    private static void sendTaxNotification(
        Id shareClassId,
        String shareClassName,
        List<Pair> pairs,
        String comment
    ) {
        TaxEmailConfiguration__mdt config = getEmailConfiguration();
        if (config == null || !config.IsActive__c) {
            return;
        }

        List<String> toAddresses = splitEmails(config.ToAddresses__c);
        List<String> ccAddresses = splitEmails(config.CcAddresses__c);

        if (toAddresses.isEmpty()) {
            return;
        }

        List<String> lines = new List<String>();
        for (Pair p : pairs) {
            if (p == null) continue;

            if (p.country == 'BE') {
                lines.add('BE - ' + p.typeValue);
            } else {
                lines.add(p.country);
            }
        }

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String scUrl = baseUrl + '/' + shareClassId;

        String subject = '[Tax Transparency] New request(s) - ' +
            (shareClassName != null ? shareClassName : String.valueOf(shareClassId));

        String htmlBody =
            '<p>Hello Tax Team,</p>' +
            '<p>New Tax Transparency request(s) have been submitted.</p>' +
            '<ul>' +
            '<li><b>Share Class:</b> ' + htmlEscape(shareClassName) + '</li>' +
            '<li><b>Requests:</b><br/>' + String.join(escapeList(lines), '<br/>') + '</li>' +
            '<li><b>Comment:</b> ' + htmlEscape(String.isBlank(comment) ? '' : comment) + '</li>' +
            '<li><b>Salesforce link:</b> <a href="' + scUrl + '">Open Share Class</a></li>' +
            '</ul>' +
            '<p>Thanks,</p>';

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(toAddresses);

        if (!ccAddresses.isEmpty()) {
            email.setCcAddresses(ccAddresses);
        }

        email.setSubject(subject);
        email.setHtmlBody(htmlBody);

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }

    @AuraEnabled(cacheable=false)
    public static List<ClosableOption> getClosableTaxDataOptions(Id shareClassId) {
        List<ClosableOption> result = new List<ClosableOption>();

        if (shareClassId == null) {
            return result;
        }

        List<TaxData__c> taxDataList = [
            SELECT Id, Country__c, Type__c, Status__c, De_Register__c
            FROM TaxData__c
            WHERE ShareClass__c = :shareClassId
            AND Status__c = 'Yes'
            AND (De_Register__c = false OR De_Register__c = null)
            AND Country__c != null
            AND Type__c != null
            AND Country__c != 'IT'
            ORDER BY Country__c, Type__c
        ];

        Set<String> seenKeys = new Set<String>();

        for (TaxData__c td : taxDataList) {
            String country = td.Country__c;
            String typeValue = td.Type__c;
            String key = buildSelectionKey(country, typeValue);

            if (seenKeys.contains(key)) {
                continue;
            }

            seenKeys.add(key);

            ClosableOption option = new ClosableOption();
            option.country = country;
            option.typeValue = typeValue;
            option.key = key;
            option.label = buildClosureLabel(country, typeValue);
            result.add(option);
        }

        return result;
    }

    @AuraEnabled
    public static UpdateResult submitClosureRequests(Id shareClassId, List<String> selectionKeys) {
        UpdateResult res = new UpdateResult();

        if (shareClassId == null) {
            res.message = 'Missing Share Class Id.';
            return res;
        }

        if (selectionKeys == null || selectionKeys.isEmpty()) {
            res.message = 'No selection provided.';
            return res;
        }

        Share_Class__c sc;
        try {
            sc = [
                SELECT Id, Name, Fund__c
                FROM Share_Class__c
                WHERE Id = :shareClassId
                LIMIT 1
            ];
        } catch (Exception e) {
            res.message = 'Share Class not found.';
            return res;
        }

        Set<String> requestedKeys = new Set<String>();
        for (String key : selectionKeys) {
            if (!String.isBlank(key)) {
                requestedKeys.add(key);
            }
        }

        if (requestedKeys.isEmpty()) {
            res.message = 'No valid selection provided.';
            return res;
        }

        List<TaxData__c> recordsToUpdate = [
            SELECT Id, Country__c, Type__c, Status__c, De_Register__c
            FROM TaxData__c
            WHERE ShareClass__c = :shareClassId
            AND Status__c = 'Yes'
            AND (De_Register__c = false OR De_Register__c = null)
            AND Country__c != null
            AND Type__c != null
        ];

        List<TaxData__c> filteredToUpdate = new List<TaxData__c>();
        Set<String> foundKeys = new Set<String>();

        for (TaxData__c td : recordsToUpdate) {
            String key = buildSelectionKey(td.Country__c, td.Type__c);

            if (requestedKeys.contains(key)) {
                td.De_Register__c = true;
                filteredToUpdate.add(td);
                foundKeys.add(key);
            }
        }

        for (String requestedKey : requestedKeys) {
            if (!foundKeys.contains(requestedKey)) {
                res.failedByCountry.put(requestedKey, 'No available Tax Data found for this selection.');
            }
        }

        if (filteredToUpdate.isEmpty()) {
            res.message = 'No available Tax Data found for selected entries.';
            return res;
        }

        Database.SaveResult[] srs = Database.update(filteredToUpdate, false);
        Set<String> successfulLabels = new Set<String>();

        for (Integer i = 0; i < srs.size(); i++) {
            Database.SaveResult sr = srs[i];
            TaxData__c td = filteredToUpdate[i];
            String key = buildSelectionKey(td.Country__c, td.Type__c);
            String label = buildClosureLabel(td.Country__c, td.Type__c);

            if (sr.isSuccess()) {
                res.updatedCount++;
                res.updatedIds.add(sr.getId());
                successfulLabels.add(label);
            } else {
                List<String> errors = new List<String>();
                for (Database.Error err : sr.getErrors()) {
                    errors.add(err.getMessage());
                }
                res.failedByCountry.put(key, String.join(errors, '; '));
            }
        }

        res.message = 'Processed ' + String.valueOf(requestedKeys.size()) + ' selection(s).';

        if (!successfulLabels.isEmpty()) {
            try {
                sendTaxClosureNotification(
                    shareClassId,
                    sc.Name,
                    new List<String>(successfulLabels)
                );
            } catch (EmailException e) {
                // Intentionally ignored
            }
        }

        return res;
    }

    private static void sendTaxClosureNotification(
        Id shareClassId,
        String shareClassName,
        List<String> selections
    ) {
        TaxEmailConfiguration__mdt config = getEmailConfiguration();
        if (config == null || !config.IsActive__c || selections == null || selections.isEmpty()) {
            return;
        }

        List<String> toAddresses = splitEmails(config.ToAddresses__c);
        List<String> ccAddresses = splitEmails(config.CcAddresses__c);

        if (toAddresses.isEmpty()) {
            return;
        }

        List<String> sortedSelections = new List<String>();
        sortedSelections.addAll(selections);
        sortedSelections.sort();

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String scUrl = baseUrl + '/' + shareClassId;

        String subject = '[Tax Transparency] Closure request(s) - ' +
            (shareClassName != null ? shareClassName : String.valueOf(shareClassId));

        String htmlBody =
            '<p>Hello Tax Team,</p>' +
            '<p>New Tax Transparency closure request(s) have been submitted.</p>' +
            '<ul>' +
            '<li><b>Share Class:</b> ' + htmlEscape(shareClassName) + '</li>' +
            '<li><b>Requests:</b><br/>' + String.join(escapeList(sortedSelections), '<br/>') + '</li>' +
            '<li><b>Salesforce link:</b> <a href="' + scUrl + '">Open Share Class</a></li>' +
            '</ul>' +
            '<p>Thanks,</p>';

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(toAddresses);

        if (!ccAddresses.isEmpty()) {
            email.setCcAddresses(ccAddresses);
        }

        email.setSubject(subject);
        email.setHtmlBody(htmlBody);

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }

    @AuraEnabled(cacheable=false)
    public static List<String> getUnregisteredCountries(Id shareClassId, List<String> countries) {
        List<String> result = new List<String>();

        if (shareClassId == null || countries == null || countries.isEmpty()) {
            return result;
        }

        Set<String> requestedCountries = new Set<String>();
        Map<String, String> uiToRegistrationCountryMap = new Map<String, String>{ 'UK' => 'GB' };
        Map<String, String> registrationToUiCountryMap = new Map<String, String>{ 'GB' => 'UK' };

        for (String c : countries) {
            if (!String.isBlank(c)) {
                requestedCountries.add(c);
            }
        }

        if (requestedCountries.isEmpty()) {
            return result;
        }

        Set<String> countriesToQuery = new Set<String>();
        for (String country : requestedCountries) {
            countriesToQuery.add(
                uiToRegistrationCountryMap.containsKey(country)
                    ? uiToRegistrationCountryMap.get(country)
                    : country
            );
        }

        Set<String> registeredCountries = new Set<String>();
        for (Country__c c : [
            SELECT Country__c
            FROM Country__c
            WHERE ShareClass__c = :shareClassId
            AND Country__c IN :countriesToQuery
            AND RegistrationStatus__c IN ('REG','INSTITUTIONAL_ONLY')
        ]) {
            if (!String.isBlank(c.Country__c)) {
                String uiCountry = registrationToUiCountryMap.containsKey(c.Country__c)
                    ? registrationToUiCountryMap.get(c.Country__c)
                    : c.Country__c;
                registeredCountries.add(uiCountry);
            }
        }

        for (String country : requestedCountries) {
            if (!registeredCountries.contains(country)) {
                result.add(country);
            }
        }

        return result;
    }

    private static TaxEmailConfiguration__mdt getEmailConfiguration() {
        List<TaxEmailConfiguration__mdt> configs = [
            SELECT Country__c,
                   Scenario__c,
                   ToAddresses__c,
                   CcAddresses__c,
                   IsActive__c
            FROM TaxEmailConfiguration__mdt
            WHERE Country__c = :COUNTRY_ALL
            AND Scenario__c = :SCENARIO_INTERNAL_TAX_NOTIFICATION
            LIMIT 1
        ];

        return configs.isEmpty() ? null : configs[0];
    }

    private static String buildSelectionKey(String country, String typeValue) {
        return country + '|' + typeValue;
    }

    private static String buildClosureLabel(String country, String typeValue) {
        if (country == 'BE') {
            return 'Belgium (BE) - ' + typeValue;
        }

        Map<String, String> labelsByCode = new Map<String, String>{
            'AT' => 'Austria (AT)',
            'BE' => 'Belgium (BE)',
            'CH' => 'Switzerland (CH)',
            'IT' => 'Italy (IT)',
            'UK' => 'United Kingdom (UK)'
        };

        return labelsByCode.containsKey(country) ? labelsByCode.get(country) : country;
    }

    

    private static List<String> splitEmails(String rawEmails) {
        List<String> results = new List<String>();

        if (String.isBlank(rawEmails)) {
            return results;
        }

        String normalized = rawEmails.replace(',', ';');

        for (String email : normalized.split(';')) {
            String trimmedEmail = email != null ? email.trim() : null;
            if (!String.isBlank(trimmedEmail)) {
                results.add(trimmedEmail);
            }
        }

        return results;
    }

    private static List<String> escapeList(List<String> values) {
        List<String> escaped = new List<String>();

        if (values == null) {
            return escaped;
        }

        for (String value : values) {
            escaped.add(htmlEscape(value));
        }

        return escaped;
    }

    private static String htmlEscape(String input) {
        if (input == null) {
            return '';
        }

        String result = input;
        result = result.replace('&', '&amp;');
        result = result.replace('<', '&lt;');
        result = result.replace('>', '&gt;');
        result = result.replace('"', '&quot;');

        return result;
    }
}