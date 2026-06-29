/** ──────────────────────────────────────
 * @description AuraEnabled controller for the Custom Approval Inbox LWC.
 *              Returns pending approval items the current user can act on.
 *              Supports Custom approval steps (CustomApprovalStep__c) and/or
 *              Standard Salesforce approvals (ProcessInstanceWorkitem), with
 *              optional filtering by target object type.
 *              Display fields per item are driven by ApprovalProcessConfig__mdt.InboxDisplayFields__c
 *              (one field path per line), resolved with a single upfront describe pass.
 * @author Charles EID
 * @testClass CustomApprovalInboxControllerTest
 * @coverage 90%   [26-06-26]
 ────────────────────────────────────── */
public without sharing class CustomApprovalInboxController {

    // ─── Entry point ─────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static List<ItemToApprove> getItemsToApprove(String objectApiName, String approvalSystem, String queueDevNames) {
        if (testItemsToApproveOverride != null) return testItemsToApproveOverride;
        Id currentUserId = UserInfo.getUserId();
        Boolean isAdmin  = CustomApprovalHistoryUtility.isAdministrator(currentUserId);
        Set<String> setObjectApiNames = parseObjectApiNames(objectApiName);
        Map<Id, String> queueNamesById = resolveQueuesByDevName(parseQueueDevNames(queueDevNames));

        List<ItemToApprove> result = new List<ItemToApprove>();
        if (String.isBlank(approvalSystem) || approvalSystem == 'Custom') {
            result.addAll(getCustomItems(currentUserId, isAdmin, setObjectApiNames, queueNamesById));
        }
        if (String.isBlank(approvalSystem) || approvalSystem == 'Standard') {
            result.addAll(getStandardItems(currentUserId, isAdmin, setObjectApiNames, queueNamesById));
        }
        return result;
    }

    private static Set<String> parseObjectApiNames(String objectApiName) {
        Set<String> setObjectApiNames = new Set<String>();
        if (String.isNotBlank(objectApiName)) {
            for(String obj : objectApiName.split(',')) {
                setObjectApiNames.add(obj.trim());
            }
        }
        return setObjectApiNames;
    }

    private static Set<String> parseQueueDevNames(String raw) {
        Set<String> devNames = new Set<String>();
        if (String.isBlank(raw)) return devNames;
        for (String s : raw.split(',')) {
            String trimmed = s.trim();
            if (String.isNotBlank(trimmed)) devNames.add(trimmed);
        }
        return devNames;
    }

    private static Map<Id, String> resolveQueuesByDevName(Set<String> devNames) {
        Map<Id, String> result = new Map<Id, String>();
        if (devNames.isEmpty()) return result;
        for (Group g : [SELECT Id, Name FROM Group WHERE Type = 'Queue' AND DeveloperName IN :devNames]) {
            result.put(g.Id, g.Name);
        }
        return result;
    }

    // ─── Custom approval items ────────────────────────────────────────────────────
    private static List<ItemToApprove> getCustomItems(Id currentUserId, Boolean isAdmin, Set<String> setObjectApiNames, Map<Id, String> queueNamesById) {
        List<CustomApprovalStep__c> allPending = queryPendingSteps();
        List<CustomApprovalStep__c> approvable = resolveApprovableSteps(allPending, currentUserId, isAdmin, queueNamesById);
        if (approvable.isEmpty()) return new List<ItemToApprove>();

        Set<String> processDevNames = collectProcessDevNames(approvable);
        Map<String, ApprovalProcessConfig__mdt> configByDevName = queryMdtConfigsByDevName(processDevNames);

        // Filter by object type using MDT ObjectType__c — no Id casting needed
        if (!setObjectApiNames.isEmpty()) {
            List<CustomApprovalStep__c> filtered = new List<CustomApprovalStep__c>();
            for (CustomApprovalStep__c s : approvable) {
                String procName = s.CustomApproval__r?.ProcessDeveloperName__c;
                if (setObjectApiNames.contains(configByDevName.get(procName)?.ObjectType__c)) filtered.add(s);
            }
            approvable = filtered;
            if (approvable.isEmpty()) return new List<ItemToApprove>();
        }

        Map<String, Boolean> stepDevNameHasUserInput = CustomApprovalHistoryUtility.buildStepConfigMap(processDevNames);
        Map<Id, String> submittedByPerApproval = buildSubmittedByMap(collectApprovalIds(approvable));

        // Build object-level describe cache once per unique type — before any loops or field traversal
        Map<String, SObjectInfo> sobjectInfoCache = buildSObjectInfoCache(collectObjectTypes(configByDevName.values()));

        // Field describe cache — built upfront (CustomReportMatrixController pattern)
        Map<String, DescribeFieldResult> fieldDescribeCache = new Map<String, DescribeFieldResult>();
        primeDescribeCache(configByDevName.values(), fieldDescribeCache, sobjectInfoCache);

        Map<Id, List<DisplayFieldEntry>> displayFieldsByStep = resolveCustomDisplayFields(approvable, configByDevName, fieldDescribeCache, sobjectInfoCache);

        return buildCustomResult(approvable, stepDevNameHasUserInput, submittedByPerApproval, configByDevName, displayFieldsByStep, sobjectInfoCache, queueNamesById);
    }

    // ─── Standard approval items ──────────────────────────────────────────────────
    private static List<ItemToApprove> getStandardItems(Id currentUserId, Boolean isAdmin, Set<String> setObjectApiNames, Map<Id, String> queueNamesById) {
        List<ProcessInstanceWorkitem> workitems = resolveVisibleWorkitems(setObjectApiNames, currentUserId, isAdmin, queueNamesById);
        if (workitems.isEmpty()) return new List<ItemToApprove>();

        // Describe each unique SObjectType exactly once — getSObjectType() (prefix lookup) is cheap; getDescribe() is not
        Map<SObjectType, SObjectInfo> sotInfoCache = buildSObjectInfoCacheFromWorkitems(workitems);
        Map<String, SObjectInfo> sobjectInfoCache = new Map<String, SObjectInfo>();
        for (SObjectInfo info : sotInfoCache.values()) sobjectInfoCache.put(info.apiName, info);

        Map<String, Set<Id>> targetIdsByObjType = new Map<String, Set<Id>>();
        Map<Id, String> objTypeByWorkitemId = new Map<Id, String>();
        groupWorkitemsByObjType(workitems, setObjectApiNames, sotInfoCache, targetIdsByObjType, objTypeByWorkitemId);
        if (targetIdsByObjType.isEmpty()) return new List<ItemToApprove>();

        Map<String, ApprovalProcessConfig__mdt> configByObjType = queryMdtConfigsByObjType(targetIdsByObjType.keySet());
        Map<String, String> labelFieldByObjType = buildLabelFieldByObjType(configByObjType);
        Map<String, DescribeFieldResult> fieldDescribeCache = new Map<String, DescribeFieldResult>();
        primeDescribeCache(configByObjType.values(), fieldDescribeCache, sobjectInfoCache);

        // Display paths (InboxDisplayFields__c only — for field entries)
        Map<String, List<String>> displayPathsByObjType = buildPathsByObjType(configByObjType);
        // Query paths: label field + display fields in one SOQL per object type (replaces resolveWorkitemTargetNames)
        Map<String, List<String>> queryPathsByObjType = buildExtendedPathsByObjType(targetIdsByObjType.keySet(), configByObjType, labelFieldByObjType);
        Map<Id, SObject> displayRecordsById = queryDisplayRecords(targetIdsByObjType, queryPathsByObjType);

        return buildStandardResult(workitems, sotInfoCache, objTypeByWorkitemId, labelFieldByObjType, displayPathsByObjType, displayRecordsById, fieldDescribeCache, sobjectInfoCache, queueNamesById);
    }

    private static List<ProcessInstanceWorkitem> queryPendingWorkitems(Set<String> setObjectApiNames) {
        if (testWorkitemsOverride != null) return testWorkitemsOverride;
        String piwQuery = 'SELECT Id, ActorId, CreatedDate, ProcessInstance.TargetObjectId, ProcessInstance.SubmittedBy.Name, ProcessInstance.LastModifiedBy.Name'+
                          ' FROM ProcessInstanceWorkitem'+
                          ' WHERE ProcessInstance.Status = \'Pending\'';
        piwQuery += !setObjectApiNames.isEmpty()? ' AND ProcessInstance.TargetObject.Type IN :setObjectApiNames' : '';
        piwQuery += ' ORDER BY CreatedDate ASC';
        return Database.query(piwQuery);
    }

    private static List<ProcessInstanceWorkitem> filterVisibleWorkitems(List<ProcessInstanceWorkitem> workitems, Id currentUserId) {
        Set<Id> queueIds = new Set<Id>();
        for (ProcessInstanceWorkitem wi : workitems) {
            if (wi.ActorId != null && String.valueOf(wi.ActorId).left(3) == '00G') queueIds.add(wi.ActorId);
        }
        Map<Id, List<Id>> membersByQueue = QueueMemberService.resolveMembers(queueIds);

        List<ProcessInstanceWorkitem> visible = new List<ProcessInstanceWorkitem>();
        for (ProcessInstanceWorkitem wi : workitems) {
            if (wi.ActorId == null) continue;
            String prefix = String.valueOf(wi.ActorId).left(3);
            if (prefix == '005' && wi.ActorId == currentUserId) {
                visible.add(wi);
            } else if (prefix == '00G') {
                List<Id> members = membersByQueue.get(wi.ActorId);
                if (members != null && members.contains(currentUserId)) visible.add(wi);
            }
        }
        return visible;
    }

    private static void groupWorkitemsByObjType(List<ProcessInstanceWorkitem> workitems, Set<String> setObjectApiNames, Map<SObjectType, SObjectInfo> sotInfoCache, Map<String, Set<Id>> targetIdsByObjType, Map<Id, String> objTypeByWorkitemId) {
        for (ProcessInstanceWorkitem wi : workitems) {
            if (wi.ProcessInstance?.TargetObjectId == null) continue;
            Id targetId = wi.ProcessInstance.TargetObjectId;
            SObjectInfo info = sotInfoCache.get(targetId.getSObjectType());
            if (info == null) continue;
            String objType = info.apiName;
            if (!setObjectApiNames.isEmpty() && !setObjectApiNames.contains(objType)) continue;
            if (!targetIdsByObjType.containsKey(objType)) targetIdsByObjType.put(objType, new Set<Id>());
            targetIdsByObjType.get(objType).add(targetId);
            objTypeByWorkitemId.put(wi.Id, objType);
        }
    }

    private static List<ItemToApprove> buildStandardResult(List<ProcessInstanceWorkitem> workitems, Map<SObjectType, SObjectInfo> sotInfoCache, Map<Id, String> objTypeByWorkitemId, Map<String, String> labelFieldByObjType, Map<String, List<String>> displayPathsByObjType, Map<Id, SObject> displayRecordsById, Map<String, DescribeFieldResult> fieldDescribeCache, Map<String, SObjectInfo> sobjectInfoCache, Map<Id, String> queueNamesById) {
        List<ItemToApprove> result = new List<ItemToApprove>();
        for (ProcessInstanceWorkitem wi : workitems) {
            String objType = objTypeByWorkitemId.get(wi.Id);
            if (objType == null) continue;
            Id          targetId   = wi.ProcessInstance.TargetObjectId;
            SObjectInfo info       = sotInfoCache.get(targetId.getSObjectType());
            SObject     displayRec = displayRecordsById.get(targetId);
            String      labelField = labelFieldByObjType.containsKey(objType) ? labelFieldByObjType.get(objType) : 'Name';
            Object      nameRaw    = traversePath(displayRec, labelField.split('\\.'), 0);
            ItemToApprove item = new ItemToApprove();
            item.stepId                  = wi.Id;
            item.targetRecordId          = String.valueOf(targetId);
            item.targetRecordName        = nameRaw != null ? String.valueOf(nameRaw) : null;
            item.objectLabel             = info?.label;
            item.submittedByName         = wi.ProcessInstance?.SubmittedBy?.Name;
            item.previousApproverName    = wi.ProcessInstance?.LastModifiedBy?.Name;
            item.submissionDateFormatted = wi.CreatedDate != null ? wi.CreatedDate.format('dd/MM/yyyy HH:mm') : '';
            item.submissionDate          = wi.CreatedDate;
            item.isStandardApproval      = true;
            item.displayFields           = buildDisplayFieldEntries(targetId, displayPathsByObjType.get(objType), displayRecordsById, objType, fieldDescribeCache, sobjectInfoCache);
            if (wi.ActorId != null) item.assignedQueueName = queueNamesById.get(wi.ActorId);
            result.add(item);
        }
        return result;
    }

    // ─── Test injection points ────────────────────────────────────────────────────
    @TestVisible
    private static Map<String, ApprovalProcessConfig__mdt> testMdtConfigOverride;
    @TestVisible
    private static List<ProcessInstanceWorkitem> testWorkitemsOverride;
    @TestVisible
    private static List<ItemToApprove> testItemsToApproveOverride;

    // ─── Query helpers ────────────────────────────────────────────────────────────
    private static List<CustomApprovalStep__c> queryPendingSteps() {
        return [SELECT Id, StepLabel__c, StepDeveloperName__c, AssignedTo__c, AssignedToName__c, CreatedDate, PreviousApprover__r.Name,
                       CustomApproval__c, CustomApproval__r.TargetRecordId__c, CustomApproval__r.RelatedToLabel__c, CustomApproval__r.ProcessDeveloperName__c,
                       CustomApproval__r.SubmittedBy__r.Name, CustomApproval__r.TECH_ReadOnly__c, CustomApproval__r.CreatedDate
                FROM   CustomApprovalStep__c
                WHERE  IsCurrentStep__c = true
                  AND  Status__c = 'Pending'
                ORDER BY CustomApproval__r.CreatedDate ASC];
    }

    private static Map<String, ApprovalProcessConfig__mdt> queryMdtConfigsByDevName(Set<String> devNames) {
        if (testMdtConfigOverride != null) return testMdtConfigOverride;
        Map<String, ApprovalProcessConfig__mdt> result = new Map<String, ApprovalProcessConfig__mdt>();
        for (ApprovalProcessConfig__mdt cfg : [SELECT DeveloperName, ObjectType__c, InboxDisplayFields__c
                                               FROM ApprovalProcessConfig__mdt
                                               WHERE  DeveloperName IN :devNames]) {
            result.put(cfg.DeveloperName, cfg);
        }
        return result;
    }

    private static Map<String, ApprovalProcessConfig__mdt> queryMdtConfigsByObjType(Set<String> objTypes) {
        Map<String, ApprovalProcessConfig__mdt> result = new Map<String, ApprovalProcessConfig__mdt>();
        for (ApprovalProcessConfig__mdt cfg : [SELECT DeveloperName, ObjectType__c, InboxDisplayFields__c, TargetLabelFieldApiName__c
                                               FROM ApprovalProcessConfig__mdt
                                               WHERE ObjectType__c IN :objTypes
                                               ORDER BY QualifiedApiName ASC]) {
            if (!result.containsKey(cfg.ObjectType__c)) result.put(cfg.ObjectType__c, cfg);
        }
        return result;
    }

    @TestVisible
    private static Map<String, String> buildLabelFieldByObjType(Map<String, ApprovalProcessConfig__mdt> configByObjType) {
        Map<String, String> result = new Map<String, String>();
        for (String objType : configByObjType.keySet()) {
            ApprovalProcessConfig__mdt cfg = configByObjType.get(objType);
            result.put(objType, String.isNotBlank(cfg.TargetLabelFieldApiName__c) ? cfg.TargetLabelFieldApiName__c : 'Name');
        }
        return result;
    }

    @TestVisible
    private static Map<String, List<String>> buildExtendedPathsByObjType(Set<String> allObjTypes, Map<String, ApprovalProcessConfig__mdt> configByObjType, Map<String, String> labelFieldByObjType) {
        Map<String, List<String>> result = new Map<String, List<String>>();
        for (String objType : allObjTypes) {
            Set<String> pathSet = new Set<String>();
            pathSet.add(labelFieldByObjType.containsKey(objType) ? labelFieldByObjType.get(objType) : 'Name');
            ApprovalProcessConfig__mdt cfg = configByObjType.get(objType);
            if (cfg != null && String.isNotBlank(cfg.InboxDisplayFields__c)) {
                pathSet.addAll(parseFieldPaths(cfg.InboxDisplayFields__c));
            }
            result.put(objType, new List<String>(pathSet));
        }
        return result;
    }

    private static Map<Id, String> buildSubmittedByMap(Set<Id> approvalIds) {
        Map<Id, String> result = new Map<Id, String>();
        for (CustomApprovalStep__c s : [SELECT CustomApproval__c, ActualApprover__r.Name
                                        FROM CustomApprovalStep__c
                                        WHERE CustomApproval__c IN :approvalIds
                                          AND Status__c = 'Approved'
                                        ORDER BY ActionDate__c DESC NULLS LAST]) {
            if (!result.containsKey(s.CustomApproval__c)) result.put(s.CustomApproval__c, s.ActualApprover__r?.Name);
        }
        return result;
    }

    // ─── Approvable step / workitem resolution ────────────────────────────────────
    private static List<CustomApprovalStep__c> resolveApprovableSteps(List<CustomApprovalStep__c> allPending, Id currentUserId, Boolean isAdmin, Map<Id, String> queueNamesById) {
        if (!queueNamesById.isEmpty()) {
            List<CustomApprovalStep__c> approvable = new List<CustomApprovalStep__c>();
            for (CustomApprovalStep__c s : allPending) {
                if (s.CustomApproval__r?.TECH_ReadOnly__c == true) continue;
                if (String.isNotBlank(s.AssignedTo__c) && s.AssignedTo__c.startsWith('00G')) {
                    try { if (queueNamesById.containsKey((Id) s.AssignedTo__c)) approvable.add(s); } catch (Exception e) { /* skip malformed Id */ }
                }
            }
            return approvable;
        }
        Map<Id, List<Id>> resolvedQueueMembers = resolveQueueMemberships(allPending);
        return filterToApprovable(allPending, isAdmin, currentUserId, resolvedQueueMembers);
    }

    private static List<ProcessInstanceWorkitem> resolveVisibleWorkitems(Set<String> setObjectApiNames, Id currentUserId, Boolean isAdmin, Map<Id, String> queueNamesById) {
        List<ProcessInstanceWorkitem> workitems = queryPendingWorkitems(setObjectApiNames);
        if (workitems.isEmpty()) return workitems;
        if (!queueNamesById.isEmpty()) {
            List<ProcessInstanceWorkitem> filtered = new List<ProcessInstanceWorkitem>();
            for (ProcessInstanceWorkitem wi : workitems) {
                if (wi.ActorId != null && queueNamesById.containsKey(wi.ActorId)) filtered.add(wi);
            }
            return filtered;
        }
        if (!isAdmin) return filterVisibleWorkitems(workitems, currentUserId);
        return workitems;
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

    private static Set<String> collectObjectTypes(List<ApprovalProcessConfig__mdt> configs) {
        Set<String> types = new Set<String>();
        for (ApprovalProcessConfig__mdt cfg : configs) {
            if (String.isNotBlank(cfg.ObjectType__c)) types.add(cfg.ObjectType__c);
        }
        return types;
    }

    // ─── SObject describe cache ───────────────────────────────────────────────────
    // For custom items: object types known from MDT — one getGlobalDescribe() call, one describe per type
    private static Map<String, SObjectInfo> buildSObjectInfoCache(Set<String> apiNames) {
        Map<String, SObjectInfo> cache = new Map<String, SObjectInfo>();
        if (apiNames.isEmpty()) return cache;
        Map<String, SObjectType> gd = Schema.getGlobalDescribe();
        for (String apiName : apiNames) {
            SObjectType sot = gd.get(apiName);
            if (sot != null) cache.put(apiName, new SObjectInfo(sot));
        }
        return cache;
    }

    // For standard items: object types derived from Id prefix (cheap) — describe called once per unique SObjectType
    private static Map<SObjectType, SObjectInfo> buildSObjectInfoCacheFromWorkitems(List<ProcessInstanceWorkitem> workitems) {
        Map<SObjectType, SObjectInfo> cache = new Map<SObjectType, SObjectInfo>();
        for (ProcessInstanceWorkitem wi : workitems) {
            if (wi.ProcessInstance?.TargetObjectId == null) continue;
            SObjectType sot = wi.ProcessInstance.TargetObjectId.getSObjectType();
            if (!cache.containsKey(sot)) cache.put(sot, new SObjectInfo(sot));
        }
        return cache;
    }

    // ─── Field describe cache (CustomReportMatrixController pattern) ──────────────
    private static void primeDescribeCache(List<ApprovalProcessConfig__mdt> configs, Map<String, DescribeFieldResult> fieldCache, Map<String, SObjectInfo> sobjectInfoCache) {
        for (ApprovalProcessConfig__mdt cfg : configs) {
            if (String.isBlank(cfg.ObjectType__c) || String.isBlank(cfg.InboxDisplayFields__c)) continue;
            for (String path : parseFieldPaths(cfg.InboxDisplayFields__c)) {
                resolveFieldDescribe(cfg.ObjectType__c, path, fieldCache, sobjectInfoCache);
            }
        }
    }

    private static DescribeFieldResult resolveFieldDescribe(String objectName, String fieldPath, Map<String, DescribeFieldResult> fieldCache, Map<String, SObjectInfo> sobjectInfoCache) {
        String key = objectName + ':' + fieldPath;
        if (fieldCache.containsKey(key)) return fieldCache.get(key);
        DescribeFieldResult dfr = resolveFieldDescribeUncached(objectName, fieldPath, sobjectInfoCache);
        fieldCache.put(key, dfr);
        return dfr;
    }

    private static DescribeFieldResult resolveFieldDescribeUncached(String objectName, String fieldPath, Map<String, SObjectInfo> sobjectInfoCache) {
        try {
            List<String> segments = fieldPath.split('\\.');
            // Use pre-built sobjectInfoCache to avoid Schema.getGlobalDescribe() per-path
            SObjectInfo currentInfo = sobjectInfoCache.get(objectName);
            if (currentInfo == null) {
                SObjectType sot = Schema.getGlobalDescribe().get(objectName);
                if (sot == null) return null;
                currentInfo = new SObjectInfo(sot);
                sobjectInfoCache.put(objectName, currentInfo);
            }
            for (Integer i = 0; i < segments.size(); i++) {
                if (currentInfo == null) return null;
                String segment = segments[i];
                if (i == segments.size() - 1) {
                    SObjectField field = currentInfo.fieldMap.get(segment);
                    return field?.getDescribe();
                }
                String lookupApiName = segment.endsWith('__r') ? segment.removeEnd('__r') + '__c' : segment + 'Id';
                SObjectField lookupField = currentInfo.fieldMap.get(lookupApiName);
                if (lookupField == null) return null;
                List<SObjectType> refs = lookupField.getDescribe().getReferenceTo();
                if (refs.isEmpty()) return null;
                // Describe the related type once and cache it — subsequent field paths through the same type reuse it
                currentInfo = new SObjectInfo(refs[0]);
                sobjectInfoCache.put(currentInfo.apiName, currentInfo);
            }
            return null;
        } catch (Exception e) {
            return null;
        }
    }

    private static String getFieldLabel(String objectName, String fieldPath, Map<String, DescribeFieldResult> fieldCache, Map<String, SObjectInfo> sobjectInfoCache) {
        DescribeFieldResult dfr = resolveFieldDescribe(objectName, fieldPath, fieldCache, sobjectInfoCache);
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

    private static List<DisplayFieldEntry> buildDisplayFieldEntries(Id targetId, List<String> paths, Map<Id, SObject> recordsById, String objType, Map<String, DescribeFieldResult> fieldCache, Map<String, SObjectInfo> sobjectInfoCache) {
        List<DisplayFieldEntry> entries = new List<DisplayFieldEntry>();
        if (paths == null || paths.isEmpty()) return entries;
        SObject rec = recordsById.get(targetId);
        for (String path : paths) {
            Object raw = traversePath(rec, path.split('\\.'), 0);
            entries.add(new DisplayFieldEntry(getFieldLabel(objType, path, fieldCache, sobjectInfoCache), raw != null ? String.valueOf(raw) : ''));
        }
        return entries;
    }

    // ─── Custom display fields resolution ─────────────────────────────────────────
    private static Map<Id, List<DisplayFieldEntry>> resolveCustomDisplayFields(List<CustomApprovalStep__c> approvable, Map<String, ApprovalProcessConfig__mdt> configByDevName, Map<String, DescribeFieldResult> fieldCache, Map<String, SObjectInfo> sobjectInfoCache) {
        Map<String, Set<String>> fieldPathSetByObjType = new Map<String, Set<String>>();
        Map<String, Set<Id>> targetIdsByObjType = new Map<String, Set<Id>>();
        Map<String, List<String>> parsedPathsByProc = new Map<String, List<String>>();

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

        Map<Id, SObject> recordsById = queryDisplayRecords(targetIdsByObjType, buildListPathsByObjType(fieldPathSetByObjType));

        Map<Id, List<DisplayFieldEntry>> result = new Map<Id, List<DisplayFieldEntry>>();
        for (CustomApprovalStep__c s : approvable) {
            String procName = s.CustomApproval__r?.ProcessDeveloperName__c;
            String rawId    = s.CustomApproval__r?.TargetRecordId__c;
            String objType  = configByDevName.get(procName)?.ObjectType__c;
            List<String> paths = parsedPathsByProc.get(procName);
            List<DisplayFieldEntry> entries = new List<DisplayFieldEntry>();
            if (paths != null && !paths.isEmpty() && String.isNotBlank(rawId) && String.isNotBlank(objType)) {
                try {
                    entries = buildDisplayFieldEntries((Id) rawId, paths, recordsById, objType, fieldCache, sobjectInfoCache);
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

    // ─── Result builders ──────────────────────────────────────────────────────────
    private static List<ItemToApprove> buildCustomResult(List<CustomApprovalStep__c> approvable, Map<String, Boolean> stepDevNameHasUserInput, Map<Id, String> submittedByPerApproval, Map<String, ApprovalProcessConfig__mdt> configByDevName, Map<Id, List<DisplayFieldEntry>> displayFieldsByStep, Map<String, SObjectInfo> sobjectInfoCache, Map<Id, String> queueNamesById) {
        List<ItemToApprove> result = new List<ItemToApprove>();
        for (CustomApprovalStep__c s : approvable) {
            result.add(buildCustomItem(s, stepDevNameHasUserInput, submittedByPerApproval, configByDevName, displayFieldsByStep, sobjectInfoCache, queueNamesById));
        }
        return result;
    }

    private static ItemToApprove buildCustomItem(CustomApprovalStep__c s, Map<String, Boolean> stepDevNameHasUserInput, Map<Id, String> submittedByPerApproval, Map<String, ApprovalProcessConfig__mdt> configByDevName, Map<Id, List<DisplayFieldEntry>> displayFieldsByStep, Map<String, SObjectInfo> sobjectInfoCache, Map<Id, String> queueNamesById) {
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
            SObjectInfo info = sobjectInfoCache.get(objType);
            item.objectLabel = info != null ? info.label : objType;
        } else if (String.isNotBlank(rawId)) {
            try { item.objectLabel = ((Id) rawId).getSObjectType().getDescribe().getLabel(); } catch (Exception e) { /* skip malformed Id */ }
        }

        item.submittedByName         = submittedByPerApproval.containsKey(s.CustomApproval__c) ? submittedByPerApproval.get(s.CustomApproval__c) : s.CustomApproval__r?.SubmittedBy__r?.Name;
        item.assignedToName          = s.AssignedToName__c;
        item.stepDateFormatted       = s.CreatedDate != null ? s.CreatedDate.format('dd/MM/yyyy HH:mm') : '';
        item.previousApproverName    = s.PreviousApprover__r?.Name;
        item.submissionDateFormatted = s.CustomApproval__r?.CreatedDate != null ? s.CustomApproval__r.CreatedDate.format('dd/MM/yyyy HH:mm') : '';
        item.submissionDate          = s.CustomApproval__r?.CreatedDate;
        item.displayFields           = displayFieldsByStep.get(s.Id);
        if (String.isNotBlank(s.AssignedTo__c) && s.AssignedTo__c.startsWith('00G')) {
            try { item.assignedQueueName = queueNamesById.get((Id) s.AssignedTo__c); } catch (Exception e) { /* skip malformed Id */ }
        }
        return item;
    }

    // ─── Inner classes ────────────────────────────────────────────────────────────
    private class SObjectInfo {
        String label;
        String apiName;
        Map<String, SObjectField> fieldMap;
        SObjectInfo(SObjectType sot) {
            DescribeSObjectResult dsr = sot.getDescribe();
            this.label    = dsr.getLabel();
            this.apiName  = dsr.getName();
            this.fieldMap = dsr.fields.getMap();
        }
    }

    public class DisplayFieldEntry {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public DisplayFieldEntry(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class ItemToApprove {
        @AuraEnabled public String stepId;
        @AuraEnabled public String targetRecordId;
        @AuraEnabled public String targetRecordName;
        @AuraEnabled public String objectLabel;
        @AuraEnabled public String submittedByName;
        @AuraEnabled public String nextApproverSource;
        @AuraEnabled public String stepLabel;
        @AuraEnabled public String assignedToName;
        @AuraEnabled public String stepDateFormatted;
        @AuraEnabled public String previousApproverName;
        @AuraEnabled public String submissionDateFormatted;
        @AuraEnabled public DateTime submissionDate;
        @AuraEnabled public Boolean isStandardApproval;
        @AuraEnabled public List<DisplayFieldEntry> displayFields;
        @AuraEnabled public String assignedQueueName;
    }
}