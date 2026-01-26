public with sharing class customEventService {

    // ---------------------------------------------------------------------
    // Constants (avoid duplicated literals / keep intent clear)
    // ---------------------------------------------------------------------
    private static final String SEP_NAME_PARTS = ' – ';
    private static final String EMPTY = '';

    // Builds the Name automatically from time, country, user title and format
    // Refactor target: reduce Cognitive Complexity (25 -> <= 15)
    public static void setEventName(List<Event__c> newEvents, Map<Id, Event__c> oldMap) {
        if (newEvents == null || newEvents.isEmpty()) return;

        for (Event__c e : newEvents) {
            if (!shouldRebuildName(e, oldMap)) continue;

            String timePart     = formatTime12hFromText(e.startTime__c); // from Text HH:MM
            String countryPart  = countryToInitials(e.SalesTeam__c);
            String meetingTitle = e.Title__c;
            String formatPart   = toFormatInitial(e.Format__c);

            e.Name = joinNonBlank(new List<String>{ timePart, countryPart, meetingTitle, formatPart }, SEP_NAME_PARTS);
        }
    }

    private static Boolean shouldRebuildName(Event__c e, Map<Id, Event__c> oldMap) {
        if (e == null) return false;

        // Insert: always build
        if (oldMap == null || e.Id == null || !oldMap.containsKey(e.Id)) return true;

        // Update: only build if relevant fields changed
        Event__c oldE = oldMap.get(e.Id);
        return hasNameRelevantChange(e, oldE);
    }

    private static Boolean hasNameRelevantChange(Event__c e, Event__c oldE) {
        if (e == null || oldE == null) return true;
        return e.startTime__c != oldE.startTime__c
            || e.SalesTeam__c  != oldE.SalesTeam__c
            || e.Title__c      != oldE.Title__c
            || e.Format__c     != oldE.Format__c;
    }

    private static String toFormatInitial(String formatRaw) {
        if (String.isBlank(formatRaw)) return EMPTY;

        String f = formatRaw.trim().toUpperCase();
        if (String.isBlank(f)) return EMPTY;

        // Keep original logic: D* => D, P* => P, else first letter
        if (f.startsWith('D')) return 'D';
        if (f.startsWith('P')) return 'P';
        return f.substring(0, 1);
    }

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

        // Apex-safe zero padding
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
        } catch (Exception e) {
            return null;
        }
    }

    // ==========================
    // Legacy Helpers (kept)
    // ==========================

    // Formats a Datetime in 12h format (e.g. 2pm or 2:30pm)
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

    // Converts SalesTeam value into country initials (FR, BE, NL, ...)
    private static String countryToInitials(String countryRaw) {
        if (String.isBlank(countryRaw)) return '';

        Map<String,String> mapC = new Map<String,String>{
            'Belgium'     => 'BE',
            'Luxembourg'  => 'LU',
            'Netherlands' => 'NL',
            'France'      => 'FR',
            'Germany'     => 'DE',
            'Italy'       => 'IT',
            'Spain'       => 'ES'
        };

        String key = countryRaw.trim();
        if (mapC.containsKey(key)) {
            return mapC.get(key);
        }

        String out = '';
        for (String w : countryRaw.toUpperCase().split('\\s+')) {
            if (!String.isBlank(w)) out += w.substring(0, 1);
            if (out.length() >= 3) break;
        }
        return out;
    }

    /**
     * If Event__c.CopyAddress__c = true and location fields are empty,
     * copy BillingAddress from Company__c (Account) into Event__c location fields.
     *
     * Update triggers ONLY when:
     * - CopyAddress__c changes from false -> true
     *   OR
     * - Company__c changes AND CopyAddress__c is true
     *
     * Runs in BEFORE insert/update .
     *
     * Refactor target: reduce Cognitive Complexity (44 -> <= 15)
     */
    public static void copyCompanyBillingAddressToEvent(List<Event__c> newEvents, Map<Id, Event__c> oldMap) {
        if (newEvents == null || newEvents.isEmpty()) return;

        Map<Id, Event__c> oldById = (oldMap == null) ? new Map<Id, Event__c>() : oldMap;

        // 1) Determine eligible events + collect account ids
        Eligibility elig = collectEligibility(newEvents, oldById);
        if (elig.accountIds.isEmpty()) return;

        // 2) Query accounts once
        Map<Id, Account> accById = queryAccounts(elig.accountIds);

        // 3) Copy in-memory for eligible events
        applyBillingToEligibleEvents(newEvents, elig.eligibleEventIds, accById);
    }

    // ---------------------------------------------------------------------
    // Eligibility model
    // ---------------------------------------------------------------------
    private class Eligibility {
        Set<Id> eligibleEventIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
    }

    private static Eligibility collectEligibility(List<Event__c> newEvents, Map<Id, Event__c> oldById) {
        Eligibility out = new Eligibility();

        for (Event__c e : newEvents) {
            if (!isBaseCopyCandidate(e)) continue;

            Boolean eligible = isInsert(e, oldById) || isUpdateTriggerConditionMet(e, oldById);
            if (!eligible) continue;

            out.eligibleEventIds.add(e.Id);      // Note: may be null for before-insert; still ok for apply step checks
            out.accountIds.add(e.Company__c);
        }

        return out;
    }

    private static Boolean isBaseCopyCandidate(Event__c e) {
        if (e == null) return false;
        if (e.CopyAddress__c != true) return false;
        if (!isEventLocationEmpty(e)) return false;
        if (e.Company__c == null) return false;
        return true;
    }

    private static Boolean isInsert(Event__c e, Map<Id, Event__c> oldById) {
        // before insert (Id null) OR no old record present
        return e.Id == null || oldById == null || !oldById.containsKey(e.Id);
    }

    private static Boolean isUpdateTriggerConditionMet(Event__c e, Map<Id, Event__c> oldById) {
        if (e == null || e.Id == null) return false;
        if (oldById == null || !oldById.containsKey(e.Id)) return false;

        Event__c oldE = oldById.get(e.Id);
        Boolean copyJustEnabled = (oldE.CopyAddress__c != true) && (e.CopyAddress__c == true);
        Boolean companyChangedWhileCopyEnabled = (oldE.Company__c != e.Company__c) && (e.CopyAddress__c == true);

        return copyJustEnabled || companyChangedWhileCopyEnabled;
    }

    private static Map<Id, Account> queryAccounts(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) return new Map<Id, Account>();

        return new Map<Id, Account>([
            SELECT Id, Name, BillingStreet, BillingCity, BillingPostalCode, BillingCountry
            FROM Account
            WHERE Id IN :accountIds
        ]);
    }

    private static void applyBillingToEligibleEvents(
        List<Event__c> newEvents,
        Set<Id> eligibleEventIds,
        Map<Id, Account> accById
    ) {
        if (newEvents == null || newEvents.isEmpty()) return;
        if (accById == null || accById.isEmpty()) return;

        for (Event__c e : newEvents) {
            if (!isBaseCopyCandidate(e)) continue;

            // For inserts (Id null), the eligibility set may not contain null.
            // So: if Id is non-null, enforce membership; if Id is null, just proceed (it was eligible by base rules).
            if (e.Id != null && eligibleEventIds != null && !eligibleEventIds.contains(e.Id)) continue;

            Account a = accById.get(e.Company__c);
            if (a == null || isAccountBillingEmpty(a)) continue;

            copyBillingToEvent(e, a);
        }
    }

    private static void copyBillingToEvent(Event__c e, Account a) {
        e.LocationAddress__c  = a.BillingStreet;
        e.LocationCity__c     = a.BillingCity;
        e.LocationPostCode__c = a.BillingPostalCode;
        e.LocationCountry__c  = a.BillingCountry;
        e.LocationName__c     = a.Name;
    }

    // Helpers (add if not already present in this class)
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

    public static void startEventTeamApproval(List<Event__c> events) {
        if (events == null || events.isEmpty()) return;

        for (Event__c evt : events) {
            if (evt == null) continue;

            // Mettre en place la logique pour vérifier si l'utilisateur fait partie de l'Event Team
            evt.Status__c = 'SubmittedToEventTeam';
         }
    }
}