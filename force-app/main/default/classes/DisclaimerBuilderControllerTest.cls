/** ──────────────────────────────────────
 * @description Test class for DisclaimerBuilderController.
 *              Validates narrative search/aggregation (Single vs Multiple NumberOfFunds__c, Footnote/End Disclaimer
 *              bucketing) and the creation of the resulting Disclaimer__c + DisclaimerDetail__c records.
 * @author Charles EID
 * @testClass DisclaimerBuilderControllerTest
 ────────────────────────────────────── */
@IsTest
private with sharing class DisclaimerBuilderControllerTest {

    @TestSetup
    static void makeData() {
        Id disclaimerRTId = Schema.SObjectType.Narrative__c.getRecordTypeInfosByDeveloperName().get('Disclaimer').getRecordTypeId();

        insert new List<Narrative__c>{
            new Narrative__c(
                Name                = 'Footnote FR Single',
                RecordTypeId        = disclaimerRTId,
                Type__c             = 'Footnote',
                Content__c          = 'Footnote content A',
                Source__c           = 'Carmignac',
                ContentType__c      = 'Performance',
                Media__c            = 'Website',
                Country__c          = 'BE',
                NumberOfFunds__c    = 'Single'
            ),
            new Narrative__c(
                Name                = 'Footnote FR Single 2',
                RecordTypeId        = disclaimerRTId,
                Type__c             = 'Footnote',
                Content__c          = 'Footnote content B',
                Source__c           = 'Carmignac',
                ContentType__c      = 'Performance',
                Media__c            = 'Website',
                Country__c          = 'BE',
                NumberOfFunds__c    = 'Single'
            ),
            new Narrative__c(
                Name                = 'End Disclaimer FR Single',
                RecordTypeId        = disclaimerRTId,
                Type__c             = 'End Disclaimer',
                Content__c          = 'End disclaimer content',
                Source__c           = 'Carmignac',
                ContentType__c      = 'Performance',
                Media__c            = 'Website',
                Country__c          = 'BE',
                NumberOfFunds__c    = 'Single'
            ),
            new Narrative__c(
                Name                = 'Footnote FR Multiple',
                RecordTypeId        = disclaimerRTId,
                Type__c             = 'Footnote',
                Content__c          = 'Footnote content for multiple products',
                Source__c           = 'Carmignac',
                ContentType__c      = 'Performance',
                Media__c            = 'Website',
                Country__c          = 'BE',
                NumberOfFunds__c    = 'Multiple'
            )
        };
    }

    @IsTest
    static void testSearchNarratives_SingleProduct() {
        String criteriaJson = JSON.serialize(new Map<String, Object>{
            'products'      => new List<String>{'CI'},
            'sources'       => new List<String>{'Carmignac'},
            'contentTypes'  => new List<String>{'Performance'},
            'media'         => new List<String>{'Website'},
            'country'       => 'BE'
        });

        Test.startTest();
        DisclaimerBuilderController.NarrativeSearchResult result = DisclaimerBuilderController.searchNarratives(criteriaJson);
        Test.stopTest();

        System.assertEquals(2, result.footnote.matchCount);
        System.assertEquals(1, result.endDisclaimer.matchCount);
    }

    @IsTest
    static void testSearchNarratives_MultipleProducts() {
        String criteriaJson = JSON.serialize(new Map<String, Object>{
            'products'      => new List<String>{'CI', 'CP'},
            'sources'       => new List<String>{'Carmignac'},
            'contentTypes'  => new List<String>{'Performance'},
            'media'         => new List<String>{'Website'},
            'country'       => 'BE'
        });

        Test.startTest();
        DisclaimerBuilderController.NarrativeSearchResult result = DisclaimerBuilderController.searchNarratives(criteriaJson);
        Test.stopTest();

        System.assertEquals(1, result.footnote.matchCount);
        System.assertEquals(0, result.endDisclaimer.matchCount);
    }

    @IsTest
    static void testBuildDisclaimer() {
        String criteriaJson = JSON.serialize(new Map<String, Object>{
            'products'      => new List<String>{'CI'},
            'sources'       => new List<String>{'Carmignac'},
            'contentTypes'  => new List<String>{'Performance'},
            'media'         => new List<String>{'Website'},
            'country'       => 'BE'
        });
        String previewJson = JSON.serialize(DisclaimerBuilderController.searchNarratives(criteriaJson));

        Test.startTest();
        Id disclaimerId = DisclaimerBuilderController.buildDisclaimer(criteriaJson, previewJson);
        Test.stopTest();

        List<DisclaimerDetail__c> details = [SELECT Type__c, Content__c FROM DisclaimerDetail__c WHERE Disclaimer__c = :disclaimerId];
        System.assertEquals(2, details.size());
    }
}
