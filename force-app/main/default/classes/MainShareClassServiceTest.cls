@IsTest
private class MainShareClassServiceTest {

    private static final String AllCountriesSicavContext = 'ALL_COUNTRIES|SICAV';
    private static final String UkSicavContext = 'UK|SICAV';

    // Builds one Main Share Class rule used by the selection tests.
    private static MainShareClassService.RuleDefinition buildRule(
        String developerName,
        String scope,
        String legalForm,
        String shareClassName,
        Decimal priority,
        Boolean isExcluded,
        Boolean isForceMain,
        Datetime modifiedAt
    ) {
        MainShareClassService.RuleDefinition rule = new MainShareClassService.RuleDefinition();
        rule.DeveloperName = developerName;
        rule.Scope = scope;
        rule.LegalForm = legalForm;
        rule.ShareClassName = shareClassName;
        rule.Priority = priority;
        rule.IsActive = true;
        rule.IsExcluded = isExcluded;
        rule.IsForceMain = isForceMain;
        rule.ModifiedAt = modifiedAt;
        return rule;
    }

    // Builds an in-memory Country Registration with the relationships required by the engine.
    private static Country__c buildRegistration(
        Id registrationId,
        String countryCode,
        String registrationStatus,
        String shareClassName,
        String legalForm
    ) {
        return new Country__c(
            Id = registrationId,
            Country__c = countryCode,
            RegistrationStatus__c = registrationStatus,
            ShareClass__r = new Share_Class__c(
                Name__c = shareClassName,
                Fund__r = new Product__c(
                    LegalForm__c = legalForm
                )
            )
        );
    }

    // Verifies that the lowest available priority wins for a non-UK country.
    @IsTest
    static void testSelectsLowestAvailablePriority() {
        Country__c eEurAcc = buildRegistration('a3a000000000001', 'FR', 'REG', 'E EUR Acc', 'SICAV');
        Country__c fEurAcc = buildRegistration('a3a000000000002', 'FR', 'REG', 'F EUR Acc', 'SICAV');
        Country__c aEurAcc = buildRegistration('a3a000000000003', 'FR', 'REG', 'A EUR Acc', 'SICAV');

        List<MainShareClassService.RuleDefinition> rules = new List<MainShareClassService.RuleDefinition>{
            buildRule('ALL_SICAV_A_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'A EUR Acc', 2, false, false, Datetime.newInstance(2026, 1, 1, 10, 0, 0)),
            buildRule('ALL_SICAV_F_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'F EUR Acc', 4, false, false, Datetime.newInstance(2026, 1, 1, 10, 0, 1)),
            buildRule('ALL_SICAV_E_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'E EUR Acc', 5, false, false, Datetime.newInstance(2026, 1, 1, 10, 0, 2))
        };

        Map<String, List<MainShareClassService.RuleDefinition>> rulesByContext =
            new Map<String, List<MainShareClassService.RuleDefinition>>{
                AllCountriesSicavContext => rules
            };

        Id selectedId = MainShareClassService.selectMainRegistration(
            new List<Country__c>{ eEurAcc, fEurAcc, aEurAcc },
            rulesByContext
        );

        System.assertEquals(aEurAcc.Id, selectedId, 'A EUR Acc must win with priority 2.');
    }

    // Verifies that an ineligible registration cannot become Main even with the best priority.
    @IsTest
    static void testIgnoresIneligibleRegistration() {
        Country__c awEurAcc = buildRegistration('a3a000000000004', 'FR', 'NOTREG', 'AW EUR Acc', 'SICAV');
        Country__c aEurAcc = buildRegistration('a3a000000000005', 'FR', 'REG', 'A EUR Acc', 'SICAV');

        List<MainShareClassService.RuleDefinition> rules = new List<MainShareClassService.RuleDefinition>{
            buildRule('ALL_SICAV_AW_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'AW EUR Acc', 1, false, false, Datetime.newInstance(2026, 1, 1, 10, 0, 0)),
            buildRule('ALL_SICAV_A_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'A EUR Acc', 2, false, false, Datetime.newInstance(2026, 1, 1, 10, 0, 1))
        };

        Id selectedId = MainShareClassService.selectMainRegistration(
            new List<Country__c>{ awEurAcc, aEurAcc },
            new Map<String, List<MainShareClassService.RuleDefinition>>{
                AllCountriesSicavContext => rules
            }
        );

        System.assertEquals(aEurAcc.Id, selectedId, 'NOTREG must not participate in the selection.');
    }

    // Verifies that GB uses the UK rules instead of ALL_COUNTRIES rules.
    @IsTest
    static void testUsesUkRulesForGb() {
        Country__c fEurAcc = buildRegistration('a3a000000000006', 'GB', 'REG', 'F EUR Acc', 'SICAV');
        Country__c fGbpAccHdg = buildRegistration('a3a000000000007', 'GB', 'REG', 'F GBP Acc Hdg', 'SICAV');

        List<MainShareClassService.RuleDefinition> ukRules = new List<MainShareClassService.RuleDefinition>{
            buildRule('UK_SICAV_F_GBP_ACC_HDG', 'UK', 'SICAV', 'F GBP Acc Hdg', 2, false, false, Datetime.newInstance(2026, 1, 1, 10, 0, 0)),
            buildRule('UK_SICAV_F_EUR_ACC', 'UK', 'SICAV', 'F EUR Acc', 6, false, false, Datetime.newInstance(2026, 1, 1, 10, 0, 1))
        };

        Id selectedId = MainShareClassService.selectMainRegistration(
            new List<Country__c>{ fEurAcc, fGbpAccHdg },
            new Map<String, List<MainShareClassService.RuleDefinition>>{
                UkSicavContext => ukRules
            }
        );

        System.assertEquals(fGbpAccHdg.Id, selectedId, 'GB must use UK priorities.');
    }

    // Verifies that ForceMain overrides the standard priority order.
    @IsTest
    static void testForceMainOverridesPriority() {
        Country__c aEurAcc = buildRegistration('a3a000000000008', 'FR', 'REG', 'A EUR Acc', 'SICAV');
        Country__c fEurAcc = buildRegistration('a3a000000000009', 'FR', 'REG', 'F EUR Acc', 'SICAV');

        List<MainShareClassService.RuleDefinition> rules = new List<MainShareClassService.RuleDefinition>{
            buildRule('ALL_SICAV_A_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'A EUR Acc', 2, false, false, Datetime.newInstance(2026, 1, 1, 10, 0, 0)),
            buildRule('ALL_SICAV_F_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'F EUR Acc', 4, false, true, Datetime.newInstance(2026, 1, 1, 10, 0, 1))
        };

        Id selectedId = MainShareClassService.selectMainRegistration(
            new List<Country__c>{ aEurAcc, fEurAcc },
            new Map<String, List<MainShareClassService.RuleDefinition>>{
                AllCountriesSicavContext => rules
            }
        );

        System.assertEquals(fEurAcc.Id, selectedId, 'ForceMain must override the lower standard priority.');
    }

    // Verifies that the most recently modified ForceMain wins when several are available.
    @IsTest
    static void testLatestForceMainWins() {
        Country__c aEurAcc = buildRegistration('a3a000000000010', 'FR', 'REG', 'A EUR Acc', 'SICAV');
        Country__c fEurAcc = buildRegistration('a3a000000000011', 'FR', 'REG', 'F EUR Acc', 'SICAV');

        List<MainShareClassService.RuleDefinition> rules = new List<MainShareClassService.RuleDefinition>{
            buildRule('ALL_SICAV_A_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'A EUR Acc', 2, false, true, Datetime.newInstance(2026, 1, 1, 10, 0, 0)),
            buildRule('ALL_SICAV_F_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'F EUR Acc', 4, false, true, Datetime.newInstance(2026, 1, 2, 10, 0, 0))
        };

        Id selectedId = MainShareClassService.selectMainRegistration(
            new List<Country__c>{ aEurAcc, fEurAcc },
            new Map<String, List<MainShareClassService.RuleDefinition>>{
                AllCountriesSicavContext => rules
            }
        );

        System.assertEquals(fEurAcc.Id, selectedId, 'The most recently modified ForceMain must win.');
    }

    // Verifies that an excluded candidate is skipped in favor of the next available priority.
    @IsTest
    static void testExcludedRuleIsIgnored() {
        Country__c aEurAcc = buildRegistration('a3a000000000012', 'FR', 'REG', 'A EUR Acc', 'SICAV');
        Country__c fEurAcc = buildRegistration('a3a000000000013', 'FR', 'REG', 'F EUR Acc', 'SICAV');

        List<MainShareClassService.RuleDefinition> rules = new List<MainShareClassService.RuleDefinition>{
            buildRule('ALL_SICAV_A_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'A EUR Acc', 2, true, false, Datetime.newInstance(2026, 1, 1, 10, 0, 0)),
            buildRule('ALL_SICAV_F_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'F EUR Acc', 4, false, false, Datetime.newInstance(2026, 1, 1, 10, 0, 1))
        };

        Id selectedId = MainShareClassService.selectMainRegistration(
            new List<Country__c>{ aEurAcc, fEurAcc },
            new Map<String, List<MainShareClassService.RuleDefinition>>{
                AllCountriesSicavContext => rules
            }
        );

        System.assertEquals(fEurAcc.Id, selectedId, 'An excluded rule must not be selected.');
    }

    // Verifies that the only eligible registration becomes Main even without configured rules.
    @IsTest
    static void testSelectsSingleRegistrationWithoutContextRules() {
        Country__c aEurAcc = buildRegistration('a3a000000000014', 'FR', 'REG', 'A EUR Acc', 'SICAV');

        Id selectedId = MainShareClassService.selectMainRegistration(
            new List<Country__c>{ aEurAcc },
            new Map<String, List<MainShareClassService.RuleDefinition>>()
        );

        System.assertEquals(
            aEurAcc.Id,
            selectedId,
            'The only eligible registration must become Main even without configured rules.'
        );
    }

    // Verifies that duplicate priorities in the same competing context are rejected.
    @IsTest
    static void testDuplicatePriorityThrowsException() {
        Country__c aEurAcc = buildRegistration('a3a000000000015', 'FR', 'REG', 'A EUR Acc', 'SICAV');
        Country__c fEurAcc = buildRegistration('a3a000000000016', 'FR', 'REG', 'F EUR Acc', 'SICAV');

        List<MainShareClassService.RuleDefinition> rules = new List<MainShareClassService.RuleDefinition>{
            buildRule('ALL_SICAV_A_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'A EUR Acc', 2, false, false, Datetime.newInstance(2026, 1, 1, 10, 0, 0)),
            buildRule('ALL_SICAV_F_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'F EUR Acc', 2, false, false, Datetime.newInstance(2026, 1, 1, 10, 0, 1))
        };

        try {
            MainShareClassService.selectMainRegistration(
                new List<Country__c>{ aEurAcc, fEurAcc },
                new Map<String, List<MainShareClassService.RuleDefinition>>{
                    AllCountriesSicavContext => rules
                }
            );
            System.assert(false, 'Duplicate priorities must throw an exception.');
        } catch (MainShareClassService.MainShareClassException exceptionRecord) {
            System.assert(exceptionRecord.getMessage().contains('Duplicate Main Share Class priority'));
        }
    }

    // Verifies that a contradictory Excluded + ForceMain rule is rejected.
    @IsTest
    static void testExcludedAndForceMainThrowsException() {
        Country__c aEurAcc = buildRegistration('a3a000000000017', 'FR', 'REG', 'A EUR Acc', 'SICAV');
        Country__c fEurAcc = buildRegistration('a3a000000000018', 'FR', 'REG', 'F EUR Acc', 'SICAV');

        List<MainShareClassService.RuleDefinition> rules = new List<MainShareClassService.RuleDefinition>{
            buildRule('ALL_SICAV_A_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'A EUR Acc', 2, true, true, Datetime.newInstance(2026, 1, 1, 10, 0, 0)),
            buildRule('ALL_SICAV_F_EUR_ACC', 'ALL_COUNTRIES', 'SICAV', 'F EUR Acc', 4, false, false, Datetime.newInstance(2026, 1, 1, 10, 0, 1))
        };

        try {
            MainShareClassService.selectMainRegistration(
                new List<Country__c>{ aEurAcc, fEurAcc },
                new Map<String, List<MainShareClassService.RuleDefinition>>{
                    AllCountriesSicavContext => rules
                }
            );
            System.assert(false, 'Excluded + ForceMain must throw an exception.');
        } catch (MainShareClassService.MainShareClassException exceptionRecord) {
            System.assert(exceptionRecord.getMessage().contains('both Excluded and ForceMain'));
        }
    }

    // Verifies null and empty public entry points remain safe for trigger and batch execution.
    @IsTest
    static void testPublicEntryPointsHandleEmptyInput() {
        Test.startTest();
        MainShareClassService.recalculateAfterCountryInsert(new List<Country__c>());
        MainShareClassService.recalculateAfterCountryUpdate(new List<Country__c>(), new Map<Id, Country__c>());
        MainShareClassService.recalculateAfterCountryDelete(new List<Country__c>());
        MainShareClassService.recalculateAfterShareClassInsert(new List<Share_Class__c>());
        MainShareClassService.recalculateAfterShareClassUpdate(new List<Share_Class__c>(), new Map<Id, Share_Class__c>());
        MainShareClassService.recalculateByRegistrationIds(new Set<Id>());
        Test.stopTest();

        System.assert(true, 'Empty bulk inputs must be handled without exception.');
    }
}