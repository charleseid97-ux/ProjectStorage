public with sharing class EngagementMeetingSignalBatch
    implements Database.Batchable<SObject>, Database.Stateful{

    private static final String SOURCE_TYPE = 'MEETING_PRODUCT_INTEREST';
    private final String runId;
    private final Set<Id> missingContactIds = new Set<Id>();
    private final Set<Id> missingStrategyIds = new Set<Id>();

    /**
     * Creates a Meeting source batch with a generated reconciliation run id.
     */
    public EngagementMeetingSignalBatch() {
        this(EngagementSignalRefreshService.createRunId());
    }

    /**
     * Creates a Meeting source batch sharing the supplied full refresh run id.
     */
    public EngagementMeetingSignalBatch(String runId) {
        this.runId = runId;
    }

    /**
     * Selects recent Events linked to a Meeting Note using the actual Event date.
     */
    public Database.QueryLocator start(Database.BatchableContext context) {
        EngagementSignalRule__mdt rule = EngagementScoringRuleService.getSignalRule(SOURCE_TYPE);
        Integer lookbackDays = rule == null || rule.LookbackDays__c == null
            ? 180
            : rule.LookbackDays__c.intValue();
        Datetime cutoff = System.now().addDays(-lookbackDays);
        return Database.getQueryLocator([
            SELECT Id,
                   StartDateTime,
                   Meeting_Note__c
            FROM Event
            WHERE StartDateTime >= :cutoff
            AND Meeting_Note__c != null
        ]);
    }

    /**
     * Creates one signal per Event x Contact x Strategy for Valuable Client Interests.
     */
    public void execute(Database.BatchableContext context, List<Event> scope) {
        Set<Id> eventIds = new Set<Id>();
        Set<Id> meetingNoteIds = new Set<Id>();
        for (Event eventRecord : scope) {
            eventIds.add(eventRecord.Id);
            meetingNoteIds.add(eventRecord.Meeting_Note__c);
        }

        Map<Id, Set<Id>> contactsByEvent = loadContactsByEvent(eventIds);
        Map<Id, List<ClientInterest__c>> interestsByMeetingNote = loadInterestsByMeetingNote(
            meetingNoteIds
        );

        List<Engagement_Signal__c> signals = new List<Engagement_Signal__c>();
        for (Event eventRecord : scope) {
            Set<Id> contactIds = contactsByEvent.get(eventRecord.Id);
            List<ClientInterest__c> interests = interestsByMeetingNote.get(
                eventRecord.Meeting_Note__c
            );

            if (contactIds == null || contactIds.isEmpty()) {
                missingContactIds.add(eventRecord.Id);
                continue;
            }
            if (interests == null || interests.isEmpty()) {
                continue;
            }

            addMeetingSignals(eventRecord, contactIds, interests, signals);
        }

        EngagementSignalService.upsertSignals(signals);
    }

    /**
     * Logs unresolved source ids and reconciles Meeting signals not seen in this full run.
     */
    public void finish(Database.BatchableContext context) {
        EngagementSignalBatchLogService.logResolutionIssues(
            context.getJobId(),
            SOURCE_TYPE,
            'Event',
            missingContactIds,
            'ClientInterest__c',
            missingStrategyIds,
            'EngagementMeetingSignalBatch'
        );
        if (EngagementSignalRefreshService.isBatchSuccessful(context.getJobId())) {
            Database.executeBatch(new EngagementSignalReconciliationBatch(SOURCE_TYPE, runId), 200);
        }
    }

    /**
     * Loads Contact relations for the Event records in the current scope.
     */
    private static Map<Id, Set<Id>> loadContactsByEvent(Set<Id> eventIds) {
        Map<Id, Set<Id>> contactsByEvent = new Map<Id, Set<Id>>();
        if (eventIds.isEmpty()) {
            return contactsByEvent;
        }

        for (EventRelation relation : [
            SELECT EventId,
                   RelationId
            FROM EventRelation
            WHERE EventId IN :eventIds
            AND RelationId IN (SELECT Id FROM Contact)
        ]) {
            if (!contactsByEvent.containsKey(relation.EventId)) {
                contactsByEvent.put(relation.EventId, new Set<Id>());
            }
            contactsByEvent.get(relation.EventId).add(relation.RelationId);
        }

        return contactsByEvent;
    }

    /**
     * Loads Valuable Client Interests, including missing Strategies for end-of-batch logging.
     */
    private static Map<Id, List<ClientInterest__c>> loadInterestsByMeetingNote(
        Set<Id> meetingNoteIds
    ) {
        Map<Id, List<ClientInterest__c>> interestsByMeetingNote = new Map<Id, List<ClientInterest__c>>();
        if (meetingNoteIds.isEmpty()) {
            return interestsByMeetingNote;
        }

        EngagementSignalRule__mdt rule = EngagementScoringRuleService.getSignalRule(SOURCE_TYPE);
        Decimal minInterest = rule == null ? 4 : rule.MinInterest__c;
        for (ClientInterest__c clientInterest : [
            SELECT Id,
                   MeetingNote__c,
                   Strategy__c,
                   Interest__c
            FROM ClientInterest__c
            WHERE MeetingNote__c IN :meetingNoteIds
            AND Interest__c >= :minInterest
        ]) {
            if (!interestsByMeetingNote.containsKey(clientInterest.MeetingNote__c)) {
                interestsByMeetingNote.put(
                    clientInterest.MeetingNote__c,
                    new List<ClientInterest__c>()
                );
            }
            interestsByMeetingNote.get(clientInterest.MeetingNote__c).add(clientInterest);
        }

        return interestsByMeetingNote;
    }

    /**
     * Builds all Contact x Strategy signals for one Event and tracks missing Strategy ids.
     */
    private void addMeetingSignals(
        Event eventRecord,
        Set<Id> contactIds,
        List<ClientInterest__c> interests,
        List<Engagement_Signal__c> signals
    ) {
        for (ClientInterest__c clientInterest : interests) {
            if (clientInterest.Strategy__c == null) {
                missingStrategyIds.add(clientInterest.Id);
                continue;
            }

            for (Id contactId : contactIds) {
                Engagement_Signal__c signal = EngagementSignalService.buildSignal(
                    contactId,
                    clientInterest.Strategy__c,
                    'Event',
                    eventRecord.Id,
                    SOURCE_TYPE,
                    eventRecord.StartDateTime,
                    clientInterest.Interest__c,
                    false,
                    runId
                );
                if (signal != null) {
                    signals.add(signal);
                }
            }
        }
    }
}
