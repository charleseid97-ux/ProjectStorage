/** ──────────────────────────────────────
 * @description Lightning Web Component controller for the Disclaimer Builder screen.
 *              Searches Disclaimer-record-type Narrative__c records matching the selected
 *                  Source / Content Type / Media / Country / Number Of Funds criteria,
 *                  concatenates their Content__c per Footnote / End Disclaimer bucket, and
 *                  persists the resulting Disclaimer__c + DisclaimerDetail__c records.
 * @author Charles EID
 * @testClass DisclaimerBuilderControllerTest
 ────────────────────────────────────── */
public with sharing class DisclaimerBuilderController {

    @AuraEnabled(cacheable=true)
    public static NarrativeSearchResult searchNarratives(String criteriaJson) {
        DisclaimerCriteria criteria = (DisclaimerCriteria) JSON.deserialize(criteriaJson, DisclaimerCriteria.class);
        String numberOfFunds = (criteria.products != null && criteria.products.size() > 1) ? 'Multiple' : 'Single';

        List<Narrative__c> footnotes      = new List<Narrative__c>();
        List<Narrative__c> endDisclaimers = new List<Narrative__c>();
        for (Narrative__c n : [SELECT Id, Type__c, Content__c
                                FROM Narrative__c
                                WHERE RecordType.DeveloperName = 'Disclaimer'
                                AND Type__c IN ('Footnote', 'End Disclaimer')
                                AND Source__c IN :criteria.sources
                                AND ContentType__c IN :criteria.contentTypes
                                AND Media__c IN :criteria.media
                                AND Country__c = :criteria.country
                                AND NumberOfFunds__c = :numberOfFunds]) {
            if (n.Type__c == 'Footnote') {
                footnotes.add(n);
            } else {
                endDisclaimers.add(n);
            }
        }

        NarrativeSearchResult result = new NarrativeSearchResult();
        result.footnote      = buildBucket(footnotes);
        result.endDisclaimer = buildBucket(endDisclaimers);
        return result;
    }

    @AuraEnabled
    public static Id buildDisclaimer(String criteriaJson, String previewJson) {
        DisclaimerCriteria criteria    = (DisclaimerCriteria) JSON.deserialize(criteriaJson, DisclaimerCriteria.class);
        NarrativeSearchResult preview  = (NarrativeSearchResult) JSON.deserialize(previewJson, NarrativeSearchResult.class);

        Disclaimer__c disclaimer = new Disclaimer__c(
            SelectedProducts__c     = String.join(criteria.products, ', '),
            SelectedSources__c      = String.join(criteria.sources, ', '),
            SelectedContentTypes__c = String.join(criteria.contentTypes, ', '),
            SelectedMedia__c        = String.join(criteria.media, ', '),
            SelectedCountry__c      = criteria.country
        );
        insert disclaimer;

        List<DisclaimerDetail__c> details = new List<DisclaimerDetail__c>{
            new DisclaimerDetail__c(
                Disclaimer__c       = disclaimer.Id,
                Type__c             = 'End Disclaimer',
                Content__c          = preview.endDisclaimer.content,
                SourceNarratives__c = String.join(preview.endDisclaimer.narrativeIds, ', ')
            ),
            new DisclaimerDetail__c(
                Disclaimer__c       = disclaimer.Id,
                Type__c             = 'Footnote',
                Content__c          = preview.footnote.content,
                SourceNarratives__c = String.join(preview.footnote.narrativeIds, ', ')
            )
        };
        insert details;

        return disclaimer.Id;
    }

    private static NarrativeBucket buildBucket(List<Narrative__c> narratives) {
        NarrativeBucket bucket = new NarrativeBucket();
        List<String> contentParts = new List<String>();
        for (Narrative__c n : narratives) {
            if (String.isNotBlank(n.Content__c)) {
                contentParts.add(n.Content__c);
            }
            bucket.narrativeIds.add(n.Id);
        }
        bucket.content    = String.join(contentParts, '\n\n');
        bucket.matchCount = narratives.size();
        return bucket;
    }

    // ────────────────────────────────────── WRAPPERS ──────────────────────────────────────
    public class DisclaimerCriteria {
        @AuraEnabled public List<String> products { get; set; }
        @AuraEnabled public List<String> sources { get; set; }
        @AuraEnabled public List<String> contentTypes { get; set; }
        @AuraEnabled public List<String> media { get; set; }
        @AuraEnabled public String country { get; set; }
    }

    public class NarrativeSearchResult {
        @AuraEnabled public NarrativeBucket footnote { get; set; }
        @AuraEnabled public NarrativeBucket endDisclaimer { get; set; }
        public NarrativeSearchResult() {
            this.footnote      = new NarrativeBucket();
            this.endDisclaimer = new NarrativeBucket();
        }
    }

    public class NarrativeBucket {
        @AuraEnabled public String content { get; set; }
        @AuraEnabled public List<String> narrativeIds { get; set; }
        @AuraEnabled public Integer matchCount { get; set; }
        public NarrativeBucket() {
            this.content      = '';
            this.narrativeIds = new List<String>();
            this.matchCount   = 0;
        }
    }
}
