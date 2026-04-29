public with sharing class CountryHandler {
  

    private static final String COUNTRY_IT = 'IT';
    private static final String TYPE_TRANSPARENCY = 'Transparency';
    private static final String STATUS_YES = 'Yes';
    private static final String STATUS_NO = 'No';
    private static final String SOURCE_MANUAL = 'Manual';

    private static final Set<String> VALID_REGISTRATION_STATUSES =
        new Set<String>{'REG', 'INSTITUTIONAL_ONLY'};

    public static void syncItalianTaxData(List<Country__c> newList, Map<Id, Country__c> oldMap) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        Map<Id, Country__c> toActivateByShareClass = new Map<Id, Country__c>();
        Set<Id> toDeactivateShareClassIds = new Set<Id>();

        for (Country__c c : newList) {
            if (c == null || c.ShareClass__c == null || c.Country__c != COUNTRY_IT) {
                continue;
            }

            Boolean isNowEligible = VALID_REGISTRATION_STATUSES.contains(c.RegistrationStatus__c);

            // Insert
            if (oldMap == null || !oldMap.containsKey(c.Id)) {
                if (isNowEligible) {
                    toActivateByShareClass.put(c.ShareClass__c, c);
                }
                continue;
            }

            // Update
            Country__c oldC = oldMap.get(c.Id);
            if (oldC == null) {
                continue;
            }

            Boolean wasEligible = VALID_REGISTRATION_STATUSES.contains(oldC.RegistrationStatus__c);

            if (!wasEligible && isNowEligible) {
                // Became eligible
                toActivateByShareClass.put(c.ShareClass__c, c);
            } else if (wasEligible && !isNowEligible) {
                // No longer eligible
                toDeactivateShareClassIds.add(c.ShareClass__c);
            } else if (isNowEligible && c.RegistrationDate__c != oldC.RegistrationDate__c) {
                // Still eligible but date changed -> keep/update StartDate on existing active TaxData if needed
                toActivateByShareClass.put(c.ShareClass__c, c);
            }
        }

        Set<Id> allShareClassIds = new Set<Id>();
        allShareClassIds.addAll(toActivateByShareClass.keySet());
        allShareClassIds.addAll(toDeactivateShareClassIds);

        if (allShareClassIds.isEmpty()) {
            return;
        }

        Map<Id, Share_Class__c> shareClassMap = new Map<Id, Share_Class__c>([
            SELECT Id, Fund__c
            FROM Share_Class__c
            WHERE Id IN :allShareClassIds
        ]);

        List<TaxData__c> existingTaxData = [
            SELECT Id, ShareClass__c, Country__c, Type__c, Status__c, StartDate__c, EndDate__c, Source__c
            FROM TaxData__c
            WHERE ShareClass__c IN :allShareClassIds
              AND Country__c = :COUNTRY_IT
              AND Type__c = :TYPE_TRANSPARENCY
        ];

        Map<Id, TaxData__c> taxByShareClassId = new Map<Id, TaxData__c>();
        for (TaxData__c td : existingTaxData) {
            // One expected record per ShareClass / IT / Transparency
            if (!taxByShareClassId.containsKey(td.ShareClass__c)) {
                taxByShareClassId.put(td.ShareClass__c, td);
            }
        }

        List<TaxData__c> toInsert = new List<TaxData__c>();
        List<TaxData__c> toUpdate = new List<TaxData__c>();

        // Activation / creation
        for (Id shareClassId : toActivateByShareClass.keySet()) {
            Country__c countryRecord = toActivateByShareClass.get(shareClassId);
            TaxData__c existing = taxByShareClassId.get(shareClassId);

            if (existing == null) {
                Share_Class__c sc = shareClassMap.get(shareClassId);
                if (sc == null) {
                    continue;
                }

                TaxData__c td = new TaxData__c();
                td.ShareClass__c = shareClassId;
                td.Product__c = sc.Fund__c;
                td.Country__c = COUNTRY_IT;
                td.Type__c = TYPE_TRANSPARENCY;
                td.Status__c = STATUS_YES;
                td.Source__c = SOURCE_MANUAL;
                td.StartDate__c = countryRecord.RegistrationDate__c;
                td.EndDate__c = null;

                toInsert.add(td);
            } else {
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

                if (changed) {
                    toUpdate.add(existing);
                }
            }
        }

        // Deactivation
        for (Id shareClassId : toDeactivateShareClassIds) {
            TaxData__c existing = taxByShareClassId.get(shareClassId);
            if (existing == null) {
                continue;
            }

            Boolean changed = false;

            if (existing.Status__c != STATUS_NO) {
                existing.Status__c = STATUS_NO;
                changed = true;
            }

            if (existing.EndDate__c != Date.today()) {
                existing.EndDate__c = Date.today();
                changed = true;
            }

            if (changed) {
                toUpdate.add(existing);
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

}