/** ──────────────────────────────────────
 * @description Trigger handler of Fund_Field_ApplicabilityHistory__c (FundFieldApplicabilityHistoryTrigger, before insert / update).
 *              Guardrails applied to every history line, whoever writes it (FieldHistoryLogger, Data Loader, upload):
 *                  - Applicability__c is true when the line's field is listed in Tracked_Fields__c of the Field_History_Config__mdt whose
 *                    LookupFieldAPIName__c is filled on the line, false otherwise.
 *                  - OpenPeriodKey__c (unique) = record Id + ':' + lowercase field API name while the line is an open period (Applicability__c true,
 *                    End_Date__c empty), empty otherwise: the database rejects a second open period for the same record and field (DUPLICATE_VALUE).
 *              Tracking a new object only needs its lookup field on Fund_Field_ApplicabilityHistory__c and its Field_History_Config__mdt record.
 * @author Charles EID
 * @testClass Test_FieldHistoryLogger
 * @coverage 100%   [29-10-26]
 * @lastModifiedBy Charles EID   [29-10-26]
 ────────────────────────────────────── */
public without sharing class FundFieldApplicabilityHistoryHandler {

    private static Map<String, Set<String>> trackedFieldsByLookup;

    public static void handleBeforeInsertUpdate(List<Fund_Field_ApplicabilityHistory__c> newList) {
        Map<String, Set<String>> trackedFieldsByLookup = getTrackedFieldsByLookup();
        for (Fund_Field_ApplicabilityHistory__c h : newList) {
            String fieldApiName = h.FieldAPIName__c?.toLowerCase();
            h.Applicability__c = false;
            h.OpenPeriodKey__c = null;
            for (String lookupField : trackedFieldsByLookup.keySet()) {
                Id recordId = (Id) h.get(lookupField);
                if (recordId == null || !trackedFieldsByLookup.get(lookupField).contains(fieldApiName)) continue;
                h.Applicability__c = true;
                if (h.End_Date__c == null) h.OpenPeriodKey__c = recordId + ':' + fieldApiName;
            }
        }
    }

    // Loaded once per transaction: reading a long text area makes this custom metadata query count toward the SOQL limit, and the trigger runs on every history DML of a Product / Share Class save. SOQL, not getAll(): getAll() cuts long text areas at 255 characters and the Share Class Tracked_Fields__c is longer
    private static Map<String, Set<String>> getTrackedFieldsByLookup() {
        if (trackedFieldsByLookup != null) return trackedFieldsByLookup;
        trackedFieldsByLookup = new Map<String, Set<String>>();
        for (Field_History_Config__mdt config : [SELECT LookupFieldAPIName__c, Tracked_Fields__c FROM Field_History_Config__mdt]) {
            if (String.isNotBlank(config.LookupFieldAPIName__c) && String.isNotBlank(config.Tracked_Fields__c)) trackedFieldsByLookup.put(config.LookupFieldAPIName__c, new Set<String>(config.Tracked_Fields__c.toLowerCase().split('\\s+')));
        }
        return trackedFieldsByLookup;
    }
}