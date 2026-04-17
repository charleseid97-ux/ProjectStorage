public without sharing class customEventService {

    // Constants
    private static final String SEP_NAME_PARTS = ' – ';
    private static final String EMPTY = '';

    // Country lookup as a single static map to avoid re-creation
    private static final Map<String,String> COUNTRY_MAP = new Map<String,String>{
        'Belgium'         => 'BE',
        'Luxembourg'      => 'LU',
        'Netherlands'     => 'NL',
        'France'          => 'FR',
        'Germany'         => 'DE',
        'Italy'           => 'IT',
        'Spain'           => 'ES',
        'United Kingdom'  => 'GB',
        'Switzerland'     => 'CH',
        'Us Offshore'     => 'XU',
        'Sweden'          => 'SE',
        'All Countries'   => 'XA',
        'Andorra'         => 'AD',
        'Argentina'       => 'AR',
        'Austria'         => 'AT',
        'Bahamas'         => 'BS',
        'Brazil'          => 'BR',
        'Canada'          => 'CA',
        'DCP'             => 'XD',
        'Denmark'         => 'DK',
        'Finland'         => 'FI',
        'Gibraltar'       => 'GI',
        'Hong Kong'       => 'HK',
        'Ireland'         => 'IE',
        'Isle of Man'     => 'IM',
        'Japan'           => 'JP',
        'Jersey'          => 'JE',
        'Liechtenstein'   => 'LI',
        'Malta'           => 'MT',
        'Norway'          => 'NO',
        'Panama'          => 'PA',
        'Portugal'        => 'PT',
        'Qatar'           => 'QA',
        'Saudi Arabia'    => 'SA',
        'Singapore'       => 'SG',
        'South Africa'    => 'ZA',
        'Taiwan'          => 'TW',
        'Uruguay'         => 'UY',
        'Latvia'          => 'LV',
        'Lithuania'       => 'LT'
    };

    // ---------------------------
    // Event Name construction
    // ---------------------------

    // Build event Name from time, country, title and format
    public static void setEventName(List<Event__c> events, Boolean isInit) {
        if (events == null || events.isEmpty()) return;

        Map<Id, String> eventToSpeakers = isInit ? new Map<Id, String>() : getSpeakers(events);

        for (Event__c e : events) {
            String datePart    = (e.startDate__c != null) ? String.valueOf(e.startDate__c) : null;
            String countryPart = countryToInitials(e.SalesTeam__c);
            String titlePart   = e.Title__c;
            String speakerPart = isInit ? null : eventToSpeakers.get(e.Id);

            e.Name = joinNonBlank(
                new List<String>{ datePart, countryPart, titlePart, speakerPart },
                SEP_NAME_PARTS
            );
        }
    }

  



    // ---------------------------
    // Helpers: format / join / parse
    // ---------------------------

    // Convert format picklist to single-character initial
    private static String toFormatInitial(String formatRaw) {
        if (String.isBlank(formatRaw)) return EMPTY;
        String f = formatRaw.trim().toUpperCase();
        if (String.isBlank(f)) return EMPTY;
        if (f.startsWith('D')) return 'D';
        if (f.startsWith('P')) return 'P';
        return f.substring(0, 1);
    }

    // Join non-blank parts with separator
    private static String joinNonBlank(List<String> parts, String sep) {
        if (parts == null || parts.isEmpty()) return EMPTY;
        List<String> kept = new List<String>();
        for (String p : parts) {
            if (!String.isBlank(p)) kept.add(p);
        }
        return kept.isEmpty() ? EMPTY : String.join(kept, sep);
    }

    /**
     * Input: "HH:MM" or "HH:MM:SS"
     * Output: "h:MM AM/PM" (ex: "1:05 PM")
     */
    private static String formatTime12hFromText(String timeTxt) {
        if (String.isBlank(timeTxt)) return null;
        List<Integer> parts = parseTimeParts(timeTxt);
        if (parts == null || parts.size() < 2) return null;
        Integer hh = parts[0];
        Integer mm = parts[1];
        if (hh == null || mm == null) return null;
        if (hh < 0 || hh > 23) return null;
        if (mm < 0 || mm > 59) return null;
        String ampm = (hh >= 12) ? 'PM' : 'AM';
        Integer h12 = Math.mod(hh, 12);
        if (h12 == 0) h12 = 12;
        String mmStr = (mm < 10 ? '0' : '') + String.valueOf(mm);
        return String.valueOf(h12) + ':' + mmStr + ' ' + ampm;
    }

    // Accept "HH:MM" or "HH:MM:SS"
    private static List<Integer> parseTimeParts(String timeTxt) {
        if (String.isBlank(timeTxt)) return null;
        String v = timeTxt.trim();
        if (!v.contains(':')) return null;
        List<String> seg = v.split(':');
        if (seg.size() < 2) return null;
        try {
            Integer hh = Integer.valueOf(seg[0]);
            Integer mm = Integer.valueOf(seg[1]);
            Integer ss = (seg.size() >= 3) ? Integer.valueOf(seg[2]) : 0;
            return new List<Integer>{ hh, mm, ss };
        } catch (Exception ex) {
            return null;
        }
    }

    // Legacy helper: format Datetime -> 12h string (kept for compatibility)
    private static String formatTime12h(Datetime dt) {
        if (dt == null) return '';
        Time t = dt.time();
        Integer h = t.hour();
        Integer m = t.minute();
        String ampm = (h >= 12) ? 'pm' : 'am';
        Integer h12 = Math.mod(h, 12);
        if (h12 == 0) h12 = 12;
        return (m == 0)
            ? String.valueOf(h12) + ampm
            : String.valueOf(h12) + ':' + two(m) + ampm;
    }

    private static String two(Integer v) {
        return (v < 10) ? '0' + String.valueOf(v) : String.valueOf(v);
    }

    // ---------------------------
    // Country mapping
    // ---------------------------

    // Convert SalesTeam label to country initials
    private static String countryToInitials(String countryRaw) {
        if (String.isBlank(countryRaw)) return '';
        String key = countryRaw.trim();
        if (COUNTRY_MAP.containsKey(key)) {
            return COUNTRY_MAP.get(key);
        }
        // Fallback: take initials from words (max 3 chars)
        String out = '';
        for (String w : countryRaw.toUpperCase().split('\\s+')) {
            if (!String.isBlank(w)) out += w.substring(0, 1);
            if (out.length() >= 3) break;
        }
        return out;
    }

    // ---------------------------
    // Copy billing address logic
    // ---------------------------

    public static void copyCompanyBillingAddressToEvent(List<Event__c> newEvents, Map<Id, Event__c> oldMap) {
        system.debug('=====copyCompanyBillingAddressToEvent started');
        if (newEvents == null || newEvents.isEmpty()) return;
        Map<Id, Event__c> oldById = (oldMap == null) ? new Map<Id, Event__c>() : oldMap;

        Eligibility elig = collectEligibility(newEvents, oldById);
        system.debug('=====Eligibility collected: ' + elig.eligibleEventIds.size() + ' eligible events, ' + elig.accountIds.size() + ' unique accounts');
        if (elig.accountIds.isEmpty()) return;

        Map<Id, Account> accById = queryAccounts(elig.accountIds);
        applyBillingToEligibleEvents(newEvents, elig.eligibleEventIds, accById);
    }

    // Model grouping event eligibility and account ids
    private class Eligibility {
        Set<Id> eligibleEventIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
    }

    // Determine which events are eligible and collect account ids
    private static Eligibility collectEligibility(List<Event__c> newEvents, Map<Id, Event__c> oldById) {
        Eligibility out = new Eligibility();
        for (Event__c e : newEvents) {
            if (!isBaseCopyCandidate(e)) continue;
            Boolean eligible = isInsert(e, oldById) || isUpdateTriggerConditionMet(e, oldById);
            if (!eligible) continue;
            out.eligibleEventIds.add(e.Id);
            out.accountIds.add(e.Company__c);
        }
        return out;
    }

    // Basic checks for copy candidate
    private static Boolean isBaseCopyCandidate(Event__c e) {
        if (e == null) return false;
        if (e.CopyAddress__c != true) return false;
        if (!isEventLocationEmpty(e)) return false;
        if (e.Company__c == null) return false;
        return true;
    }

    // Determine if record is an insert
    private static Boolean isInsert(Event__c e, Map<Id, Event__c> oldById) {
        return e.Id == null || oldById == null || !oldById.containsKey(e.Id);
    }

    // Determine update trigger conditions
    private static Boolean isUpdateTriggerConditionMet(Event__c e, Map<Id, Event__c> oldById) {
        if (e == null || e.Id == null) return false;
        if (oldById == null || !oldById.containsKey(e.Id)) return false;
        Event__c oldE = oldById.get(e.Id);
        Boolean copyJustEnabled = (oldE.CopyAddress__c != true) && (e.CopyAddress__c == true);
        Boolean companyChangedWhileCopyEnabled = (oldE.Company__c != e.Company__c) && (e.CopyAddress__c == true);
        return copyJustEnabled || companyChangedWhileCopyEnabled;
    }

    // Query Accounts by collected ids
    private static Map<Id, Account> queryAccounts(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) return new Map<Id, Account>();
        List<Account> accounts = [
            SELECT Id, Name, BillingStreet, BillingCity, BillingPostalCode, BillingCountry
            FROM Account
            WHERE Id IN :accountIds
            WITH SECURITY_ENFORCED
        ];
        accounts = (List<Account>)Security.stripInaccessible(AccessType.READABLE, accounts).getRecords();
        return new Map<Id, Account>(accounts);
    }

    // Apply billing info into eligible events
    private static void applyBillingToEligibleEvents(
        List<Event__c> newEvents,
        Set<Id> eligibleEventIds,
        Map<Id, Account> accById
    ) {
        system.debug('=====Applying billing to eligible events, count=' + ((newEvents != null) ? newEvents.size() : 0) + ', eligibleEventIds=' + eligibleEventIds + ', accById size=' + ((accById != null) ? accById.size() : 0));
        if (newEvents == null || newEvents.isEmpty()) return;
        if (accById == null || accById.isEmpty()) return;

        for (Event__c e : newEvents) {
            if (!isBaseCopyCandidate(e)) continue;
            if (e.Id != null && eligibleEventIds != null && !eligibleEventIds.contains(e.Id)) continue;

            Account a = accById.get(e.Company__c);
            if (a == null || isAccountBillingEmpty(a)) continue;
            copyBillingToEvent(e, a);
        }
    }

    // Copy account billing fields into event fields
    private static void copyBillingToEvent(Event__c e, Account a) {
        system.debug('=====Copying billing from account ' + a.Id + ' to event ' + e.Id);
        e.LocationAddress__c  = a.BillingStreet;
        e.city__c     = a.BillingCity;
        e.LocationPostCode__c = a.BillingPostalCode;
        e.country__c  = a.BillingCountry;
        e.LocationName__c     = a.Name;
    }

    private static Boolean isEventLocationEmpty(Event__c ev) {
        return String.isBlank(ev.LocationAddress__c)
            && String.isBlank(ev.city__c)
            && String.isBlank(ev.country__c)
            && String.isBlank(ev.LocationPostCode__c)
            && String.isBlank(ev.LocationName__c);
    }

    private static Boolean isAccountBillingEmpty(Account a) {
        return String.isBlank(a.BillingStreet)
            && String.isBlank(a.BillingCity)
            && String.isBlank(a.BillingPostalCode)
            && String.isBlank(a.BillingCountry);
    }

    // ---------------------------
    // Event Team / Approval helper
    // ---------------------------
    // BEFORE UPDATE:
    // When events are created, speakers are not yet linked, so Name is incomplete.
    // Once speakers are added (after insert), the record is updated → we recompute Name
    // and move the status from Draft to SubmittedToEventTeam.
    // The actual approval submission must happen in AFTER UPDATE.
    public static void setReadyForApprovalProcess(List<Event__c> events, Map<Id, Event__c> oldMap) {
        if (events == null || events.isEmpty() || oldMap == null || oldMap.isEmpty()) {
            return;
        }

        // Recompute name with speakers now available
        setEventName(events, false);

        for (Event__c evt : events) {
            if (evt == null || evt.Id == null) continue;

            Event__c oldEvt = oldMap.get(evt.Id);
            if (oldEvt == null) continue;

            // If still Draft after update → ready to be submitted
            if (oldEvt.Status__c == 'Draft' && evt.Status__c == 'Draft') {
                evt.Status__c = 'SubmittedToEventTeam';
            }
        }
    }
    // AFTER INSERT: submit approval + send notification
    public static void startEventTeamApprovalAfterUpdate(List<Event__c> events,Map<Id, Event__c> oldMap) {
        

        if (events == null || events.isEmpty()) return;


        for (Event__c evt : events) {
            if (evt != null && evt.Id != null && evt.Status__c == 'SubmittedToEventTeam' && oldMap.get(evt.Id).Status__c != 'SubmittedToEventTeam' ) {
                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setObjectId(evt.Id);
                req.setProcessDefinitionNameOrId('EventApprovalProcess');
                Approval.process(req);
            }
        }
    }
    // ---------------------------
    // Campaign creation from Event__c
    // ---------------------------

    // Create Campaigns when Event.Status__c transitions to 'FullyApproved'
    public static void createCampaign(List<Event__c> newEvents, Map<Id, Event__c> oldMap) {
        if (newEvents == null || newEvents.isEmpty()) return;

        List<Event__c> eligibleEvents = detectBecameFullyApproved(newEvents, oldMap);
        if (eligibleEvents.isEmpty()) return;
        eligibleEvents = (List<Event__c>)Security.stripInaccessible(AccessType.READABLE, eligibleEvents).getRecords();

        List<Campaign> campaignsToInsert = new List<Campaign>();
        Map<Id, Campaign> eventIdToCampaign = new Map<Id, Campaign>();

        for (Event__c e : eligibleEvents) {
            Campaign c = buildCampaignFromEvent(e);
            campaignsToInsert.add(c);
            eventIdToCampaign.put(e.Id, c);
        }
        System.debug('[customEventService.createCampaign] Inserting ' + campaignsToInsert );
        insert campaignsToInsert;

        // Link created campaigns back on events
        linkCampaignsToEvents(eventIdToCampaign, eligibleEvents);
    }

    // Detect transition to FullyApproved and avoid duplicates
    private static List<Event__c> detectBecameFullyApproved(List<Event__c> newEvents, Map<Id, Event__c> oldMap) {
        List<Event__c> out = new List<Event__c>();
        for (Event__c e : newEvents) {
            if (e == null) continue;
            Event__c oldE = (oldMap != null) ? oldMap.get(e.Id) : null;
            Boolean becameFullyApproved =
                e.Status__c == 'FullyApproved' &&
                (oldE == null || oldE.Status__c != 'FullyApproved');
            if (becameFullyApproved && e.Campaign__c == null) out.add(e);
        }
        return out;
    }

    // Build a Campaign record from an Event__c
    private static Campaign buildCampaignFromEvent(Event__c e) {
        Campaign c = new Campaign();
        // Record Type
        c.RecordTypeId = Schema.SObjectType.Campaign
        .getRecordTypeInfosByDeveloperName()
        .get('Event_and_Meeting')
        .getRecordTypeId();

        // Name
        String timePart    = formatTime12hFromText(e.startTime__c);
        String countryPart = countryToInitials(e.SalesTeam__c);
        c.Name = joinNonBlank(
            new List<String>{ timePart, countryPart, e.Title__c, toFormatInitial(e.Format__c) },
            SEP_NAME_PARTS
        );

        // Dates
        c.StartDate = e.startDate__c;
        c.EndDate   = (e.endDate__c != null) ? e.endDate__c : e.startDate__c;

        // Defaults
        c.Type   = 'Nurturing';
        c.Status = 'Email Sent';

        // Datetime mapping
        Datetime startDt = buildDatetimeFromDateAndTextTime(e.startDate__c, e.startTime__c);
        Datetime endDt   = buildDatetimeFromDateAndTextTime(
            (e.endDate__c != null) ? e.endDate__c : e.startDate__c,
            e.endTime__c
        );
        if (startDt != null) c.Start_Date_Time__c = startDt;
        if (endDt   != null) c.End_Date_Time__c   = endDt;

        // Location mapping
        c.Address_1__c     = e.LocationAddress__c;
        c.City__c          = e.city__c;
        c.Country__c       = e.country__c;
        c.Post_Code__c     = e.LocationPostCode__c;
        c.Location_name__c = e.LocationName__c;

        // Ownership/context
        c.Company__c    = e.Company__c;
       // c.Sales_Team__c = resolveCampaignSalesTeam(e.SalesTeam__c);
        if (!String.isBlank(e.Language__c)) c.Language__c = e.Language__c;

        // Description composition
        String descr = '';
        if (!String.isBlank(e.MeetingGoal__c))       descr += 'Goal:\n' + e.MeetingGoal__c + '\n\n';
        if (!String.isBlank(e.MeetingBackground__c)) descr += 'Background:\n' + e.MeetingBackground__c + '\n\n';
        if (!String.isBlank(e.Description__c))       descr += 'Rationale:\n' + e.Description__c + '\n\n';
        c.Description = String.isBlank(descr) ? null : descr.trim();

        // Flags from example
        c.Product__c            = true;
        c.Professionnal_only__c = true;

        return c;
    }

    // Link created campaigns back to Event__c records
    private static void linkCampaignsToEvents(Map<Id, Campaign> eventIdToCampaign, List<Event__c> eligibleEvents) {
        List<Event__c> eventsToUpdate = new List<Event__c>();
        for (Event__c e : eligibleEvents) {
            Campaign created = eventIdToCampaign.get(e.Id);
            if (created == null) continue;
            eventsToUpdate.add(new Event__c(
                Id = e.Id,
                Campaign__c = created.Id
            ));
        }
        if (!eventsToUpdate.isEmpty()) update eventsToUpdate;
    }

    // ---------------------------
    // Datetime builder
    // ---------------------------

    // Build Datetime from Date and "HH:MM" or "HH:MM:SS" text
    private static Datetime buildDatetimeFromDateAndTextTime(Date d, String timeTxt) {
        if (d == null || String.isBlank(timeTxt)) return null;
        List<Integer> parts = parseTimeParts(timeTxt);
        if (parts == null || parts.size() < 2) return null;

        Integer hh = parts[0];
        Integer mm = parts[1];
        Integer ss = (parts.size() >= 3 && parts[2] != null) ? parts[2] : 0;

        if (hh == null || mm == null) return null;
        if (hh < 0 || hh > 23) return null;
        if (mm < 0 || mm > 59) return null;
        if (ss < 0 || ss > 59) return null;

        Time t = Time.newInstance(hh, mm, ss, 0);
        return Datetime.newInstance(d, t);
    }

    // ---------------------------
    // Campaign Sales Team resolution
    // ---------------------------

    // Get active picklist values for Campaign.Sales_Team__c
    private static Set<String> getCampaignSalesTeamAllowedValues() {
        Set<String> allowed = new Set<String>();
        Schema.DescribeFieldResult d =
            Campaign.SObjectType.getDescribe()
                .fields.getMap()
                .get('Sales_Team__c')
                .getDescribe();
        for (Schema.PicklistEntry pe : d.getPicklistValues()) {
            if (pe.isActive()) allowed.add(pe.getValue());
        }
        return allowed;
    }

    // Resolve Campaign Sales Team ensuring it matches the Campaign picklist
    private static String resolveCampaignSalesTeam(String eventSalesTeam) {
        if (String.isBlank(eventSalesTeam)) return null;
        Set<String> allowed = getCampaignSalesTeamAllowedValues();
        String value = eventSalesTeam.trim();
        if (allowed.contains(value)) return value;
        String initials = countryToInitials(value);
        if (!String.isBlank(initials) && allowed.contains(initials)) return initials;
        return null;
    }
    // set automatic location for digital events, and remove it if format is changed from digital to something else
    public static void setDigitalLocation(List<Event__c> newEvents, Map<Id, Event__c> oldMap) {
        newEvents =  newEvents  ;
        for (Event__c ev : newEvents) {

            if (oldMap == null) {
                if (ev.Format__c == 'Digital') {
                    ev.country__c = 'Digital';
                    ev.City__c = 'Digital';
                }
            } else {
                Event__c oldEv = oldMap.get(ev.Id);

                Boolean formatChanged = oldEv.Format__c != ev.Format__c;

                if (formatChanged && ev.City__c == 'Digital') {
                    ev.City__c = null;
                    ev.country__c = null;
                }
            }
        }
    }

    public static Map<Id, String> getSpeakers(List<Event__c> events) {
        Set<Id> eventIds = new Set<Id>();
        for (Event__c e : events) {
            if (e.Id != null) eventIds.add(e.Id);
        }

        Map<Id, Set<String>> tmp = new Map<Id, Set<String>>();

        for (SessionSpeakerProduct__c s : [
            SELECT Session__c, SpeakerContact__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :eventIds
            AND SpeakerContact__c != null
        ]) {
            if (!tmp.containsKey(s.Session__c)) {
                tmp.put(s.Session__c, new Set<String>());
            }
            tmp.get(s.Session__c).add(getSpeakerInitials(s.SpeakerContact__r.Name));
        }

        Map<Id, String> res = new Map<Id, String>();
        for (Id eid : tmp.keySet()) {
            List<String> vals = new List<String>(tmp.get(eid));
            vals.sort();
            res.put(eid, String.join(vals, '/'));
        }
        return res;
    }

    public static String getSpeakerInitials(String fullName) {
        if (String.isBlank(fullName)) {
            return null;
        }

        List<String> p = fullName.trim().split('\\s+');
        if (p.size() < 2) {
            return null;
        }

        String firstInitial = p[0].substring(0, 1);
        String lastInitial  = p[p.size() - 1].substring(0, 1);

        return (firstInitial + lastInitial).toUpperCase();
    }

    public static void updateName(Map<Id, Event__c> oldMap, Map<Id, Event__c> newMap) {
        List<Event__c> toUpdate = new List<Event__c>();

        for (Event__c e : newMap.values()) {
            Event__c oldE = oldMap.get(e.Id);
            if (oldE == null) continue;

            if (
                e.startDate__c != oldE.startDate__c ||
                e.SalesTeam__c != oldE.SalesTeam__c ||
                e.Title__c     != oldE.Title__c
            ) {
                toUpdate.add(e);
            }
        }

        if (!toUpdate.isEmpty()) {
            setEventName(toUpdate, false);
        }
    }

    /**
     * Generic validation method for Event__c records.
     * Used in before insert/update to enforce business rules.
     */
    public static void validateEvents(List<Event__c> records, Map<Id, Event__c> oldMap) {
        if (records == null || records.isEmpty()) return;

        for (Event__c rec : records) {
            // Ensure Organizer is always populated
            if (rec.Organizer__c == null) {
                rec.addError('Organizer is required.');
            }
        }
    }

    // ---------------------------
    // Timezone via LocationTimezoneResolver
    // ---------------------------
    public static void setTimeZone(List<Event__c> events) {
        if (events == null || events.isEmpty()) return;

        for (Event__c ev : events) {
            if (ev == null) continue;

            //  ne rien faire si déjà renseigné
            if (!String.isBlank(ev.TimeZone__c)) continue;

            // skip si pas de données
            if (String.isBlank(ev.country__c) && String.isBlank(ev.city__c)) continue;

            LocationTimezoneResolver.Result res =
                LocationTimezoneResolver.resolve(ev.country__c, ev.city__c);

            if (res != null && !String.isBlank(res.timezoneId)) {
                ev.TimeZone__c = res.timezoneId;
            }
        }
    }
}