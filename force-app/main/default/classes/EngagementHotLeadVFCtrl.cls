public with sharing class EngagementHotLeadVFCtrl {
    private static final Integer SCORE_LOOKBACK_DAYS = 180;
    private static final Integer HOT_LOOKBACK_DAYS = 60;
    private static final Integer MIN_HOT_SIGNALS = 4;
    private static final Integer MIN_HOT_SOURCES = 2;
    private static final Integer MAX_CANDIDATE_PAIRS = 500;
    private static final Integer TOP_LIMIT = 15;

    public List<HotLeadRow> hotLeads { get; private set; }
    public HotLeadRow selectedLead { get; private set; }
    public List<SignalRow> selectedSignals { get; private set; }
    public List<SourceBreakdownRow> sourceBreakdown { get; private set; }
    public String selectedKey { get; set; }

    /**
     * Loads the current Top 15 Contact x Strategy Hot Leads.
     */
    public EngagementHotLeadVFCtrl() {
        hotLeads = new List<HotLeadRow>();
        selectedSignals = new List<SignalRow>();
        sourceBreakdown = new List<SourceBreakdownRow>();
        loadHotLeads();
    }

    /**
     * Selects one Contact x Strategy row from the ranking.
     */
    public PageReference selectLead() {
        if (String.isBlank(selectedKey)) {
            return null;
        }

        for (HotLeadRow lead : hotLeads) {
            if (lead.key == selectedKey) {
                selectedLead = lead;
                buildSelectedLeadDetails();
                break;
            }
        }
        return null;
    }

    /**
     * Finds Hot Lead candidate pairs on the recent 60-day window, then ranks them
     * using the existing 180-day scoring calculator and configured metadata rules.
     */
    private void loadHotLeads() {
        Datetime hotCutoff = System.now().addDays(-HOT_LOOKBACK_DAYS);
        List<AggregateResult> candidateRows = [
            SELECT Contact__c contactId,
                   Strategy__c strategyId,
                   COUNT(Id) recentCount,
                   COUNT_DISTINCT(SourceType__c) sourceCount
            FROM Engagement_Signal__c
            WHERE IsActive__c = true
            AND InteractionDate__c >= :hotCutoff
            AND Contact__c != null
            AND Strategy__c != null
            GROUP BY Contact__c, Strategy__c
            HAVING COUNT(Id) >= :MIN_HOT_SIGNALS
            AND COUNT_DISTINCT(SourceType__c) >= :MIN_HOT_SOURCES
            ORDER BY COUNT(Id) DESC
            LIMIT :MAX_CANDIDATE_PAIRS
        ];

        if (candidateRows.isEmpty()) {
            return;
        }

        Set<Id> contactIds = new Set<Id>();
        Set<Id> strategyIds = new Set<Id>();
        Map<String, CandidateInfo> candidateByKey = new Map<String, CandidateInfo>();
        for (AggregateResult row : candidateRows) {
            Id contactId = (Id) row.get('contactId');
            Id strategyId = (Id) row.get('strategyId');
            String key = buildKey(contactId, strategyId);

            CandidateInfo candidate = new CandidateInfo();
            candidate.contactId = contactId;
            candidate.strategyId = strategyId;
            candidate.recentCount = Integer.valueOf(String.valueOf(row.get('recentCount')));
            candidate.sourceCount = Integer.valueOf(String.valueOf(row.get('sourceCount')));
            candidateByKey.put(key, candidate);
            contactIds.add(contactId);
            strategyIds.add(strategyId);
        }

        Datetime scoreCutoff = System.now().addDays(-SCORE_LOOKBACK_DAYS);
        Map<String, List<Engagement_Signal__c>> signalsByKey = new Map<String, List<Engagement_Signal__c>>();
        for (Engagement_Signal__c signal : [
            SELECT Id,
                   Contact__c,
                   Strategy__c,
                   SourceType__c,
                   SourceObject__c,
                   SourceId__c,
                   InteractionDate__c,
                   QualityValue__c,
                   BaseWeight__c,
                   IsActive__c
            FROM Engagement_Signal__c
            WHERE IsActive__c = true
            AND InteractionDate__c >= :scoreCutoff
            AND Contact__c IN :contactIds
            AND Strategy__c IN :strategyIds
            ORDER BY InteractionDate__c DESC
        ]) {
            String key = buildKey(signal.Contact__c, signal.Strategy__c);
            if (!candidateByKey.containsKey(key)) {
                continue;
            }
            if (!signalsByKey.containsKey(key)) {
                signalsByKey.put(key, new List<Engagement_Signal__c>());
            }
            signalsByKey.get(key).add(signal);
        }

        Map<Id, Contact> contactsById = new Map<Id, Contact>([
            SELECT Id, Name, FirstName, LastName, Email, Phone, Title, Account.Name
            FROM Contact
            WHERE Id IN :contactIds
        ]);
        Map<Id, Strategy__c> strategiesById = new Map<Id, Strategy__c>([
            SELECT Id, Name
            FROM Strategy__c
            WHERE Id IN :strategyIds
        ]);

        Map<Id, HotLeadRow> bestLeadByContact = new Map<Id, HotLeadRow>();
        for (String key : candidateByKey.keySet()) {
            CandidateInfo candidate = candidateByKey.get(key);
            List<Engagement_Signal__c> pairSignals = signalsByKey.get(key);
            if (pairSignals == null || pairSignals.isEmpty()) {
                continue;
            }

            EngagementScoreCalculator.ScoreResult scoreResult =
                EngagementScoreCalculator.calculateScore(pairSignals);
            HotLeadRow lead = buildLeadRow(
                candidate,
                contactsById.get(candidate.contactId),
                strategiesById.get(candidate.strategyId),
                scoreResult,
                pairSignals
            );

            HotLeadRow existingLead = bestLeadByContact.get(candidate.contactId);
            if (existingLead == null || isHigherRank(lead, existingLead)) {
                bestLeadByContact.put(candidate.contactId, lead);
            }
        }

        hotLeads.addAll(bestLeadByContact.values());
        sortLeads(hotLeads);
        while (hotLeads.size() > TOP_LIMIT) {
            hotLeads.remove(hotLeads.size() - 1);
        }

        for (Integer index = 0; index < hotLeads.size(); index++) {
            hotLeads[index].rank = index + 1;
        }

        if (!hotLeads.isEmpty()) {
            selectedKey = hotLeads[0].key;
            selectedLead = hotLeads[0];
            buildSelectedLeadDetails();
        }
    }

    /**
     * Builds the visual row used by the ranking and selected detail panel.
     */
    private static HotLeadRow buildLeadRow(
        CandidateInfo candidate,
        Contact contactRecord,
        Strategy__c strategyRecord,
        EngagementScoreCalculator.ScoreResult scoreResult,
        List<Engagement_Signal__c> signals
    ) {
        HotLeadRow lead = new HotLeadRow();
        lead.key = buildKey(candidate.contactId, candidate.strategyId);
        lead.contactId = candidate.contactId;
        lead.strategyId = candidate.strategyId;
        lead.contactName = contactRecord == null ? 'Contact' : contactRecord.Name;
        lead.initials = getInitials(contactRecord);
        lead.accountName = contactRecord == null || contactRecord.Account == null
            ? ''
            : contactRecord.Account.Name;
        lead.email = contactRecord == null ? null : contactRecord.Email;
        lead.phone = contactRecord == null ? null : contactRecord.Phone;
        lead.title = contactRecord == null ? null : contactRecord.Title;
        lead.strategyName = strategyRecord == null ? 'Strategy' : strategyRecord.Name;
        lead.score = scoreResult == null || scoreResult.score == null ? 0 : scoreResult.score;
        lead.scoreDisplay = formatScore(lead.score);
        lead.signalCount180 = scoreResult == null ? 0 : scoreResult.signalCount;
        lead.recentCount60 = candidate.recentCount;
        lead.distinctSources60 = candidate.sourceCount;
        lead.lastInteractionDate = scoreResult == null ? null : scoreResult.lastInteractionDate;
        lead.signals = signals;
        return lead;
    }

    /**
     * Loads the detail table and score distribution for the selected pair.
     */
    private void buildSelectedLeadDetails() {
        selectedSignals.clear();
        sourceBreakdown.clear();
        if (selectedLead == null || selectedLead.signals == null) {
            return;
        }

        Map<String, Decimal> scoreBySource = new Map<String, Decimal>();
        Decimal totalScore = 0;
        for (Engagement_Signal__c signal : selectedLead.signals) {
            Decimal contribution = EngagementScoreCalculator.calculateSignalScore(signal);
            if (contribution <= 0) {
                continue;
            }

            SignalRow row = new SignalRow();
            row.signalId = signal.Id;
            row.sourceType = signal.SourceType__c;
            row.sourceLabel = getSourceLabel(signal.SourceType__c);
            row.sourceObject = signal.SourceObject__c;
            row.sourceId = signal.SourceId__c;
            row.sourceUrl = String.isBlank(signal.SourceId__c) ? null : '/' + signal.SourceId__c;
            row.interactionDate = signal.InteractionDate__c;
            row.qualityValue = signal.QualityValue__c;
            row.qualityDisplay = getQualityDisplay(signal.SourceType__c, signal.QualityValue__c);
            row.contribution = contribution;
            row.contributionDisplay = formatScore(contribution);
            row.icon = getSourceIcon(signal.SourceType__c);
            selectedSignals.add(row);

            totalScore += contribution;
            Decimal sourceScore = scoreBySource.containsKey(signal.SourceType__c)
                ? scoreBySource.get(signal.SourceType__c)
                : 0;
            scoreBySource.put(signal.SourceType__c, sourceScore + contribution);
        }

        for (String sourceType : scoreBySource.keySet()) {
            Decimal sourceScore = scoreBySource.get(sourceType);
            SourceBreakdownRow row = new SourceBreakdownRow();
            row.sourceType = sourceType;
            row.label = getSourceLabel(sourceType);
            row.score = sourceScore;
            row.scoreDisplay = formatScore(sourceScore);
            row.percent = totalScore == 0
                ? 0
                : (sourceScore * 100 / totalScore).setScale(1);
            row.cssClass = getSourceCssClass(sourceType);
            sourceBreakdown.add(row);
        }

        sortBreakdown(sourceBreakdown);
    }

    /**
     * Returns true when the first lead must rank before the second one.
     */
    private static Boolean isHigherRank(HotLeadRow firstLead, HotLeadRow secondLead) {
        if (firstLead.score != secondLead.score) {
            return firstLead.score > secondLead.score;
        }
        if (firstLead.lastInteractionDate == null) {
            return false;
        }
        if (secondLead.lastInteractionDate == null) {
            return true;
        }
        return firstLead.lastInteractionDate > secondLead.lastInteractionDate;
    }

    /**
     * Sorts leads descending by score and then by latest interaction date.
     */
    private static void sortLeads(List<HotLeadRow> leads) {
        for (Integer i = 1; i < leads.size(); i++) {
            HotLeadRow current = leads[i];
            Integer j = i - 1;
            while (j >= 0 && isHigherRank(current, leads[j])) {
                leads[j + 1] = leads[j];
                j--;
            }
            leads[j + 1] = current;
        }
    }

    /**
     * Sorts source breakdown rows descending by score.
     */
    private static void sortBreakdown(List<SourceBreakdownRow> rows) {
        for (Integer i = 1; i < rows.size(); i++) {
            SourceBreakdownRow current = rows[i];
            Integer j = i - 1;
            while (j >= 0 && current.score > rows[j].score) {
                rows[j + 1] = rows[j];
                j--;
            }
            rows[j + 1] = current;
        }
    }

    /**
     * Builds the unique Contact x Strategy key used only by this controller.
     */
    private static String buildKey(Id contactId, Id strategyId) {
        return String.valueOf(contactId) + '-' + String.valueOf(strategyId);
    }

    /**
     * Returns initials for the circular contact avatar.
     */
    private static String getInitials(Contact contactRecord) {
        if (contactRecord == null) return '?';
        String firstInitial = String.isBlank(contactRecord.FirstName)
            ? ''
            : contactRecord.FirstName.substring(0, 1).toUpperCase();
        String lastInitial = String.isBlank(contactRecord.LastName)
            ? ''
            : contactRecord.LastName.substring(0, 1).toUpperCase();
        String initials = firstInitial + lastInitial;
        return String.isBlank(initials) ? '?' : initials;
    }

    /**
     * Formats a score without unnecessary trailing decimals.
     */
    private static String formatScore(Decimal score) {
        if (score == null) return '0';
        Decimal rounded = score.setScale(2);
        if (rounded == rounded.setScale(0)) {
            return String.valueOf(rounded.setScale(0));
        }
        return String.valueOf(rounded);
    }

    /**
     * Returns a user-friendly source label.
     */
    private static String getSourceLabel(String sourceType) {
        Map<String, String> labels = new Map<String, String>{
            'WEB_VISIT' => 'Website',
            'NEWSLETTER_CLICK' => 'Newsletter',
            'PROSPACE_SUBSCRIPTION' => 'Subscription',
            'WEBINAR_ATTENDANCE' => 'Webinar',
            'MEETING_PRODUCT_INTEREST' => 'Meeting Note'
        };
        return labels.containsKey(sourceType) ? labels.get(sourceType) : sourceType;
    }

    /**
     * Returns a compact source icon for the detail table.
     */
    private static String getSourceIcon(String sourceType) {
        Map<String, String> icons = new Map<String, String>{
            'WEB_VISIT' => '●',
            'NEWSLETTER_CLICK' => '✉',
            'PROSPACE_SUBSCRIPTION' => '◆',
            'WEBINAR_ATTENDANCE' => '▶',
            'MEETING_PRODUCT_INTEREST' => '▣'
        };
        return icons.containsKey(sourceType) ? icons.get(sourceType) : '•';
    }

    /**
     * Formats source-specific quality information.
     */
    private static String getQualityDisplay(String sourceType, Decimal qualityValue) {
        if (qualityValue == null) return '';
        if (sourceType == 'WEB_VISIT') {
            return formatScore(qualityValue) + ' sec';
        }
        if (sourceType == 'WEBINAR_ATTENDANCE') {
            return formatScore(qualityValue) + ' %';
        }
        if (sourceType == 'MEETING_PRODUCT_INTEREST') {
            return 'Interest ' + formatScore(qualityValue) + '/5';
        }
        return formatScore(qualityValue);
    }

    /**
     * Returns a stable CSS class for one source.
     */
    private static String getSourceCssClass(String sourceType) {
        Map<String, String> classes = new Map<String, String>{
            'WEB_VISIT' => 'source-web',
            'NEWSLETTER_CLICK' => 'source-newsletter',
            'PROSPACE_SUBSCRIPTION' => 'source-subscription',
            'WEBINAR_ATTENDANCE' => 'source-webinar',
            'MEETING_PRODUCT_INTEREST' => 'source-meeting'
        };
        return classes.containsKey(sourceType) ? classes.get(sourceType) : 'source-other';
    }

    private class CandidateInfo {
        public Id contactId;
        public Id strategyId;
        public Integer recentCount;
        public Integer sourceCount;
    }

    public class HotLeadRow {
        public Integer rank { get; set; }
        public String key { get; set; }
        public Id contactId { get; set; }
        public Id strategyId { get; set; }
        public String contactName { get; set; }
        public String initials { get; set; }
        public String accountName { get; set; }
        public String email { get; set; }
        public String phone { get; set; }
        public String title { get; set; }
        public String strategyName { get; set; }
        public Decimal score { get; set; }
        public String scoreDisplay { get; set; }
        public Integer signalCount180 { get; set; }
        public Integer recentCount60 { get; set; }
        public Integer distinctSources60 { get; set; }
        public Datetime lastInteractionDate { get; set; }
        public List<Engagement_Signal__c> signals { get; set; }
    }

    public class SignalRow {
        public Id signalId { get; set; }
        public String sourceType { get; set; }
        public String sourceLabel { get; set; }
        public String sourceObject { get; set; }
        public String sourceId { get; set; }
        public String sourceUrl { get; set; }
        public String icon { get; set; }
        public Datetime interactionDate { get; set; }
        public Decimal qualityValue { get; set; }
        public String qualityDisplay { get; set; }
        public Decimal contribution { get; set; }
        public String contributionDisplay { get; set; }
    }

    public class SourceBreakdownRow {
        public String sourceType { get; set; }
        public String label { get; set; }
        public Decimal score { get; set; }
        public String scoreDisplay { get; set; }
        public Decimal percent { get; set; }
        public String cssClass { get; set; }
    }
}