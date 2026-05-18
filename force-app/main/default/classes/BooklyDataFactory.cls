public class BooklyDataFactory {

    private static Integer counter = 0;
    private static User cachedOrganizer;

    // Génère une clé unique pour éviter les conflits d'unicité.
    private static String uniqueKey() {
        counter++;
        return String.valueOf(DateTime.now().getTime()) + counter;
    }

    // Récupère le profil utilisé par les users de test Bookly.
    private static Id getAdminProfileId() {
        return [
            SELECT Id
            FROM Profile
            WHERE Name = 'Carmignac - System Administrator'
            LIMIT 1
        ].Id;
    }

    // Crée un compte utilisé comme société liée aux contacts et events.
    public static Account createAccount() {
        Account acc = new Account(
            Name = 'CARMIGNAC Test ' + uniqueKey(),
            CurrencyIsoCode = 'EUR'
        );

        insert acc;
        return acc;
    }

    // Crée l'utilisateur organizer unique utilisé pour tous les rôles utilisateur.
    public static User createOrganizerUser() {
        String key = uniqueKey();

        User u = new User(
            Alias = 'bookly',
            Email = 'bookly.organizer.' + key + '@test.com',
            Username = 'bookly.organizer.' + key + '@test.com',
            LastName = 'Organizer',
            FirstName = 'Bookly',
            CommunityNickname = 'bookly' + key,
            CompanyName = 'INETUM',
            Department = 'DBS',
            Division = 'Digital Transformation',
            Country = 'France',
            CountryCode = 'FR',
            CurrencyIsoCode = 'EUR',
            DefaultCurrencyIsoCode = 'EUR',
            EmailEncodingKey = 'ISO-8859-1',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'fr_FR_EURO',
            TimeZoneSidKey = 'Europe/Paris',
            Team__c = 'France',
            BusinessDevelopmentRegions__c = 'BP_FR',
            Bypass_Duplicate_Rules__c = true,
            BypassValidationRules__c = true,
            Bypass_Flow__c = false,
            BypassProcessBuilders__c = false,
            BypassWorkflowRules__c = false,
            Approver__c = false,
            IsActive = true,
            ProfileId = getAdminProfileId()
        );

        insert u;
        return u;
    }

    // Crée un contact speaker avec un scénario top speaker configurable.
    public static Contact createSpeakerContact(Id accountId, Id ownerId, Boolean isTopSpeaker) {
        Contact speaker = new Contact(
            FirstName = 'Raphael',
            LastName = 'GALLARDO',
            Email = 'speaker.' + uniqueKey() + '@test.com',
            AccountId = accountId,
            OwnerId = ownerId,
            CurrencyIsoCode = 'EUR',
            JobTitle__c = 'Product Manager',
            Language__c = 'French',
            LeadSource = 'Event',
            Persona__c = 'B2B Buyer',
            ContactStatus__c = 'true',
            IsValidSpeaker__c = true,
            AssetClassFocus__c = 'Other',
            OtherCountry = 'France',
            OtherCountryCode = 'FR',
            MailingCity = 'Paris',
            MailingPostalCode = '75001',
            MailingStreet = '24 Place Vendôme'
        );

        if (isTopSpeaker) {
            speaker.AttendanceNumber__c = 1;
            speaker.Equities__c = true;
            speaker.Fixed_Income_Strategy__c = true;
            speaker.Carmignac_Emergents_CE_PE_UKCE__c = true;
            speaker.Carmignac_Flexible_Bond_CFB__c = true;
        }

        insert speaker;
        return speaker;
    }

    // Crée un event complet avec les valeurs valides connues.
    public static Event__c createEvent(Id accountId, Id organizerUserId) {
        Event__c evt = new Event__c(
            title__c = 'test',
            description__c = 'test',
            category__c = 'Event conference',
            city__c = 'Ajaccio',
            country__c = 'France',
            clientType__c = 'End Investor',
            AudienceCompany__c = 'One company',
            Co_hosted__c = 'No',
            format__c = 'Physical',
            language__c = 'FR',
            salesTeam__c = 'Belgium',
            timezone__c = 'Europe/Paris',
            startDate__c = Date.today().addDays(10),
            endDate__c = Date.today().addDays(10),
            startTime__c = '11:30',
            endTime__c = '19:15',
            targetedAttendees__c = 2,
            company__c = accountId,
            Organizer__c = organizerUserId,
            salesOwner__c = organizerUserId,
            bypasseApprovals__c = false,
            bypasseNotifications__c = false,
            noAutomations__c = false
        );

        insert evt;
        return evt;
    }

    // Crée une stratégie minimale pour les SessionSpeakerProduct.
    public static Strategy__c createStrategy(String name) {
        String key = uniqueKey();

        Strategy__c strategy = new Strategy__c(
            Name = name,
            Code__c = 'ST' + key.right(6),
            AssetClass__c = 'Diversified',
            RegionalFocus__c = 'Global',
            IsThematic__c = false,
            CurrencyIsoCode = 'EUR'
        );

        insert strategy;
        return strategy;
    }

    // Crée deux stratégies pour couvrir les scénarios multi-strategy.
    public static List<Strategy__c> createStrategies() {
        List<Strategy__c> strategies = new List<Strategy__c>{
            new Strategy__c(
                Name = 'Strategy Test 1',
                Code__c = 'ST001',
                AssetClass__c = 'Diversified',
                RegionalFocus__c = 'Global',
                IsThematic__c = false,
                CurrencyIsoCode = 'EUR'
            ),
            new Strategy__c(
                Name = 'Strategy Test 2',
                Code__c = 'ST002',
                AssetClass__c = 'Diversified',
                RegionalFocus__c = 'Global',
                IsThematic__c = false,
                CurrencyIsoCode = 'EUR'
            )
        };

        insert strategies;
        return strategies;
    }

    // Crée le lien entre une session, un speaker et une stratégie.
    public static SessionSpeakerProduct__c createSessionSpeakerProduct(
        Id eventId,
        Id speakerId,
        Id strategyId
    ) {
        SessionSpeakerProduct__c ssp = new SessionSpeakerProduct__c(
            session__c = eventId,
            speakerContact__c = speakerId,
            strategy__c = strategyId,
            Language__c = 'Italian',
            speakerLanguage__c = 'English',
            presentationStatus__c = 'required',
            ProductTeamBriefingNotes__c = 'Test briefing notes'
        );

        insert ssp;
        return ssp;
    }

    // Crée un attendee lié à un event.
    public static EventAttendee__c createEventAttendee(Id eventId, Id contactId) {
        EventAttendee__c attendee = new EventAttendee__c(
            Event__c = eventId,
            Contact__c = contactId
        );

        insert attendee;
        return attendee;
    }

    // Prépare les données principales utilisées par les tests Bookly.
    public static Map<String, SObject> setupForBookly() {
        Map<String, SObject> data = new Map<String, SObject>();

        User organizer = createOrganizerUser();
        Account company1 = createAccount();
        Strategy__c strategy1 = createStrategy('Strategy1');

        Contact speaker1 = createSpeakerContact(company1.Id, organizer.Id, false);
        Contact speakerTop1 = createSpeakerContact(company1.Id, organizer.Id, true);

        data.put('OrganizerUser', organizer);
        data.put('company1', company1);
        data.put('Strategy1', strategy1);
        data.put('Speaker1', speaker1);
        data.put('SpeakerTop1', speakerTop1);

        return data;
    }

    
   // Crée un organizer admin obligatoire pour Event__c
    public static User createOrganizer() {
        if (cachedOrganizer != null) {
            return cachedOrganizer;
        }

        String key = uniqueKey();

        cachedOrganizer = new User(
            Alias = 'torg',
            Email = 'organizer.' + key + '@test.com',
            Username = 'organizer.' + key + '@test.com',
            LastName = 'Organizer',
            FirstName = 'Test',
            CommunityNickname = 'torg' + key,
            CompanyName = 'INETUM',
            Department = 'DBS',
            Division = 'Digital Transformation',
            Country = 'France',
            CountryCode = 'FR',
            CurrencyIsoCode = 'EUR',
            DefaultCurrencyIsoCode = 'EUR',
            EmailEncodingKey = 'ISO-8859-1',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'fr_FR_EURO',
            TimeZoneSidKey = 'Europe/Paris',
            Team__c = 'France',
            BusinessDevelopmentRegions__c = 'BP_FR',
            Bypass_Duplicate_Rules__c = true,
            BypassValidationRules__c = true,
            Bypass_Flow__c = false,
            BypassProcessBuilders__c = false,
            BypassWorkflowRules__c = false,
            Approver__c = false,
            IsActive = true,
            ProfileId = getAdminProfileId()
        );

        insert cachedOrganizer;
        return cachedOrganizer;
    }

    // Crée un Event__c minimal valide NON inséré
    public static Event__c createEvent() {

        User organizer = createOrganizer();

        return new Event__c(
            Name = '2026-04-30 – IT – qsdqsd – AA',
            Organizer__c = organizer.Id,
            StartDate__c = Date.today(),
            EndDate__c = Date.today(),
            StartTime__c = '15:30',
            EndTime__c = '16:30',
            Title__c = 'qsdqsd',
            Category__c = 'One to One meeting',
            City__c = 'Lisbon',
            Country__c = 'Portugal',
            ClientType__c = 'B2B Buyer',
            Co_hosted__c = 'No',
            SalesTeam__c = 'Italy',
            Format__c = 'Physical',
            TargetedAttendees__c = 0,
            CopyAddress__c = false,
            BypasseApprovals__c = false,
            BypasseNotifications__c = false,
            CoHosted__c = false,
            EventTeamAutoApproved__c = false,
            HOPARequired__c = false,
            IsCarmignacOffice__c = false,
            IsMeetingdays__c = false,
            NoAutomations__c = false,
            Timezone__c = 'Europe/Paris',
            Status__c = 'FullyApproved',
            MeetingBackground__c = 'dqsdqs',
            MeetingGoal__c = 'qsdqsd',
            LocationAddress__c = '6 rue des saules'
        );
    }
}