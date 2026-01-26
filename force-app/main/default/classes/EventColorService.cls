public with sharing class EventColorService {

    /**
     * Internal wrapper storing the three color variations
     * associated with a particular Sales Team.
     *
     * meetingColor  → Light tone, applied to "Meeting Days" records
     * oneToOneColor → Medium tone, applied to "One-to-one" meeting records
     * eventColor    → Dark tone, applied to "Event" records
     */
    private class SalesTeamColors {
        String meetingColor;
        String oneToOneColor;
        String eventColor;
    }

    /**
     * Cache storing the color configuration indexed by SalesTeam__c (uppercase key).
     * This avoids repeated queries when many events must be processed.
     */
    private static Map<String, SalesTeamColors> COLORS_BY_SALESTEAM;

    /**
     * Loads color configuration from EventColors__c and stores
     * the result in an in-memory cache. This ensures efficient reuse.
     */
    private static Map<String, SalesTeamColors> getColorsBySalesTeam() {

        if (COLORS_BY_SALESTEAM == null) {
            COLORS_BY_SALESTEAM = new Map<String, SalesTeamColors>();

            for (EventColors__c cs : [
                SELECT SalesTeam__c, meetingDays__c, oneToOne__c, event__c
                FROM EventColors__c
            ]) {
                if (String.isBlank(cs.SalesTeam__c)) {
                    continue;
                }

                SalesTeamColors colors = new SalesTeamColors();
                colors.meetingColor  = normalizeHex(cs.meetingDays__c);
                colors.oneToOneColor = normalizeHex(cs.oneToOne__c);
                colors.eventColor    = normalizeHex(cs.event__c);

                COLORS_BY_SALESTEAM.put(cs.SalesTeam__c.trim().toUpperCase(), colors);
            }
        }

        return COLORS_BY_SALESTEAM;
    }

    /**
     * Applies the color logic directly in memory to a list of Event__c records.
     * No DML operations are performed.
     *
     * Colors are assigned based on:
     *  - the SalesTeam__c value of the event
     *  - the RecordType DeveloperName
     *
     * DeveloperName mapping:
     *  • "MeetingDays" → meetingDays__c (light tone)
     *  • "Meeting"     → oneToOne__c (medium tone)
     *  • "event"       → event__c (dark tone)
     *
     * The method is intended to be used before sending data to the UI
     * or prior to performing DML operations in triggers.
     */
    public static void applyColorsInMemory(List<Event__c> events) {

        if (events == null || events.isEmpty()) {
            return;
        }

        Map<String, SalesTeamColors> configuredColors = getColorsBySalesTeam();

        // Lookup of RecordTypes using Describe API.
        // No SOQL is required, which ensures governor efficiency and deployment portability.
        Map<String, Schema.RecordTypeInfo> rtInfos =
            Event__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();

        Schema.RecordTypeInfo rtEvent       = rtInfos.get('event');
        Schema.RecordTypeInfo rtMeetingDays = rtInfos.get('MeetingDays');
        Schema.RecordTypeInfo rtOneToOne    = rtInfos.get('Meeting');

        Id EVENT_RT_ID       = rtEvent != null       ? rtEvent.getRecordTypeId()       : null;
        Id MEETINGDAYS_RT_ID = rtMeetingDays != null ? rtMeetingDays.getRecordTypeId() : null;
        Id ONETOONE_RT_ID    = rtOneToOne != null    ? rtOneToOne.getRecordTypeId()    : null;

        for (Event__c e : events) {

            // A Sales Team must be defined to determine colors
            if (String.isBlank(e.SalesTeam__c)) {
                continue;
            }

            SalesTeamColors colors =
                configuredColors.get(e.SalesTeam__c.trim().toUpperCase());

            if (colors == null) {
                // No color configuration exists for this Sales Team
                continue;
            }

            String selectedColor;

            // Assignment based on RecordType mapping
            if (e.RecordTypeId == MEETINGDAYS_RT_ID) {
                selectedColor = colors.meetingColor;
            }
            else if (e.RecordTypeId == ONETOONE_RT_ID) {
                selectedColor = colors.oneToOneColor;
            }
            else if (e.RecordTypeId == EVENT_RT_ID) {
                selectedColor = colors.eventColor;
            }
            else {
                // Unsupported or unmanaged RecordType
                continue;
            }

            if (!String.isBlank(selectedColor)) {
                e.Color__c = selectedColor;
            }
        }
    }

    /**
     * Normalizes a hex color string by ensuring it is prefixed with '#'
     * and converted to upper-case. Returns null for empty input.
     */
    private static String normalizeHex(String hex) {
        if (String.isBlank(hex)) {
            return null;
        }
        String h = hex.trim();
        if (!h.startsWith('#')) {
            h = '#' + h;
        }
        return h.toUpperCase();
    }
}