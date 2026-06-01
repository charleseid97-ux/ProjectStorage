public without sharing class EventApprovalInboxController {

    private static final String SPEAKER_PROCESS_DEVELOPER_NAME = 'SpeakerApproval';
    private static final String ORGANIZER_PROCESS_DEVELOPER_NAME = 'OrganizerApprovalProcess';

    public class ApprovalRow {
        @AuraEnabled public String workItemId;
        @AuraEnabled public Id eventId;
        @AuraEnabled public String eventName;
        @AuraEnabled public String speakerName;
        @AuraEnabled public String type;
        @AuraEnabled public String format;
        @AuraEnabled public Date eventDate;
        @AuraEnabled public String salesTeam;
        @AuraEnabled public String organizer;
        @AuraEnabled public String speakers;
        @AuraEnabled public String assignedTo;
        @AuraEnabled public String assignmentType;
        @AuraEnabled public String status;
        @AuraEnabled public String processName;
        @AuraEnabled public String processDeveloperName;
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> loadApprovals() {

        Map<String, Object> result = new Map<String, Object>();

        List<ApprovalRow> eventRows = new List<ApprovalRow>();
        List<ApprovalRow> speakerRows = new List<ApprovalRow>();
        List<ApprovalRow> organizerRows = new List<ApprovalRow>();

        Id me = UserInfo.getUserId();

        Boolean hasSpeakerApproverPermission =
            FeatureManagement.checkPermission('BooklySpeakerApprover');

        Boolean hasOrganizerApproverPermission =
            FeatureManagement.checkPermission('BooklyApproveAnyOrganizer');

        List<ProcessInstanceWorkitem> workItems = [
            SELECT Id,
                ActorId,
                ProcessInstance.TargetObjectId,
                ProcessInstance.ProcessDefinition.Name,
                ProcessInstance.ProcessDefinition.DeveloperName
            FROM ProcessInstanceWorkitem
        ];

        Set<Id> eventIds = new Set<Id>();
        Set<Id> esaIds = new Set<Id>();
        Set<Id> actorUserIds = new Set<Id>();
        Set<Id> actorGroupIds = new Set<Id>();

        // Analyse des workitems
        for (ProcessInstanceWorkitem wi : workItems) {

            if (wi.ActorId != null) {

                String actorPrefix = String.valueOf(wi.ActorId).substring(0, 3);

                if (actorPrefix == '005') {
                    actorUserIds.add(wi.ActorId);
                }

                if (actorPrefix == '00G') {
                    actorGroupIds.add(wi.ActorId);
                }
            }

            Id targetId = wi.ProcessInstance.TargetObjectId;

            try {

                if (targetId.getSObjectType() == Event__c.SObjectType) {
                    eventIds.add(targetId);
                }

                if (targetId.getSObjectType() == EventSpeakerApprovals__c.SObjectType) {
                    esaIds.add(targetId);
                }

            } catch (Exception ex) {
            }
        }

        Set<Id> myQueues = new Set<Id>();

        if (!actorGroupIds.isEmpty()) {

            for (GroupMember gm : [
                SELECT GroupId
                FROM GroupMember
                WHERE GroupId IN :actorGroupIds
                AND UserOrGroupId = :me
            ]) {
                myQueues.add(gm.GroupId);
            }
        }

        Map<Id, String> userNames = new Map<Id, String>();

        if (!actorUserIds.isEmpty()) {

            for (User u : [
                SELECT Id, Name
                FROM User
                WHERE Id IN :actorUserIds
            ]) {
                userNames.put(u.Id, u.Name);
            }
        }

        Map<Id, Event__c> eventsById = new Map<Id, Event__c>();

        if (!eventIds.isEmpty()) {

            eventsById = new Map<Id, Event__c>([
                SELECT Id,
                    Name,
                    category__c,
                    Format__c,
                    startDate__c,
                    Speakers__c,
                    Organizer__r.Name,
                    SalesTeam__c
                FROM Event__c
                WHERE Id IN :eventIds
            ]);
        }

        Map<Id, EventSpeakerApprovals__c> esasById =
            new Map<Id, EventSpeakerApprovals__c>();

        if (!esaIds.isEmpty()) {

            esasById = new Map<Id, EventSpeakerApprovals__c>([
                SELECT Id,
                    Speaker__r.Name,
                    Event__c,
                    Event__r.Name,
                    Event__r.category__c,
                    Event__r.Format__c,
                    Event__r.startDate__c,
                    Event__r.Speakers__c,
                    Event__r.Organizer__r.Name,
                    Event__r.SalesTeam__c
                FROM EventSpeakerApprovals__c
                WHERE Id IN :esaIds
            ]);
        }

        // Construction des lignes
        for (ProcessInstanceWorkitem wi : workItems) {

            Id targetId = wi.ProcessInstance.TargetObjectId;
            String processDeveloperName =
                wi.ProcessInstance.ProcessDefinition.DeveloperName;

            ApprovalRow row = new ApprovalRow();

            row.workItemId = wi.Id;
            row.status = 'Pending';
            row.processName = wi.ProcessInstance.ProcessDefinition.Name;
            row.processDeveloperName = processDeveloperName;

            if (wi.ActorId == me) {

                row.assignmentType = 'ME';
                row.assignedTo = userNames.get(wi.ActorId);

            } else if (myQueues.contains(wi.ActorId)) {

                row.assignmentType = 'QUEUE';
                row.assignedTo = 'Queue';

            } else {

                Boolean isSpeakerApproval =
                    targetId.getSObjectType() == EventSpeakerApprovals__c.SObjectType;

                Boolean isOrganizerApproval =
                    targetId.getSObjectType() == Event__c.SObjectType;

                Boolean canApproveOtherSpeaker =
                    hasSpeakerApproverPermission &&
                    isSpeakerApproval &&
                    processDeveloperName == SPEAKER_PROCESS_DEVELOPER_NAME;

                Boolean canApproveOtherOrganizer =
                    hasOrganizerApproverPermission &&
                    isOrganizerApproval &&
                    processDeveloperName == ORGANIZER_PROCESS_DEVELOPER_NAME;

                if (canApproveOtherSpeaker || canApproveOtherOrganizer) {

                    row.assignmentType = 'OTHER';

                    if (wi.ActorId != null && userNames.containsKey(wi.ActorId)) {
                        row.assignedTo = userNames.get(wi.ActorId);
                    } else {
                        row.assignedTo = String.valueOf(wi.ActorId);
                    }

                } else {
                    continue;
                }
            }

            if (eventsById.containsKey(targetId)) {

                Event__c evt = eventsById.get(targetId);

                row.eventId = evt.Id;
                row.eventName = evt.Name;
                row.type = evt.category__c;
                row.format = evt.Format__c;
                row.eventDate = evt.startDate__c;
                row.speakers = evt.Speakers__c;
                row.organizer = evt.Organizer__r != null
                    ? evt.Organizer__r.Name
                    : null;
                row.salesTeam = evt.SalesTeam__c;

                if (
                    row.assignmentType == 'OTHER' &&
                    row.processDeveloperName == ORGANIZER_PROCESS_DEVELOPER_NAME
                ) {
                    organizerRows.add(row);
                } else {
                    eventRows.add(row);
                }
            }

            if (esasById.containsKey(targetId)) {

                EventSpeakerApprovals__c esa = esasById.get(targetId);

                row.eventId = esa.Event__c;
                row.eventName = esa.Event__r.Name;
                row.speakerName = esa.Speaker__r != null
                    ? esa.Speaker__r.Name
                    : null;
                row.type = esa.Event__r.category__c;
                row.format = esa.Event__r.Format__c;
                row.eventDate = esa.Event__r.startDate__c;
                row.speakers = esa.Event__r.Speakers__c;
                row.organizer = esa.Event__r.Organizer__r != null
                    ? esa.Event__r.Organizer__r.Name
                    : null;
                row.salesTeam = esa.Event__r.SalesTeam__c;

                speakerRows.add(row);
            }
        }

        result.put('hasSpeakerApproverPermission', hasSpeakerApproverPermission);
        result.put('hasOrganizerApproverPermission', hasOrganizerApproverPermission);
        result.put('eventRows', eventRows);
        result.put('speakerRows', speakerRows);
        result.put('organizerRows', organizerRows);

        return result;
    }

    @AuraEnabled
    public static void bulkApprove(List<Id> workItemIds) {

        if (workItemIds == null || workItemIds.isEmpty()) {
            return;
        }

        Id me = UserInfo.getUserId();

        Boolean hasSpeakerApproverPermission =
            FeatureManagement.checkPermission('BooklySpeakerApprover');

        Boolean hasOrganizerApproverPermission =
            FeatureManagement.checkPermission('BooklyApproveAnyOrganizer');

        List<ProcessInstanceWorkitem> workItems = [
            SELECT Id,
                ActorId,
                ProcessInstance.TargetObjectId,
                ProcessInstance.ProcessDefinition.DeveloperName
            FROM ProcessInstanceWorkitem
            WHERE Id IN :workItemIds
        ];

        for (ProcessInstanceWorkitem wi : workItems) {

            Id targetId = wi.ProcessInstance.TargetObjectId;
            String processDeveloperName =
                wi.ProcessInstance.ProcessDefinition.DeveloperName;

            Boolean isAssignedToMe = wi.ActorId == me;

            Boolean isAssignedToQueue =
                wi.ActorId != null &&
                String.valueOf(wi.ActorId).startsWith('00G');

            Boolean canApproveOtherSpeaker =
                hasSpeakerApproverPermission &&
                targetId.getSObjectType() == EventSpeakerApprovals__c.SObjectType &&
                processDeveloperName == SPEAKER_PROCESS_DEVELOPER_NAME;

            Boolean canApproveOtherOrganizer =
                hasOrganizerApproverPermission &&
                targetId.getSObjectType() == Event__c.SObjectType &&
                processDeveloperName == ORGANIZER_PROCESS_DEVELOPER_NAME;

            if (
                !isAssignedToMe &&
                !isAssignedToQueue &&
                !canApproveOtherSpeaker &&
                !canApproveOtherOrganizer
            ) {
                continue;
            }

            Approval.ProcessWorkitemRequest req =
                new Approval.ProcessWorkitemRequest();

            req.setWorkitemId(wi.Id);
            req.setAction('Approve');
            req.setComments('Bulk approved');

            if (isAssignedToQueue) {
                req.setNextApproverIds(new Id[] { me });
            }

            Approval.process(req);
        }
    }
}