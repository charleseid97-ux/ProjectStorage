/** ──────────────────────────────────────
 * @description AuraEnabled controller for the Custom Approval Inbox LWC.
 *              Returns pending approval items the current user can act on.
 *              Supports Custom approval steps (CustomApprovalStep__c) and/or
 *              Standard Salesforce approvals (ProcessInstanceWorkitem), with
 *              optional filtering by target object type.
 *              Display fields per item are driven by ApprovalProcessConfig__mdt.InboxDisplayFields__c
 *              (one field path per line), resolved with a single upfront describe pass.
 * @author Charles EID
 ────────────────────────────────────── */
public without sharing class CustomApprovalInboxController {

    // ─── Entry point ─────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static List<ItemToApprove> getItemsToApprove(String objectApiName, String approvalSystem) {
        Id currentUserId = UserInfo.getUserId();
        Boolean isAdmin  = CustomApprovalHistoryUtility.isAdministrator(currentUserId);

        List<ItemToApprove> result = new List<ItemToApprove>();

        if (String.isBlank(approvalSystem) || approvalSystem == 'Custom') {
            result.addAll(getCustomItems(currentUserId, isAdmin, objectApiName));
        }
        if (String.isBlank(approvalSystem) || approvalSystem == 'Standard') {
            result.addAll(getStandardItems(currentUserId, objectApiName));
        }
        return result;
    }

    // ─── Custom approval items ────────────────────────────────────────────────────
    private static List<ItemToApprove> getCustomItems(Id currentUserId, Boolean isAdmin, String objectApiName) {
        List<CustomApprovalStep__c> allPending = queryPendingSteps();
        Map<Id, List<Id>> resolvedQueueMembers = resolveQueueMemberships(allPending);
        List<CustomApprovalStep__c> approvable = filterToApprovable(allPending, isAdmin, currentUserId, resolvedQueueMembers);
        if (approvable.isEmpty()) return new List<ItemToApprove>();

        Set<String> processDevNames = collectProcessDevNames(approvable);
        Map<String, ApprovalProcessConfig__mdt> configByDevName = queryMdtConfigsByDevName(processDevNames);

        // Filter by object type using MDT ObjectType__c — no Id casting needed
        if (String.isNotBlank(objectApiName)) {
            List<CustomApprovalStep__c> filtered = new List<CustomApprovalStep__c>();
            for (CustomApprovalStep__c s : approvable) {
                String procName = s.CustomApproval__r?.ProcessDeveloperName__c;
                if (configByDevName.get(procName)?.ObjectType__c == objectApiName) filtered.add(s);
            }
            approvable = filtered;
            if (approvable.isEmpty()) return new List<ItemToApprove>();
        }

        Map<String, Boolean> stepDevNameHasUserInput = CustomApprovalHistoryUtility.buildStepConfigMap(processDevNames);
        Map<Id, String>      submittedByPerApproval  = buildSubmittedByMap(collectApprovalIds(approvable));

        // Describe cache — built upfront before any data query (CustomReportMatrixController pattern)
        Map<String, DescribeFieldResult> describeCache = new Map<String, DescribeFieldResult>();
        primeDescribeCache(configByDevName.values(), describeCache);

        Map<Id, List<DisplayFieldEntry>> displayFieldsByStep = resolveCustomDisplayFields(approvable, configByDevName, describeCache);

        return buildCustomResult(approvable, stepDevNameHasUserInput, submittedByPerApproval, configByDevName, displayFieldsByStep);
    }

    // ─── Standard approval items ──────────────────────────────────────────────────
    private static List<ItemToApprove> getStandardItems(Id currentUserId, String objectApiName) {
        List<ProcessInstanceWorkitem> workitems = [
            SELECT Id, CreatedDate,
                   ProcessInstance.TargetObjectId,
                   ProcessInstance.SubmittedBy.Name
            FROM   ProcessInstanceWorkitem
            WHERE  Actor.Id = :currentUserId
              AND  ProcessInstance.Status = 'Pending'
            ORDER BY CreatedDate ASC
        ];
        if (workitems.isEmpty()) return new List<ItemToApprove>();

        // Group by object type; optionally filter
        Map<String, Set<Id>> targetIdsByObjType = new Map<String, Set<Id>>();
        Map<Id, String>      objTypeByWorkitemId = new Map<Id, String>();
        for (ProcessInstanceWorkitem wi : workitems) {
            if (wi.ProcessInstance?.TargetObjectId == null) continue;
            Id targetId   = wi.ProcessInstance.TargetObjectId;
            String objType = targetId.getSObjectType().getDescribe().getName();
            if (String.isNotBlank(objectApiName) && objType != objectApiName) continue;
            if (!targetIdsByObjType.containsKey(objType)) targetIdsByObjType.put(objType, new Set<Id>());
            targetIdsByObjType.get(objType).add(targetId);
            objTypeByWorkitemId.put(wi.Id, objType);
        }
        if (targetIdsByObjType.isEmpty()) return new List<ItemToApprove>();

        // Resolve target record names — one SOQL per object type
        Map<Id, String> nameById = new Map<Id, String>();
        for (String objType : targetIdsByObjType.keySet()) {
            Set<Id> ids = targetIdsByObjType.get(objType);
            for (SObject rec : Database.query('SELECT Id, Name FROM ' + objType + ' WHERE Id IN :ids')) {
                nameById.put(rec.Id, (String) rec.get('Name'));
            }
        }

        // MDT display fields matched by ObjectType__c (first record per object type)
        Set<String> objTypes = targetIdsByObjType.keySet();
        Map<String, ApprovalProcessConfig__mdt> configByObjType = queryMdtConfigsByObjType(objTypes);

        // Describe cache — built upfront
        Map<String, DescribeFieldResult> describeCache = new Map<String, DescribeFieldResult>();
        primeDescribeCache(configByObjType.values(), describeCache);

        // Display field values — one SOQL per object type that has display fields
        Map<String, List<String>> pathsByObjType = buildPathsByObjType(configByObjType);
        Map<Id, SObject>          displayRecordsById = queryDisplayRecords(targetIdsByObjType, pathsByObjType);

        // Build items
        List<ItemToApprove> result = new List<ItemToApprove>();
        for (ProcessInstanceWorkitem wi : workitems) {
            String objType = objTypeByWorkitemId.get(wi.Id);
            if (objType == null) continue;

            Id     targetId = wi.ProcessInstance.TargetObjectId;
            ItemToApprove item = new ItemToApprove();
            item.stepId               = wi.Id;
            item.targetRecordId       = String.valueOf(targetId);
            item.targetRecordName     = nameById.get(targetId);
            item.objectLabel          = targetId.getSObjectType().getDescribe().getLabel();
            item.submittedByName      = wi.ProcessInstance?.SubmittedBy?.Name;
            item.submissionDateFormatted = wi.CreatedDate != null ? wi.CreatedDate.format('dd/MM/yyyy HH:mm') : '';
            item.isStandardApproval   = true;
            item.displayFields        = buildDisplayFieldEntries(targetId, pathsByObjType.get(objType), displayRecordsById, objType, describeCache);
            result.add(item);
        }
        return result;
    }

    // ─── Test injection point ─────────────────────────────────────────────────────
    @TestVisible
    private static Map<String, ApprovalProcessConfig__mdt> testMdtConfigOverride;

    // ─── Query helpers ────────────────────────────────────────────────────────────
    private static List<CustomApprovalStep__c> queryPendingSteps() {
        return [SELECT Id, StepLabel__c, StepDeveloperName__c, AssignedTo__c, AssignedToName__c, CreatedDate,
                       PreviousApprover__r.Name,
                       CustomApproval__c, CustomApproval__r.TargetRecordId__c, CustomApproval__r.RelatedToLabel__c,
                       CustomApproval__r.ProcessDeveloperName__c,
                       CustomApproval__r.SubmittedBy__r.Name, CustomApproval__r.TECH_ReadOnly__c, CustomApproval__r.CreatedDate
                FROM   CustomApprovalStep__c
                WHERE  IsCurrentStep__c = true
                  AND  Status__c = 'Pending'
                ORDER BY CustomApproval__r.CreatedDate ASC];
    }

    private static Map<String, ApprovalProcessConfig__mdt> queryMdtConfigsByDevName(Set<String> devNames) {
        if (testMdtConfigOverride != null) return testMdtConfigOverride;
        Map<String, ApprovalProcessConfig__mdt> result = new Map<String, ApprovalProcessConfig__mdt>();
        for (ApprovalProcessConfig__mdt cfg : [
            SELECT DeveloperName, ObjectType__c, InboxDisplayFields__c
            FROM   ApprovalProcessConfig__mdt
            WHERE  DeveloperName IN :devNames
        ]) {
            result.put(cfg.DeveloperName, cfg);
        }
        return result;
    }

    private static Map<String, ApprovalProcessConfig__mdt> queryMdtConfigsByObjType(Set<String> objTypes) {
        Map<String, ApprovalProcessConfig__mdt> result = new Map<String, ApprovalProcessConfig__mdt>();
        for (ApprovalProcessConfig__mdt cfg : [
            SELECT DeveloperName, ObjectType__c, InboxDisplayFields__c
            FROM   ApprovalProcessConfig__mdt
            WHERE  ObjectType__c IN :objTypes
            ORDER BY QualifiedApiName ASC
        ]) {
            if (!result.containsKey(cfg.ObjectType__c)) result.put(cfg.ObjectType__c, cfg);
        }
        return result;
    }

    private static Map<Id, String> buildSubmittedByMap(Set<Id> approvalIds) {
        Map<Id, String> result = new Map<Id, String>();
        for (CustomApprovalStep__c s : [SELECT CustomApproval__c, ActualApprover__r.Name
                                        FROM   CustomApprovalStep__c
                                        WHERE  CustomApproval__c IN :approvalIds
                                          AND  Status__c         = 'Approved'
                                        ORDER BY ActionDate__c DESC NULLS LAST]) {
            if (!result.containsKey(s.CustomApproval__c)) result.put(s.CustomApproval__c, s.ActualApprover__r?.Name);
        }
        return result;
    }

    // ─── Queue resolution ─────────────────────────────────────────────────────────
    private static Map<Id, List<Id>> resolveQueueMemberships(List<CustomApprovalStep__c> steps) {
        Set<Id> queueIds = new Set<Id>();
        for (CustomApprovalStep__c s : steps) {
            if (String.isNotBlank(s.AssignedTo__c) && s.AssignedTo__c.startsWith('00G')) {
                queueIds.add((Id) s.AssignedTo__c);
            }
        }
        return QueueMemberService.resolveMembers(queueIds);
    }

    // ─── Permission filter ────────────────────────────────────────────────────────
    private static List<CustomApprovalStep__c> filterToApprovable(List<CustomApprovalStep__c> allPending, Boolean isAdmin, Id currentUserId, Map<Id, List<Id>> resolvedQueueMembers) {
        List<CustomApprovalStep__c> approvable = new List<CustomApprovalStep__c>();
        for (CustomApprovalStep__c s : allPending) {
            if (s.CustomApproval__r?.TECH_ReadOnly__c == true) continue;
            if (canUserApprove(s, isAdmin, currentUserId, resolvedQueueMembers)) approvable.add(s);
        }
        return approvable;
    }

    private static Boolean canUserApprove(CustomApprovalStep__c s, Boolean isAdmin, Id currentUserId, Map<Id, List<Id>> resolvedQueueMembers) {
        if (isAdmin) return true;
        if (String.isBlank(s.AssignedTo__c)) return false;
        Id assignedId = (Id) s.AssignedTo__c;
        String prefix = String.valueOf(assignedId).left(3);
        if (prefix == '005') return assignedId == currentUserId;
        if (prefix == '00G') {
            List<Id> members = resolvedQueueMembers.get(assignedId);
            return members != null && members.contains(currentUserId);
        }
        return false;
    }

    // ─── Collection helpers ───────────────────────────────────────────────────────
    private static Set<Id> collectApprovalIds(List<CustomApprovalStep__c> steps) {
        Set<Id> ids = new Set<Id>();
        for (CustomApprovalStep__c s : steps) ids.add(s.CustomApproval__c);
        return ids;
    }

    private static Set<String> collectProcessDevNames(List<CustomApprovalStep__c> steps) {
        Set<String> names = new Set<String>();
        for (CustomApprovalStep__c s : steps) {
            if (String.isNotBlank(s.CustomApproval__r?.ProcessDeveloperName__c)) names.add(s.CustomApproval__r.ProcessDeveloperName__c);
        }
        return names;
    }

    // ─── Describe cache helpers (CustomReportMatrixController pattern) ────────────
    private static void primeDescribeCache(List<ApprovalProcessConfig__mdt> configs, Map<String, DescribeFieldResult> cache) {
        for (ApprovalProcessConfig__mdt cfg : configs) {
            if (String.isBlank(cfg.ObjectType__c) || String.isBlank(cfg.InboxDisplayFields__c)) continue;
            for (String path : parseFieldPaths(cfg.InboxDisplayFields__c)) {
                resolveFieldDescribe(cfg.ObjectType__c, path, cache);
            }
        }
    }

    private static DescribeFieldResult resolveFieldDescribe(String objectName, String fieldPath, Map<String, DescribeFieldResult> cache) {
        String key = objectName + ':' + fieldPath;
        if (cache.containsKey(key)) return cache.get(key);
        DescribeFieldResult dfr = resolveFieldDescribeUncached(objectName, fieldPath);
        cache.put(key, dfr);
        return dfr;
    }

    private static DescribeFieldResult resolveFieldDescribeUncached(String objectName, String fieldPath) {
        try {
            List<String> segments = fieldPath.split('\\.');
            SObjectType currentType = Schema.getGlobalDescribe().get(objectName);
            for (Integer i = 0; i < segments.size(); i++) {
                if (currentType == null) return null;
                String segment = segments[i];
                Map<String, SObjectField> fieldMap = currentType.getDescribe().fields.getMap();
                if (i == segments.size() - 1) {
                    SObjectField field = fieldMap.get(segment);
                    return field?.getDescribe();
                }
                String lookupApiName = segment.endsWith('__r') ? segment.removeEnd('__r') + '__c' : segment + 'Id';
                SObjectField lookupField = fieldMap.get(lookupApiName);
                if (lookupField == null) return null;
                List<SObjectType> refs = lookupField.getDescribe().getReferenceTo();
                if (refs.isEmpty()) return null;
                currentType = refs[0];
            }
            return null;
        } catch (Exception e) {
            return null;
        }
    }

    private static String getFieldLabel(String objectName, String fieldPath, Map<String, DescribeFieldResult> cache) {
        DescribeFieldResult dfr = resolveFieldDescribe(objectName, fieldPath, cache);
        return dfr != null ? dfr.getLabel() : fieldPath;
    }

    // ─── Display field resolution ─────────────────────────────────────────────────
    private static List<String> parseFieldPaths(String raw) {
        List<String> paths = new List<String>();
        if (String.isBlank(raw)) return paths;
        for (String line : raw.split('\n')) {
            String trimmed = line.trim();
            if (String.isNotBlank(trimmed)) paths.add(trimmed);
        }
        return paths;
    }

    private static Map<String, List<String>> buildPathsByObjType(Map<String, ApprovalProcessConfig__mdt> configByObjType) {
        Map<String, List<String>> result = new Map<String, List<String>>();
        for (String objType : configByObjType.keySet()) {
            List<String> paths = parseFieldPaths(configByObjType.get(objType).InboxDisplayFields__c);
            if (!paths.isEmpty()) result.put(objType, paths);
        }
        return result;
    }

    private static Map<Id, SObject> queryDisplayRecords(Map<String, Set<Id>> targetIdsByObjType, Map<String, List<String>> pathsByObjType) {
        Map<Id, SObject> result = new Map<Id, SObject>();
        for (String objType : pathsByObjType.keySet()) {
            Set<Id> ids = targetIdsByObjType.get(objType);
            if (ids == null || ids.isEmpty()) continue;
            List<String> paths = pathsByObjType.get(objType);
            String soql = 'SELECT Id, ' + String.join(paths, ', ') + ' FROM ' + objType + ' WHERE Id IN :ids';
            for (SObject rec : Database.query(soql)) result.put(rec.Id, rec);
        }
        return result;
    }

    private static Object traversePath(SObject rec, String[] segs, Integer i) {
        if (rec == null) return null;
        if (i == segs.size() - 1) return rec.get(segs[i]);
        return traversePath(rec.getSObject(segs[i]), segs, i + 1);
    }

    private static List<DisplayFieldEntry> buildDisplayFieldEntries(Id targetId, List<String> paths, Map<Id, SObject> recordsById, String objType, Map<String, DescribeFieldResult> describeCache) {
        List<DisplayFieldEntry> entries = new List<DisplayFieldEntry>();
        if (paths == null || paths.isEmpty()) return entries;
        SObject rec = recordsById.get(targetId);
        for (String path : paths) {
            Object raw = traversePath(rec, path.split('\\.'), 0);
            entries.add(new DisplayFieldEntry(getFieldLabel(objType, path, describeCache), raw != null ? String.valueOf(raw) : ''));
        }
        return entries;
    }

    // ─── Custom display fields resolution ─────────────────────────────────────────
    private static Map<Id, List<DisplayFieldEntry>> resolveCustomDisplayFields(List<CustomApprovalStep__c> approvable, Map<String, ApprovalProcessConfig__mdt> configByDevName, Map<String, DescribeFieldResult> describeCache) {
        // Build: objectType → union of all field paths across processes of that type
        Map<String, Set<String>> fieldPathSetByObjType = new Map<String, Set<String>>();
        Map<String, Set<Id>>     targetIdsByObjType    = new Map<String, Set<Id>>();
        Map<String, List<String>> parsedPathsByProc    = new Map<String, List<String>>();

        for (String procName : configByDevName.keySet()) {
            ApprovalProcessConfig__mdt cfg = configByDevName.get(procName);
            List<String> paths = parseFieldPaths(cfg.InboxDisplayFields__c);
            parsedPathsByProc.put(procName, paths);
            if (paths.isEmpty() || String.isBlank(cfg.ObjectType__c)) continue;
            if (!fieldPathSetByObjType.containsKey(cfg.ObjectType__c)) fieldPathSetByObjType.put(cfg.ObjectType__c, new Set<String>());
            fieldPathSetByObjType.get(cfg.ObjectType__c).addAll(paths);
        }

        for (CustomApprovalStep__c s : approvable) {
            String procName = s.CustomApproval__r?.ProcessDeveloperName__c;
            String rawId    = s.CustomApproval__r?.TargetRecordId__c;
            String objType  = configByDevName.get(procName)?.ObjectType__c;
            if (String.isBlank(objType) || String.isBlank(rawId)) continue;
            if (!targetIdsByObjType.containsKey(objType)) targetIdsByObjType.put(objType, new Set<Id>());
            try { targetIdsByObjType.get(objType).add((Id) rawId); } catch (Exception e) { /* skip malformed Id */ }
        }

        // One SOQL per object type
        Map<Id, SObject> recordsById = queryDisplayRecords(targetIdsByObjType, buildListPathsByObjType(fieldPathSetByObjType));

        // Build per-step entries using each process's own ordered field list
        Map<Id, List<DisplayFieldEntry>> result = new Map<Id, List<DisplayFieldEntry>>();
        for (CustomApprovalStep__c s : approvable) {
            String procName = s.CustomApproval__r?.ProcessDeveloperName__c;
            String rawId    = s.CustomApproval__r?.TargetRecordId__c;
            String objType  = configByDevName.get(procName)?.ObjectType__c;
            List<String> paths = parsedPathsByProc.get(procName);
            List<DisplayFieldEntry> entries = new List<DisplayFieldEntry>();
            if (paths != null && !paths.isEmpty() && String.isNotBlank(rawId) && String.isNotBlank(objType)) {
                try {
                    entries = buildDisplayFieldEntries((Id) rawId, paths, recordsById, objType, describeCache);
                } catch (Exception e) { /* skip malformed Id */ }
            }
            result.put(s.Id, entries);
        }
        return result;
    }

    private static Map<String, List<String>> buildListPathsByObjType(Map<String, Set<String>> pathSetByObjType) {
        Map<String, List<String>> result = new Map<String, List<String>>();
        for (String objType : pathSetByObjType.keySet()) {
            Set<String> paths = pathSetByObjType.get(objType);
            if (!paths.isEmpty()) result.put(objType, new List<String>(paths));
        }
        return result;
    }

    // ─── Result builder ───────────────────────────────────────────────────────────
    private static List<ItemToApprove> buildCustomResult(List<CustomApprovalStep__c> approvable, Map<String, Boolean> stepDevNameHasUserInput, Map<Id, String> submittedByPerApproval, Map<String, ApprovalProcessConfig__mdt> configByDevName, Map<Id, List<DisplayFieldEntry>> displayFieldsByStep) {
        List<ItemToApprove> result = new List<ItemToApprove>();
        for (CustomApprovalStep__c s : approvable) {
            result.add(buildCustomItem(s, stepDevNameHasUserInput, submittedByPerApproval, configByDevName, displayFieldsByStep));
        }
        return result;
    }

    private static ItemToApprove buildCustomItem(CustomApprovalStep__c s, Map<String, Boolean> stepDevNameHasUserInput, Map<Id, String> submittedByPerApproval, Map<String, ApprovalProcessConfig__mdt> configByDevName, Map<Id, List<DisplayFieldEntry>> displayFieldsByStep) {
        ItemToApprove item = new ItemToApprove();
        item.stepId             = s.Id;
        item.stepLabel          = String.isNotBlank(s.StepLabel__c) ? s.StepLabel__c : s.StepDeveloperName__c;
        item.nextApproverSource = stepDevNameHasUserInput.get(s.StepDeveloperName__c) == true ? 'UserInput' : null;
        item.isStandardApproval = false;

        String rawId    = s.CustomApproval__r?.TargetRecordId__c;
        String procName = s.CustomApproval__r?.ProcessDeveloperName__c;
        item.targetRecordId   = rawId;
        item.targetRecordName = String.isNotBlank(s.CustomApproval__r?.RelatedToLabel__c) ? s.CustomApproval__r.RelatedToLabel__c : 'View Record';

        String objType = configByDevName.get(procName)?.ObjectType__c;
        if (String.isNotBlank(objType)) {
            SObjectType sot = Schema.getGlobalDescribe().get(objType);
            item.objectLabel = sot != null ? sot.getDescribe().getLabel() : objType;
        } else if (String.isNotBlank(rawId)) {
            try { item.objectLabel = ((Id) rawId).getSObjectType().getDescribe().getLabel(); } catch (Exception e) { /* skip malformed Id */ }
        }

        item.submittedByName         = submittedByPerApproval.containsKey(s.CustomApproval__c) ? submittedByPerApproval.get(s.CustomApproval__c) : s.CustomApproval__r?.SubmittedBy__r?.Name;
        item.assignedToName          = s.AssignedToName__c;
        item.stepDateFormatted       = s.CreatedDate != null ? s.CreatedDate.format('dd/MM/yyyy HH:mm') : '';
        item.previousApproverName    = s.PreviousApprover__r?.Name;
        item.submissionDateFormatted = s.CustomApproval__r?.CreatedDate != null ? s.CustomApproval__r.CreatedDate.format('dd/MM/yyyy HH:mm') : '';
        item.displayFields           = displayFieldsByStep.get(s.Id);
        return item;
    }

    // ─── Inner classes ────────────────────────────────────────────────────────────
    public class DisplayFieldEntry {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public DisplayFieldEntry(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class ItemToApprove {
        @AuraEnabled public String  stepId;
        @AuraEnabled public String  targetRecordId;
        @AuraEnabled public String  targetRecordName;
        @AuraEnabled public String  objectLabel;
        @AuraEnabled public String  submittedByName;
        @AuraEnabled public String  nextApproverSource;
        @AuraEnabled public String  stepLabel;
        @AuraEnabled public String  assignedToName;
        @AuraEnabled public String  stepDateFormatted;
        @AuraEnabled public String  previousApproverName;
        @AuraEnabled public String  submissionDateFormatted;
        @AuraEnabled public Boolean isStandardApproval;
        @AuraEnabled public List<DisplayFieldEntry> displayFields;
    }
}
