public with sharing class customEventService {

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
    public static void setEventName(List<Event__c> newEvents, Map<Id, Event__c> oldMap) {
        if (newEvents == null || newEvents.isEmpty()) return;
        for (Event__c e : newEvents) {
            if (!shouldRebuildName(e, oldMap)) continue;
            e.Name = buildEventName(e);
        }
    }

    // Decide whether to rebuild the Name (insert or relevant field changed)
    private static Boolean shouldRebuildName(Event__c e, Map<Id, Event__c> oldMap) {
        if (e == null) return false;
        if (oldMap == null || e.Id == null || !oldMap.containsKey(e.Id)) return true;
        Event__c oldE = oldMap.get(e.Id);
        return hasNameRelevantChange(e, oldE);
    }

    // Compare relevant fields to determine change
    private static Boolean hasNameRelevantChange(Event__c e, Event__c oldE) {
        if (e == null || oldE == null) return true;
        return e.startTime__c != oldE.startTime__c
            || e.SalesTeam__c  != oldE.SalesTeam__c
            || e.Title__c      != oldE.Title__c
            || e.Format__c     != oldE.Format__c;
    }

    // Compose the event name from parts, skipping blanks
    private static String buildEventName(Event__c e) {
        String timePart     = formatTime12hFromText(e.startTime__c);
        String countryPart  = countryToInitials(e.SalesTeam__c);
        String meetingTitle = e.Title__c;
        String formatPart   = toFormatInitial(e.Format__c);
        return joinNonBlank(new List<String>{ timePart, countryPart, meetingTitle, formatPart }, SEP_NAME_PARTS);
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
        if (newEvents == null || newEvents.isEmpty()) return;
        Map<Id, Event__c> oldById = (oldMap == null) ? new Map<Id, Event__c>() : oldMap;

        Eligibility elig = collectEligibility(newEvents, oldById);
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
        return new Map<Id, Account>([
            SELECT Id, Name, BillingStreet, BillingCity, BillingPostalCode, BillingCountry
            FROM Account
            WHERE Id IN :accountIds
        ]);
    }

    // Apply billing info into eligible events
    private static void applyBillingToEligibleEvents(
        List<Event__c> newEvents,
        Set<Id> eligibleEventIds,
        Map<Id, Account> accById
    ) {
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
        e.LocationAddress__c  = a.BillingStreet;
        e.LocationCity__c     = a.BillingCity;
        e.LocationPostCode__c = a.BillingPostalCode;
        e.LocationCountry__c  = a.BillingCountry;
        e.LocationName__c     = a.Name;
    }

    private static Boolean isEventLocationEmpty(Event__c ev) {
        return String.isBlank(ev.LocationAddress__c)
            && String.isBlank(ev.LocationCity__c)
            && String.isBlank(ev.LocationCountry__c)
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

    // Mark events as submitted to event team (only for RecordTypes MeetingDays and Event)
    public static void startEventTeamApproval(List<Event__c> events) {
        if (events == null || events.isEmpty()) return;

        // Collect RecordTypeIds present in the incoming events
        Set<Id> rtIds = new Set<Id>();
        for (Event__c e : events) {
            if (e != null && e.RecordTypeId != null) rtIds.add(e.RecordTypeId);
        }

        // Map RecordTypeId -> DeveloperName (for the Event__c sObject)
        Map<Id, RecordType> rtById = new Map<Id, RecordType>();
        if (!rtIds.isEmpty()) {
            for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE Id IN :rtIds]) {
                rtById.put(rt.Id, rt);
            }
        }

        // Allowed developer names (lowercase to allow case-insensitive compare)
        Set<String> allowedRtDevNames = new Set<String>{ 'meetingdays', 'event' };

        for (Event__c evt : events) {
            if (evt == null) continue;
            // Only set Status__c when the event's RecordType DeveloperName is in the allowed set
            RecordType rt = (evt.RecordTypeId != null) ? rtById.get(evt.RecordTypeId) : null;
            String devName = (rt != null && rt.DeveloperName != null) ? rt.DeveloperName.toLowerCase() : null;
            if (devName != null && allowedRtDevNames.contains(devName)) {
                evt.Status__c = 'SubmittedToEventTeam';
            }
        }
    }

    // AFTER INSERT: submit approval + send notification
    public static void startEventTeamApprovalAfterInsert(List<Event__c> events) {

        if (events == null || events.isEmpty()) return;

        Set<Id> eventIds = new Set<Id>();

        for (Event__c evt : events) {
            if (evt != null && evt.Id != null && evt.Status__c == 'SubmittedToEventTeam') {
                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setObjectId(evt.Id);
                req.setProcessDefinitionNameOrId('EventApprovalProcess');
                Approval.process(req);
                eventIds.add(evt.Id);
            }
        }

        if (!eventIds.isEmpty()) {
            customEventNotificationService.sendApprovalEmails(
                eventIds,
                'EventTeam',
                'EventTeamApproval'
            );
        }

        System.debug('AfterInsert - Approval + Notification processed for ' + eventIds.size() + ' events');
    }
    // ---------------------------
    // Campaign creation from Event__c
    // ---------------------------

    // Create Campaigns when Event.Status__c transitions to 'FullyApproved'
    public static void createCampaign(List<Event__c> newEvents, Map<Id, Event__c> oldMap) {
        if (newEvents == null || newEvents.isEmpty()) return;

        List<Event__c> eligibleEvents = detectBecameFullyApproved(newEvents, oldMap);
        if (eligibleEvents.isEmpty()) return;

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
        c.City__c          = e.LocationCity__c;
        c.Country__c       = e.LocationCountry__c;
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

}