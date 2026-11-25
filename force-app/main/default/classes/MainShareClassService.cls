public without sharing class MainShareClassService {

    private static final String UkCountryCode = 'GB';
    private static final String UkScope = 'UK';
    private static final String AllCountriesScope = 'ALL_COUNTRIES';
    private static final String GroupKeySeparator = '|';
    private static final String SystemManagedFieldError = 'Is Main Share Class is managed automatically and cannot be modified manually.';

    private static final Set<String> EligibleRegistrationStatuses = new Set<String>{
        'REG',
        'INSTITUTIONAL_ONLY',
        'SEMI_PRO'
    };

    private static Boolean IsProcessing = false;
    @TestVisible private static List<RuleDefinition> TestRules;

    public class MainShareClassException extends Exception {
    }

    public class RuleDefinition {
        public String DeveloperName;
        public String Scope;
        public String LegalForm;
        public String ShareClassName;
        public Decimal Priority;
        public Boolean IsActive;
        public Boolean IsExcluded;
        public Boolean IsForceMain;
        public Datetime ModifiedAt;
    }

    private class RuleCandidate {
        public Country__c Registration;
        public RuleDefinition Rule;

        // Stores the registration and the rule that applies to it.
        public RuleCandidate(Country__c registration, RuleDefinition rule) {
            this.Registration = registration;
            this.Rule = rule;
        }
    }

    // Prevents users and integrations from setting the calculated flag directly.
    public static void validateSystemManagedField(
        List<Country__c> newRegistrations,
        Map<Id, Country__c> oldRegistrationsMap
    ) {
        if (IsProcessing || newRegistrations == null || newRegistrations.isEmpty()) {
            return;
        }

        for (Country__c registration : newRegistrations) {
            Country__c oldRegistration = oldRegistrationsMap == null ? null : oldRegistrationsMap.get(registration.Id);
            Boolean isManualChange = oldRegistration == null
                ? registration.IsMainShareClass__c == true
                : registration.IsMainShareClass__c != oldRegistration.IsMainShareClass__c;

            if (isManualChange) {
                registration.IsMainShareClass__c.addError(SystemManagedFieldError);
            }
        }
    }

    // Recalculates the Product + Country groups impacted by newly created registrations.
    public static void recalculateAfterCountryInsert(List<Country__c> newRegistrations) {
        if (IsProcessing) {
            return;
        }

        recalculateFromCountryRecords(newRegistrations);
    }

    // Recalculates both old and new groups when a registration changes selection data.
    public static void recalculateAfterCountryUpdate(
        List<Country__c> newRegistrations,
        Map<Id, Country__c> oldRegistrationsMap
    ) {
        if (IsProcessing || newRegistrations == null || oldRegistrationsMap == null) {
            return;
        }

        List<Country__c> affectedRegistrations = new List<Country__c>();
        for (Country__c newRegistration : newRegistrations) {
            Country__c oldRegistration = oldRegistrationsMap.get(newRegistration.Id);
            if (!hasRelevantCountryChange(newRegistration, oldRegistration)) {
                continue;
            }

            affectedRegistrations.add(oldRegistration);
            affectedRegistrations.add(newRegistration);
        }

        recalculateFromCountryRecords(affectedRegistrations);
    }

    // Recalculates the former group after a Country Registration is deleted.
    public static void recalculateAfterCountryDelete(List<Country__c> oldRegistrations) {
        if (IsProcessing) {
            return;
        }

        recalculateFromCountryRecords(oldRegistrations);
    }

    // Recalculates existing registrations linked to newly created Share Classes.
    public static void recalculateAfterShareClassInsert(List<Share_Class__c> newShareClasses) {
        if (IsProcessing || newShareClasses == null || newShareClasses.isEmpty()) {
            return;
        }

        Set<Id> shareClassIds = new Map<Id, Share_Class__c>(newShareClasses).keySet();
        recalculateFromShareClasses(shareClassIds, null, new Map<Id, Share_Class__c>(newShareClasses));
    }

    // Recalculates old and new groups when Fund or Share Class Name changes.
    public static void recalculateAfterShareClassUpdate(
        List<Share_Class__c> newShareClasses,
        Map<Id, Share_Class__c> oldShareClassesMap
    ) {
        if (IsProcessing || newShareClasses == null || oldShareClassesMap == null) {
            return;
        }

        Set<Id> changedShareClassIds = new Set<Id>();
        Map<Id, Share_Class__c> changedNewShareClasses = new Map<Id, Share_Class__c>();
        for (Share_Class__c newShareClass : newShareClasses) {
            Share_Class__c oldShareClass = oldShareClassesMap.get(newShareClass.Id);
            if (!hasRelevantShareClassChange(newShareClass, oldShareClass)) {
                continue;
            }

            changedShareClassIds.add(newShareClass.Id);
            changedNewShareClasses.put(newShareClass.Id, newShareClass);
        }

        recalculateFromShareClasses(changedShareClassIds, oldShareClassesMap, changedNewShareClasses);
    }

    // Recalculates groups containing the registrations supplied by the initialization batch.
    public static void recalculateByRegistrationIds(Set<Id> registrationIds) {
        if (IsProcessing || registrationIds == null || registrationIds.isEmpty()) {
            return;
        }

        List<Country__c> registrations = [
            SELECT Id, Country__c, ShareClass__c
            FROM Country__c
            WHERE Id IN :registrationIds
        ];
        recalculateFromCountryRecords(registrations);
    }

    // Collects Product + Country keys from Country Registration records and recalculates them.
    private static void recalculateFromCountryRecords(List<Country__c> registrations) {
        if (registrations == null || registrations.isEmpty()) {
            return;
        }

        Set<Id> shareClassIds = collectShareClassIds(registrations);
        if (shareClassIds.isEmpty()) {
            return;
        }

        Map<Id, Share_Class__c> shareClasses = new Map<Id, Share_Class__c>([
            SELECT Id, Fund__c, Name__c
            FROM Share_Class__c
            WHERE Id IN :shareClassIds
        ]);

        Set<String> groupKeys = collectGroupKeys(registrations, shareClasses);
        recalculateGroups(groupKeys);
    }

    // Collects old and new Product + Country keys for Share Class changes.
    private static void recalculateFromShareClasses(
        Set<Id> shareClassIds,
        Map<Id, Share_Class__c> oldShareClassesMap,
        Map<Id, Share_Class__c> newShareClassesMap
    ) {
        if (shareClassIds == null || shareClassIds.isEmpty()) {
            return;
        }

        List<Country__c> registrations = [
            SELECT Id, Country__c, ShareClass__c
            FROM Country__c
            WHERE ShareClass__c IN :shareClassIds
        ];

        Set<String> groupKeys = new Set<String>();
        for (Country__c registration : registrations) {
            if (registration == null || String.isBlank(registration.Country__c)) {
                continue;
            }

            addShareClassGroupKey(groupKeys, oldShareClassesMap, registration.ShareClass__c, registration.Country__c);
            addShareClassGroupKey(groupKeys, newShareClassesMap, registration.ShareClass__c, registration.Country__c);
        }

        recalculateGroups(groupKeys);
    }

    // Adds a Product + Country key when the Share Class has a related fund.
    private static void addShareClassGroupKey(
        Set<String> groupKeys,
        Map<Id, Share_Class__c> shareClassesMap,
        Id shareClassId,
        String countryCode
    ) {
        if (shareClassesMap == null || !shareClassesMap.containsKey(shareClassId)) {
            return;
        }

        Share_Class__c shareClassRecord = shareClassesMap.get(shareClassId);
        if (shareClassRecord.Fund__c != null) {
            groupKeys.add(buildGroupKey(shareClassRecord.Fund__c, countryCode));
        }
    }

    // Queries all registrations in the impacted groups and applies the configured rules.
    private static void recalculateGroups(Set<String> groupKeys) {
        if (groupKeys == null || groupKeys.isEmpty() || IsProcessing) {
            return;
        }

        Set<Id> fundIds = collectFundIds(groupKeys);
        Set<String> countryCodes = collectCountryCodes(groupKeys);
        List<Country__c> registrations = queryRegistrations(fundIds, countryCodes);
        Map<String, List<Country__c>> registrationsByGroup = groupRegistrations(registrations, groupKeys);
        Map<String, List<RuleDefinition>> rulesByContext = groupRulesByContext(loadRules());

        List<Country__c> registrationsToUpdate = buildRegistrationUpdates(
            groupKeys,
            registrationsByGroup,
            rulesByContext
        );

        if (registrationsToUpdate.isEmpty()) {
            return;
        }

        IsProcessing = true;
        try {
            update registrationsToUpdate;
        } finally {
            IsProcessing = false;
        }
    }

    // Loads all active Custom Metadata rules and maps their configuration to an internal model.
    private static List<RuleDefinition> loadRules() {
        if (TestRules != null) {
            return TestRules;
        }

        List<RuleDefinition> rules = new List<RuleDefinition>();
        for (MainShareClassRule__mdt metadataRule : [
            SELECT DeveloperName, Scope__c, LegalForm__c, ShareClassName__c, Priority__c,
                   Active__c, Excluded__c, ForceMain__c, SystemModstamp
            FROM MainShareClassRule__mdt
            WHERE Active__c = true
        ]) {
            rules.add(toRuleDefinition(metadataRule));
        }

        return rules;
    }

    // Converts a Custom Metadata record into the rule model used by the calculation engine.
    private static RuleDefinition toRuleDefinition(MainShareClassRule__mdt metadataRule) {
        RuleDefinition rule = new RuleDefinition();
        rule.DeveloperName = metadataRule.DeveloperName;
        rule.Scope = metadataRule.Scope__c;
        rule.LegalForm = metadataRule.LegalForm__c;
        rule.ShareClassName = metadataRule.ShareClassName__c;
        rule.Priority = metadataRule.Priority__c;
        rule.IsActive = metadataRule.Active__c;
        rule.IsExcluded = metadataRule.Excluded__c;
        rule.IsForceMain = metadataRule.ForceMain__c;
        rule.ModifiedAt = metadataRule.SystemModstamp;
        return rule;
    }

    // Groups active rules by Scope + Legal Form for efficient group evaluation.
    private static Map<String, List<RuleDefinition>> groupRulesByContext(List<RuleDefinition> rules) {
        Map<String, List<RuleDefinition>> rulesByContext = new Map<String, List<RuleDefinition>>();
        for (RuleDefinition rule : rules) {
            if (rule == null || rule.IsActive != true || String.isBlank(rule.Scope) || String.isBlank(rule.LegalForm)) {
                continue;
            }

            String contextKey = buildContextKey(rule.Scope, rule.LegalForm);
            if (!rulesByContext.containsKey(contextKey)) {
                rulesByContext.put(contextKey, new List<RuleDefinition>());
            }
            rulesByContext.get(contextKey).add(rule);
        }

        return rulesByContext;
    }

    // Builds only the Country records whose Main Share Class flag really changes.
    private static List<Country__c> buildRegistrationUpdates(
        Set<String> groupKeys,
        Map<String, List<Country__c>> registrationsByGroup,
        Map<String, List<RuleDefinition>> rulesByContext
    ) {
        List<Country__c> registrationsToUpdate = new List<Country__c>();
        for (String groupKey : groupKeys) {
            List<Country__c> groupRegistrations = registrationsByGroup.get(groupKey);
            if (groupRegistrations == null || groupRegistrations.isEmpty()) {
                continue;
            }

            Id selectedRegistrationId = selectMainRegistration(groupRegistrations, rulesByContext);
            for (Country__c registration : groupRegistrations) {
                Boolean shouldBeMain = registration.Id == selectedRegistrationId;
                if (registration.IsMainShareClass__c != shouldBeMain) {
                    registrationsToUpdate.add(new Country__c(
                        Id = registration.Id,
                        IsMainShareClass__c = shouldBeMain
                    ));
                }
            }
        }

        return registrationsToUpdate;
    }

    // Selects the registration that wins ForceMain or the standard priority rules.
    @TestVisible
    private static Id selectMainRegistration(
        List<Country__c> registrations,
        Map<String, List<RuleDefinition>> rulesByContext
    ) {
        List<Country__c> eligibleRegistrations = getEligibleRegistrations(registrations);
        if (eligibleRegistrations.isEmpty()) {
            return null;
        }

        // Uses the only eligible registered Share Class as Main when no competition exists.
        if (eligibleRegistrations.size() == 1) {
            return eligibleRegistrations[0].Id;
        }

        Country__c firstRegistration = eligibleRegistrations[0];
        String legalForm = firstRegistration.ShareClass__r.Fund__r.LegalForm__c;
        String scope = firstRegistration.Country__c == UkCountryCode ? UkScope : AllCountriesScope;
        List<RuleDefinition> contextRules = rulesByContext.get(buildContextKey(scope, legalForm));
        if (contextRules == null || contextRules.isEmpty()) {
            return null;
        }

        List<RuleCandidate> candidates = buildCandidates(eligibleRegistrations, contextRules);
        validateCandidates(candidates, scope, legalForm);
        RuleCandidate forcedCandidate = selectForcedCandidate(candidates, scope, legalForm);
        return forcedCandidate == null ? selectPriorityCandidate(candidates) : forcedCandidate.Registration.Id;
    }

    // Keeps only registrations with one of the three functional eligible statuses.
    private static List<Country__c> getEligibleRegistrations(List<Country__c> registrations) {
        List<Country__c> eligibleRegistrations = new List<Country__c>();
        for (Country__c registration : registrations) {
            if (registration != null
                && registration.ShareClass__r != null
                && registration.ShareClass__r.Fund__r != null
                && EligibleRegistrationStatuses.contains(registration.RegistrationStatus__c)) {
                eligibleRegistrations.add(registration);
            }
        }

        return eligibleRegistrations;
    }

    // Matches each eligible registration to its active rule using the Share Class Name.
    private static List<RuleCandidate> buildCandidates(
        List<Country__c> eligibleRegistrations,
        List<RuleDefinition> contextRules
    ) {
        Map<String, List<RuleDefinition>> rulesByShareClassName = new Map<String, List<RuleDefinition>>();
        for (RuleDefinition rule : contextRules) {
            if (rule == null || String.isBlank(rule.ShareClassName)) {
                continue;
            }

            String normalizedRuleName = rule.ShareClassName.trim().toLowerCase();
            if (!rulesByShareClassName.containsKey(normalizedRuleName)) {
                rulesByShareClassName.put(normalizedRuleName, new List<RuleDefinition>());
            }
            rulesByShareClassName.get(normalizedRuleName).add(rule);
        }

        List<RuleCandidate> candidates = new List<RuleCandidate>();
        for (Country__c registration : eligibleRegistrations) {
            String shareClassName = registration.ShareClass__r.Name__c;
            String normalizedShareClassName = String.isBlank(shareClassName)
                ? null
                : shareClassName.trim().toLowerCase();

            List<RuleDefinition> matchingRules = rulesByShareClassName.get(normalizedShareClassName);
            if (matchingRules == null || matchingRules.isEmpty()) {
                continue;
            }
            if (matchingRules.size() > 1) {
                throw new MainShareClassException(
                    'Multiple active Main Share Class rules exist for Share Class Name ' + shareClassName + '.'
                );
            }

            RuleCandidate candidate = new RuleCandidate(registration, matchingRules[0]);
            System.debug(
                'CANDIDATE => Registration=' + candidate.Registration.Id
                + ' | ShareClassName=' + candidate.Registration.ShareClass__r.Name__c
                + ' | Rule=' + candidate.Rule.DeveloperName
                + ' | Priority=' + candidate.Rule.Priority
            );
            candidates.add(candidate);
        }

        return candidates;
    }

    // Rejects contradictory overrides and duplicate priorities among competing registrations.
    private static void validateCandidates(List<RuleCandidate> candidates, String scope, String legalForm) {
        Map<Decimal, String> priorityOwners = new Map<Decimal, String>();
        for (RuleCandidate candidate : candidates) {
            if (candidate == null || candidate.Rule == null) {
                throw new MainShareClassException('Invalid Main Share Class candidate: missing rule.');
            }

            RuleDefinition rule = candidate.Rule;
            if (rule.IsExcluded == true && rule.IsForceMain == true) {
                throw new MainShareClassException('A Main Share Class rule cannot be both Excluded and ForceMain: ' + rule.DeveloperName + '.');
            }
            if (rule.Priority == null) {
                throw new MainShareClassException('Priority is required for Main Share Class rule ' + rule.DeveloperName + '.');
            }

            if (priorityOwners.containsKey(rule.Priority)) {
                throw new MainShareClassException(
                    'Duplicate Main Share Class priority ' + String.valueOf(rule.Priority)
                    + ' for scope ' + scope + ' and legal form ' + legalForm + '.'
                );
            }
            priorityOwners.put(rule.Priority, rule.DeveloperName);
        }
    }

    // Returns the most recently modified ForceMain rule and rejects an exact timestamp tie.
    private static RuleCandidate selectForcedCandidate(
        List<RuleCandidate> candidates,
        String scope,
        String legalForm
    ) {
        RuleCandidate selectedCandidate;
        Long selectedTimestamp;
        for (RuleCandidate candidate : candidates) {
            if (candidate.Rule.IsExcluded == true || candidate.Rule.IsForceMain != true) {
                continue;
            }

            Long candidateTimestamp = candidate.Rule.ModifiedAt == null ? 0 : candidate.Rule.ModifiedAt.getTime();
            if (selectedCandidate == null || candidateTimestamp > selectedTimestamp) {
                selectedCandidate = candidate;
                selectedTimestamp = candidateTimestamp;
            } else if (candidateTimestamp == selectedTimestamp) {
                throw new MainShareClassException(
                    'Multiple ForceMain rules were modified at the same time for scope '
                    + scope + ' and legal form ' + legalForm + '.'
                );
            }
        }

        return selectedCandidate;
    }

    // Selects the non-excluded candidate with the lowest configured priority.
    private static Id selectPriorityCandidate(List<RuleCandidate> candidates) {
        RuleCandidate selectedCandidate;
        for (RuleCandidate candidate : candidates) {
            if (candidate.Rule.IsExcluded == true) {
                continue;
            }

            if (selectedCandidate == null || candidate.Rule.Priority < selectedCandidate.Rule.Priority) {
                selectedCandidate = candidate;
            }
        }

        return selectedCandidate == null ? null : selectedCandidate.Registration.Id;
    }

    // Queries every registration from the impacted Fund and Country combinations.
    private static List<Country__c> queryRegistrations(Set<Id> fundIds, Set<String> countryCodes) {
        if (fundIds.isEmpty() || countryCodes.isEmpty()) {
            return new List<Country__c>();
        }

        return [
            SELECT Id, Country__c, RegistrationStatus__c, ShareClass__c, IsMainShareClass__c,
                   ShareClass__r.Name__c, ShareClass__r.Fund__c, ShareClass__r.Fund__r.LegalForm__c
            FROM Country__c
            WHERE  ShareClass__r.Fund__c IN :fundIds
            AND Country__c IN :countryCodes
        ];
    }

    // Groups queried registrations only into the exact Product + Country keys requested.
    private static Map<String, List<Country__c>> groupRegistrations(
        List<Country__c> registrations,
        Set<String> requestedGroupKeys
    ) {
        Map<String, List<Country__c>> registrationsByGroup = new Map<String, List<Country__c>>();
        for (Country__c registration : registrations) {
            String groupKey = buildGroupKey(registration.ShareClass__r.Fund__c, registration.Country__c);
            if (!requestedGroupKeys.contains(groupKey)) {
                continue;
            }

            if (!registrationsByGroup.containsKey(groupKey)) {
                registrationsByGroup.put(groupKey, new List<Country__c>());
            }
            registrationsByGroup.get(groupKey).add(registration);
        }

        return registrationsByGroup;
    }

    // Collects Share Class identifiers from Country records.
    private static Set<Id> collectShareClassIds(List<Country__c> registrations) {
        Set<Id> shareClassIds = new Set<Id>();
        for (Country__c registration : registrations) {
            if (registration != null && registration.ShareClass__c != null) {
                shareClassIds.add(registration.ShareClass__c);
            }
        }

        return shareClassIds;
    }

    // Builds Product + Country keys from the registrations and their related Share Classes.
    private static Set<String> collectGroupKeys(
        List<Country__c> registrations,
        Map<Id, Share_Class__c> shareClasses
    ) {
        Set<String> groupKeys = new Set<String>();
        for (Country__c registration : registrations) {
            if (registration == null || String.isBlank(registration.Country__c)) {
                continue;
            }

            Share_Class__c shareClassRecord = shareClasses.get(registration.ShareClass__c);
            if (shareClassRecord != null && shareClassRecord.Fund__c != null) {
                groupKeys.add(buildGroupKey(shareClassRecord.Fund__c, registration.Country__c));
            }
        }

        return groupKeys;
    }

    // Extracts all Fund identifiers contained in the composite group keys.
    private static Set<Id> collectFundIds(Set<String> groupKeys) {
        Set<Id> fundIds = new Set<Id>();
        for (String groupKey : groupKeys) {
            List<String> keyParts = groupKey.split('\\|');
            if (keyParts.size() == 2) {
                fundIds.add((Id) keyParts[0]);
            }
        }
        return fundIds;
    }

    // Extracts all country codes contained in the composite group keys.
    private static Set<String> collectCountryCodes(Set<String> groupKeys) {
        Set<String> countryCodes = new Set<String>();
        for (String groupKey : groupKeys) {
            List<String> keyParts = groupKey.split('\\|');
            if (keyParts.size() == 2) {
                countryCodes.add(keyParts[1]);
            }
        }
        return countryCodes;
    }

    // Detects Country Registration changes that can alter the Main Share Class selection.
    private static Boolean hasRelevantCountryChange(Country__c newRegistration, Country__c oldRegistration) {
        return oldRegistration == null
            || newRegistration.Country__c != oldRegistration.Country__c
            || newRegistration.ShareClass__c != oldRegistration.ShareClass__c
            || newRegistration.RegistrationStatus__c != oldRegistration.RegistrationStatus__c;
    }

    // Detects Share Class changes used directly by the Main Share Class rules or grouping.
    private static Boolean hasRelevantShareClassChange(Share_Class__c newShareClass, Share_Class__c oldShareClass) {
        return oldShareClass == null
            || newShareClass.Fund__c != oldShareClass.Fund__c
            || newShareClass.Name__c != oldShareClass.Name__c;
    }

    // Builds a stable key for one Product + Country calculation group.
    private static String buildGroupKey(Id fundId, String countryCode) {
        return String.valueOf(fundId) + GroupKeySeparator + countryCode;
    }

    // Builds the Custom Metadata context key used to select the appropriate rule set.
    private static String buildContextKey(String scope, String legalForm) {
        return scope + GroupKeySeparator + legalForm;
    }
}