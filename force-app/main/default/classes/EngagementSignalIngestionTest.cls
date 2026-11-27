/** ──────────────────────────────────────
 * @description Tests of the Engagement Signal ingestion, on one eligible record per source (thresholds read from
 *              EngagementSignalRule__mdt at runtime) plus records without Contact or Strategy (logged, no signal):
 *              the 14-day scheduled refresh (window applied, no reconciliation), the weekly full refresh (reconciliation
 *              of stale signals), idempotent re-execution, and strict FundName resolution (normalization, no fuzzy match,
 *              ambiguous Fund names).
 * @author Achraf El Hitary
 * @covers EngagementSignalRefreshService   100%   [25-11-26]
 * @covers EngagementWebsiteSignalBatch   100%   [25-11-26]
 * @covers EngagementNewsletterSignalBatch   96%   [25-11-26]
 * @covers EngagementSubscriptionSignalBatch   93%   [25-11-26]
 * @covers EngagementWebinarSignalBatch   97%   [25-11-26]
 * @covers EngagementMeetingSignalBatch   97%   [25-11-26]
 * @covers EngagementSignalReconciliationBatch   100%   [25-11-26]
 * @covers EngagementSignalService   100%   [25-11-26]
 * @covers EngagementSignalBatchLogService   100%   [25-11-26]
 * @covers EngagementFundStrategyResolver   96%   [25-11-26]
 * @covers EngagementScoringRuleService   98%   [25-11-26]
 * @lastModifiedBy Charles EID   [24-11-26]
 ────────────────────────────────────── */
@IsTest
private class EngagementSignalIngestionTest {

    private static final String SOURCE_WEB_VISIT = 'WEB_VISIT';
    private static final String SOURCE_NEWSLETTER_CLICK = 'NEWSLETTER_CLICK';
    private static final String SOURCE_PROSPACE_SUBSCRIPTION = 'PROSPACE_SUBSCRIPTION';
    private static final String SOURCE_WEBINAR_ATTENDANCE = 'WEBINAR_ATTENDANCE';
    private static final String SOURCE_MEETING_PRODUCT_INTEREST = 'MEETING_PRODUCT_INTEREST';

    private static final String OBJECT_INTERACTION_DETAIL = 'Digital_Interaction_Details__c';
    private static final String OBJECT_WEB_COMMUNICATION = 'Web_Communication__c';
    private static final String OBJECT_CAMPAIGN_MEMBER = 'CampaignMember';
    private static final String OBJECT_EVENT = 'Event';

    private static final Map<String, String> SOURCE_OBJECT_BY_TYPE = new Map<String, String>{
        SOURCE_WEB_VISIT => OBJECT_INTERACTION_DETAIL,
        SOURCE_NEWSLETTER_CLICK => OBJECT_INTERACTION_DETAIL,
        SOURCE_PROSPACE_SUBSCRIPTION => OBJECT_WEB_COMMUNICATION,
        SOURCE_WEBINAR_ATTENDANCE => OBJECT_CAMPAIGN_MEMBER,
        SOURCE_MEETING_PRODUCT_INTEREST => OBJECT_EVENT
    };

    private static final String ENGAGEMENT_TYPE_WEB = 'Web';
    private static final String ENGAGEMENT_TYPE_NEWSLETTER = 'Newsletter';
    private static final String ENGAGEMENT_TYPE_WEBINARS = 'Webinars';

    private static final String DETAIL_TYPE_VISIT = 'Visit';
    private static final String DETAIL_TYPE_OPEN = 'Open';
    private static final String DETAIL_TYPE_CLICK = 'Click';

    private static final String STRATEGY_NAME = 'Engagement Test Strategy';
    private static final String STRATEGY_NAME_OTHER = 'Engagement Other Strategy';
    private static final String STRATEGY_CODE = 'ENGTST';
    private static final String STRATEGY_CODE_OTHER = 'ENGTS2';
    private static final String ASSET_CLASS_EQUITY = 'Equity';
    private static final String SUB_ASSET_CLASS_GLOBAL = 'Global';

    private static final String FUND_CODE = 'ENGF1';
    private static final String FUND_CODE_WITHOUT_STRATEGY = 'ENGF2';
    private static final String FUND_CODE_AMBIGUOUS = 'ENGF3';
    private static final String FUND_CODE_AMBIGUOUS_OTHER = 'ENGF4';
    private static final String FUND_NAME = 'Engagement Test Fund';
    private static final String FUND_NAME_SPACED_UPPERCASE = '  ENGAGEMENT   TEST   FUND ';
    private static final String FUND_NAME_WITH_SUFFIX = 'Engagement Test Fund IE000TEST';
    private static final String FUND_NAME_WITHOUT_STRATEGY = 'Engagement Fund Without Strategy';
    private static final String FUND_NAME_AMBIGUOUS = 'Engagement Ambiguous Fund';
    private static final String FUND_NAME_UNKNOWN = 'Unknown Engagement Fund';
    private static final String BLANK = ' ';

    private static final String CONTACT_FIRST_NAME = 'Engagement';
    private static final String CONTACT_LAST_NAME = 'Signal';
    private static final String CONTACT_EMAIL = 'engagement.signal@test.invalid';
    private static final String CONTACT_PHONE = '0111111111';
    private static final String CONTACT_SOURCE = '-';
    private static final String CONTACT_WEBSITE_COUNTRY = 'FR';
    private static final String PROSPACE_STATUS_VALIDATED = 'Validated';

    private static final String WEBINAR_NAME = 'Engagement Webinar';
    private static final String WEBINAR_NAME_WITHOUT_STRATEGY = 'Engagement Webinar Without Strategy';
    private static final String EVENT_CATEGORY_CONFERENCE = 'Event conference';
    private static final String EVENT_CITY = 'Paris';
    private static final String EVENT_COUNTRY = 'France';
    private static final String EVENT_CLIENT_TYPE = 'End Investor';
    private static final String EVENT_CO_HOSTED_NO = 'No';
    private static final String EVENT_FORMAT_PHYSICAL = 'Physical';
    private static final String EVENT_SALES_TEAM = 'Belgium';
    private static final String CAMPAIGN_STATUS_LIVE = 'Live';

    private static final String RUN_ID_PREFIX = 'ENG-';
    private static final String RUN_ID_OLD = 'ENG-OLD';
    private static final String STALE_SIGNAL_KEY = 'ENG-TEST-STALE';

    private static final Decimal DEFAULT_MIN_TIME_SPENT = 300;
    private static final Decimal DEFAULT_MIN_ATTENDANCE_RATE = 100;
    private static final Decimal DEFAULT_MIN_INTEREST = 5;

    private static final Integer PARTIAL_WINDOW_DAYS = 14;
    private static final Integer OLD_INTERACTION_AGE_DAYS = 30;
    private static final Datetime INTERACTION_DATE = System.now().addDays(-1);

    @TestSetup
    static void makeData() {
        Strategy__c strategy = new Strategy__c(Name = STRATEGY_NAME, Code__c = STRATEGY_CODE, AssetClass__c = ASSET_CLASS_EQUITY, SubAssetClass__c = SUB_ASSET_CLASS_GLOBAL);
        Strategy__c otherStrategy = new Strategy__c(Name = STRATEGY_NAME_OTHER, Code__c = STRATEGY_CODE_OTHER, AssetClass__c = ASSET_CLASS_EQUITY, SubAssetClass__c = SUB_ASSET_CLASS_GLOBAL);
        insert new List<Strategy__c>{ strategy, otherStrategy };
        Product__c fund = buildFund(FUND_CODE, FUND_NAME, strategy.Id);
        Product__c fundWithoutStrategy = buildFund(FUND_CODE_WITHOUT_STRATEGY, FUND_NAME_WITHOUT_STRATEGY, null);
        insert new List<Product__c>{ fund, fundWithoutStrategy, buildFund(FUND_CODE_AMBIGUOUS, FUND_NAME_AMBIGUOUS, strategy.Id), buildFund(FUND_CODE_AMBIGUOUS_OTHER, FUND_NAME_AMBIGUOUS, otherStrategy.Id) };
        Contact contact = new Contact(FirstName = CONTACT_FIRST_NAME, LastName = CONTACT_LAST_NAME, Email = CONTACT_EMAIL, Phone = CONTACT_PHONE, Source__c = CONTACT_SOURCE, WebsiteCountry__c = CONTACT_WEBSITE_COUNTRY, Prospace_Status__c = PROSPACE_STATUS_VALIDATED);
        insert contact;

        Event__c webinarEvent = new Event__c(Name = WEBINAR_NAME, title__c = WEBINAR_NAME, category__c = EVENT_CATEGORY_CONFERENCE, City__c = EVENT_CITY, Country__c = EVENT_COUNTRY, clientType__c = EVENT_CLIENT_TYPE, Co_hosted__c = EVENT_CO_HOSTED_NO, format__c = EVENT_FORMAT_PHYSICAL, salesTeam__c = EVENT_SALES_TEAM, startDate__c = INTERACTION_DATE.date(), endDate__c = INTERACTION_DATE.date(), targetedAttendees__c = 1, noAutomations__c = true, bypasseApprovals__c = true, bypasseNotifications__c = true);
        Event__c eventWithoutStrategy = webinarEvent.clone();
        eventWithoutStrategy.Name = WEBINAR_NAME_WITHOUT_STRATEGY;
        insert new List<Event__c>{ webinarEvent, eventWithoutStrategy };
        insert new sessionSpeakerProduct__c(session__c = webinarEvent.Id, strategy__c = strategy.Id);
        Campaign webinar = new Campaign(Name = WEBINAR_NAME, Status = CAMPAIGN_STATUS_LIVE, Event__c = webinarEvent.Id, Start_Date_Time__c = INTERACTION_DATE);
        Campaign webinarWithoutStrategy = new Campaign(Name = WEBINAR_NAME_WITHOUT_STRATEGY, Status = CAMPAIGN_STATUS_LIVE, Event__c = eventWithoutStrategy.Id);
        insert new List<Campaign>{ webinar, webinarWithoutStrategy };
        Decimal minAttendanceRate = getRule(SOURCE_WEBINAR_ATTENDANCE)?.MinAttendanceRate__c ?? DEFAULT_MIN_ATTENDANCE_RATE;
        insert new List<CampaignMember>{ new CampaignMember(CampaignId = webinar.Id, ContactId = contact.Id, Attendance_rate__c = minAttendanceRate), new CampaignMember(CampaignId = webinarWithoutStrategy.Id, ContactId = contact.Id, Attendance_rate__c = minAttendanceRate) };

        Decimal ruleMinTimeSpent = getRule(SOURCE_WEB_VISIT)?.MinTimeSpentSeconds__c;
        Decimal minTimeSpent = ruleMinTimeSpent ?? DEFAULT_MIN_TIME_SPENT;
        Digital_Interaction__c web = buildInteraction(contact.Id, ENGAGEMENT_TYPE_WEB, null, minTimeSpent);
        Digital_Interaction__c webWithoutContact = buildInteraction(null, ENGAGEMENT_TYPE_WEB, null, minTimeSpent);
        Digital_Interaction__c newsletter = buildInteraction(contact.Id, ENGAGEMENT_TYPE_NEWSLETTER, null, null);
        Digital_Interaction__c newsletterWithoutContact = buildInteraction(null, ENGAGEMENT_TYPE_NEWSLETTER, null, null);
        Digital_Interaction__c newsletterWithoutOpen = buildInteraction(contact.Id, ENGAGEMENT_TYPE_NEWSLETTER, null, null);
        Digital_Interaction__c webinarInteraction = buildInteraction(contact.Id, ENGAGEMENT_TYPE_WEBINARS, webinar.Id, null);
        Digital_Interaction__c webinarWithoutStrategyInteraction = buildInteraction(contact.Id, ENGAGEMENT_TYPE_WEBINARS, webinarWithoutStrategy.Id, null);
        insert new List<Digital_Interaction__c>{ web, webWithoutContact, newsletter, newsletterWithoutContact, newsletterWithoutOpen, webinarInteraction, webinarWithoutStrategyInteraction };
        List<Digital_Interaction_Details__c> details = new List<Digital_Interaction_Details__c>{
            buildDetail(web.Id, DETAIL_TYPE_VISIT, INTERACTION_DATE, FUND_NAME, minTimeSpent),
            buildDetail(web.Id, DETAIL_TYPE_VISIT, INTERACTION_DATE, FUND_NAME_UNKNOWN, minTimeSpent),
            buildDetail(webWithoutContact.Id, DETAIL_TYPE_VISIT, INTERACTION_DATE, FUND_NAME, minTimeSpent),
            buildDetail(newsletter.Id, DETAIL_TYPE_OPEN, INTERACTION_DATE, null, null),
            buildDetail(newsletter.Id, DETAIL_TYPE_CLICK, INTERACTION_DATE, FUND_NAME, null),
            buildDetail(newsletter.Id, DETAIL_TYPE_CLICK, INTERACTION_DATE, FUND_NAME_UNKNOWN, null),
            buildDetail(newsletterWithoutContact.Id, DETAIL_TYPE_OPEN, INTERACTION_DATE, null, null),
            buildDetail(newsletterWithoutContact.Id, DETAIL_TYPE_CLICK, INTERACTION_DATE, FUND_NAME, null),
            buildDetail(newsletterWithoutOpen.Id, DETAIL_TYPE_CLICK, INTERACTION_DATE, FUND_NAME, null)
        };
        if (ruleMinTimeSpent != null) details.add(buildDetail(web.Id, DETAIL_TYPE_VISIT, INTERACTION_DATE, FUND_NAME, ruleMinTimeSpent - 1));
        insert details;

        insert new List<Web_Communication__c>{ buildSubscription(contact.Id, fund.Id), buildSubscription(null, fund.Id), buildSubscription(contact.Id, fundWithoutStrategy.Id) };

        Meeting_Note__c meetingNote = new Meeting_Note__c(Date__c = INTERACTION_DATE.date());
        Meeting_Note__c meetingNoteWithoutInterest = new Meeting_Note__c(Date__c = INTERACTION_DATE.date());
        insert new List<Meeting_Note__c>{ meetingNote, meetingNoteWithoutInterest };
        Event meeting = buildMeeting(meetingNote.Id);
        Event meetingWithoutContact = buildMeeting(meetingNote.Id);
        Event meetingWithoutInterest = buildMeeting(meetingNoteWithoutInterest.Id);
        insert new List<Event>{ meeting, meetingWithoutContact, meetingWithoutInterest };
        insert new List<EventRelation>{ new EventRelation(EventId = meeting.Id, RelationId = contact.Id), new EventRelation(EventId = meetingWithoutInterest.Id, RelationId = contact.Id) };
        Decimal minInterest = getRule(SOURCE_MEETING_PRODUCT_INTEREST)?.MinInterest__c ?? DEFAULT_MIN_INTEREST;
        insert new List<ClientInterest__c>{ new ClientInterest__c(MeetingNote__c = meetingNote.Id, Strategy__c = strategy.Id, Interest__c = minInterest), new ClientInterest__c(MeetingNote__c = meetingNote.Id, Interest__c = minInterest) };
    }

    // Runs the 14-day scheduled refresh: one signal per active source rule, nothing older than the window (a 30-day-old visit), and no reconciliation (an old signal stays active).
    @IsTest
    static void testScheduledRefresh() {
        Engagement_Signal__c staleSignal = insertStaleSignal();
        Digital_Interaction__c web = [SELECT Id FROM Digital_Interaction__c WHERE Engagement_Type__c = :ENGAGEMENT_TYPE_WEB AND Contact_lu__c != null LIMIT 1];
        Decimal minTimeSpent = getRule(SOURCE_WEB_VISIT)?.MinTimeSpentSeconds__c ?? DEFAULT_MIN_TIME_SPENT;
        Datetime oldInteractionDate = System.now().addDays(-OLD_INTERACTION_AGE_DAYS);
        insert buildDetail(web.Id, DETAIL_TYPE_VISIT, oldInteractionDate, FUND_NAME, minTimeSpent);

        Test.startTest();

        new EngagementSignalRefreshService(PARTIAL_WINDOW_DAYS).execute(null);

        Test.stopTest();

        assertOneSignalPerSource();
        System.assertEquals(true, [SELECT IsActive__c FROM Engagement_Signal__c WHERE Id = :staleSignal.Id].IsActive__c, 'A partial refresh does not reconcile');
    }

    // Runs the weekly full refresh: one signal per active source rule, reconciliation of an old signal without touching the signals of the run, idempotent re-execution of a source batch, then strict FundName resolution.
    @IsTest
    static void testFullRefresh() {
        Engagement_Signal__c staleSignal = insertStaleSignal();

        Test.startTest();

        new EngagementSignalRefreshService().execute(null);

        Test.stopTest();

        List<Engagement_Signal__c> signals = assertOneSignalPerSource();
        staleSignal = [SELECT IsActive__c, ObsoleteReason__c FROM Engagement_Signal__c WHERE Id = :staleSignal.Id];
        System.assertEquals(false, staleSignal.IsActive__c, 'The full refresh deactivates a signal it did not see');
        System.assert(staleSignal.ObsoleteReason__c.contains(signals[0].LastSeenRunId__c));
        System.assertEquals(signals.size(), [SELECT COUNT() FROM Engagement_Signal__c WHERE IsActive__c = true], 'Reconciliation keeps the signals of the run active');

        List<Digital_Interaction_Details__c> visits = [SELECT Id, Details_Date__c, FundName__c, Time_Spent__c, Digital_Interaction__r.Contact_lu__c FROM Digital_Interaction_Details__c WHERE Type__c = :DETAIL_TYPE_VISIT];
        new EngagementWebsiteSignalBatch().execute(null, visits);
        System.assertEquals(signals.size() + 1, [SELECT COUNT() FROM Engagement_Signal__c], 'Re-running a source batch must not create duplicates');

        Map<String, Id> strategyByFundName = EngagementFundStrategyResolver.loadStrategyByFundName();
        Strategy__c strategy = [SELECT Id FROM Strategy__c WHERE Code__c = :STRATEGY_CODE];
        System.assertEquals(strategy.Id, EngagementFundStrategyResolver.resolveFundName(FUND_NAME_SPACED_UPPERCASE, strategyByFundName), 'Case and spacing differences are normalized');
        System.assertEquals(null, EngagementFundStrategyResolver.resolveFundName(FUND_NAME_WITH_SUFFIX, strategyByFundName), 'No fuzzy matching');
        System.assertEquals(null, EngagementFundStrategyResolver.resolveFundName(FUND_NAME_AMBIGUOUS, strategyByFundName), 'A Fund name shared by two Strategies is not resolved');
        System.assertEquals(null, EngagementFundStrategyResolver.resolveFundName(null, strategyByFundName));
        System.assertEquals(null, EngagementFundStrategyResolver.normalizeFundName(BLANK));
    }

    // Asserts one active signal per active source rule, with the configured source object and weight and the refresh run id, and returns them (the old test signal excluded).
    private static List<Engagement_Signal__c> assertOneSignalPerSource() {
        List<Engagement_Signal__c> signals = [SELECT SourceType__c, SourceObject__c, QualityValue__c, BaseWeight__c, LastSeenRunId__c FROM Engagement_Signal__c WHERE IsActive__c = true AND ExternalKey__c != :STALE_SIGNAL_KEY];
        Map<String, List<Engagement_Signal__c>> signalsByType = new Map<String, List<Engagement_Signal__c>>();
        for (Engagement_Signal__c signal : signals) {
            if (!signalsByType.containsKey(signal.SourceType__c)) signalsByType.put(signal.SourceType__c, new List<Engagement_Signal__c>());
            signalsByType.get(signal.SourceType__c).add(signal);
            System.assert(signal.LastSeenRunId__c.startsWith(RUN_ID_PREFIX), 'Every signal carries the refresh run id');
        }
        for (String sourceType : SOURCE_OBJECT_BY_TYPE.keySet()) {
            if (getRule(sourceType) == null) continue;
            List<Engagement_Signal__c> typeSignals = signalsByType.get(sourceType);
            System.assertEquals(1, typeSignals?.size(), 'One signal expected for ' + sourceType);
            System.assertEquals(SOURCE_OBJECT_BY_TYPE.get(sourceType), typeSignals[0].SourceObject__c);
            System.assertEquals(EngagementScoringRuleService.getBaseWeight(sourceType, typeSignals[0].QualityValue__c), typeSignals[0].BaseWeight__c);
        }
        return signals;
    }

    // Inserts an active Website signal seen by an older run, which a full refresh must deactivate.
    private static Engagement_Signal__c insertStaleSignal() {
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        Strategy__c strategy = [SELECT Id FROM Strategy__c WHERE Code__c = :STRATEGY_CODE];
        Engagement_Signal__c staleSignal = new Engagement_Signal__c(ExternalKey__c = STALE_SIGNAL_KEY, Contact__c = contact.Id, Strategy__c = strategy.Id, SourceType__c = SOURCE_WEB_VISIT, SourceObject__c = OBJECT_INTERACTION_DETAIL, IsActive__c = true, LastSeenRunId__c = RUN_ID_OLD);
        insert staleSignal;
        return staleSignal;
    }

    // Returns the active rule of a source type, null when the source is disabled in this org.
    private static EngagementSignalRule__mdt getRule(String sourceType) {
        return EngagementScoringRuleService.getSignalRule(sourceType);
    }

    // Builds a Product Catalog Fund; strategyId null for a Fund without Strategy.
    private static Product__c buildFund(String code, String productName, Id strategyId) {
        return new Product__c(Name = code, ProductName__c = productName, FundStrategy__c = strategyId);
    }

    // Builds a Digital Interaction; contactId, campaignId and timeSpent are null when not filled.
    private static Digital_Interaction__c buildInteraction(Id contactId, String engagementType, Id campaignId, Decimal timeSpent) {
        return new Digital_Interaction__c(Contact_lu__c = contactId, Engagement_Type__c = engagementType, Campaign__c = campaignId, Time_Spent__c = timeSpent);
    }

    // Builds a Digital Interaction Detail; fundName and timeSpent are null when not filled.
    private static Digital_Interaction_Details__c buildDetail(Id interactionId, String detailType, Datetime detailsDate, String fundName, Decimal timeSpent) {
        return new Digital_Interaction_Details__c(Digital_Interaction__c = interactionId, Type__c = detailType, Details_Date__c = detailsDate, FundName__c = fundName, Time_Spent__c = timeSpent);
    }

    // Builds an active Prospace subscription; contactId null for a subscription without Contact.
    private static Web_Communication__c buildSubscription(Id contactId, Id fundId) {
        return new Web_Communication__c(Contact__c = contactId, Fund__c = fundId, IsActive__c = true);
    }

    // Builds a 30-minute meeting held yesterday on a Meeting Note.
    private static Event buildMeeting(Id meetingNoteId) {
        return new Event(Meeting_Note__c = meetingNoteId, DurationInMinutes = 30, ActivityDateTime = INTERACTION_DATE);
    }
}