/** ──────────────────────────────────────
 * @description Recipient resolver for the Legal Pending Approvals reminder.
 *              Groups overdue items by business region and returns one EmailBundle per region,
 *                  each with the regional AD group email added to ccAddresses.
 *              Registered in ApprovalsReminder__mdt.RecipientResolverClass__c for the
 *                  LegalPendingApprovals record.
 *              Items with no mapped region (blank TECH_BusinessRegion__c or unrecognised object type)
 *                  are collected in a catch-all bundle with no CC — the base Legal_Queue toAddresses
 *                  merged in by ApprovalsReminderBatch still cover these items.
 * @author Charles EID
 * @implements IApprovalsRecipientResolver
 ────────────────────────────────────── */
public with sharing class LegalApprovalsRecipientResolver implements IApprovalsRecipientResolver {

    public List<ApprovalsReminderBatch.EmailBundle> resolve(List<CustomApprovalInboxController.ItemToApprove> overdueItems) {

        // Step 1 — Build ID-prefix → SObjectType map for Grid and Convention (2 describes, O(1) per lookup)
        Schema.SObjectType gridType = Grid__c.sObjectType;
        Schema.SObjectType convType = Convention__c.sObjectType;
        Map<String, Schema.SObjectType> prefixMap = new Map<String, Schema.SObjectType>{
            gridType.getDescribe().getKeyPrefix() => gridType,
            convType.getDescribe().getKeyPrefix() => convType
        };

        // Step 2 — Collect record IDs by object type
        Set<Id> gridIds = new Set<Id>();
        Set<Id> convIds = new Set<Id>();
        for (CustomApprovalInboxController.ItemToApprove item : overdueItems) {
            if (String.isBlank(item.targetRecordId) || item.targetRecordId.length() < 3) continue;
            Schema.SObjectType t = prefixMap.get(item.targetRecordId.substring(0, 3));
            if (t == gridType)      gridIds.add((Id) item.targetRecordId);
            else if (t == convType) convIds.add((Id) item.targetRecordId);
        }

        // Step 3 — Query business region per record
        Map<String, String> regionByRecordId = new Map<String, String>();
        if (!gridIds.isEmpty()) {
            for (Grid__c g : [SELECT Id, TECH_BusinessRegion__c FROM Grid__c WHERE Id IN :gridIds]) {
                regionByRecordId.put(g.Id, g.TECH_BusinessRegion__c);
            }
        }
        if (!convIds.isEmpty()) {
            for (Convention__c c : [SELECT Id, TECH_Business_Region__c FROM Convention__c WHERE Id IN :convIds]) {
                regionByRecordId.put(c.Id, c.TECH_Business_Region__c);
            }
        }

        // Step 4 — Load MDT records that have an AD group email configured
        Map<String, Queue_Business_Region__mdt> mdtByRegion = new Map<String, Queue_Business_Region__mdt>();
        for (Queue_Business_Region__mdt mdt : [SELECT Business_region__c, ADGroupEmail__c FROM Queue_Business_Region__mdt WHERE ADGroupEmail__c != null]) {
            mdtByRegion.put(mdt.Business_region__c, mdt);
        }

        // Step 5 — Build one bundle per region; items with no region go to catch-all bundle (key '')
        Map<String, ApprovalsReminderBatch.EmailBundle> bundleByRegion = new Map<String, ApprovalsReminderBatch.EmailBundle>();
        for (CustomApprovalInboxController.ItemToApprove item : overdueItems) {
            String region = String.isNotBlank(item.targetRecordId) ? regionByRecordId.get(item.targetRecordId) : null;
            String bundleKey = String.isNotBlank(region) ? region : '';

            ApprovalsReminderBatch.EmailBundle bundle = bundleByRegion.get(bundleKey);
            if (bundle == null) {
                bundle = new ApprovalsReminderBatch.EmailBundle();
                bundleByRegion.put(bundleKey, bundle);
            }
            bundle.items.add(item);

            Queue_Business_Region__mdt mdt = String.isNotBlank(region) ? mdtByRegion.get(region) : null;
            if (mdt != null && String.isNotBlank(mdt.ADGroupEmail__c)) {
                bundle.ccAddresses.add(mdt.ADGroupEmail__c);
            }
        }

        return bundleByRegion.values();
    }
}