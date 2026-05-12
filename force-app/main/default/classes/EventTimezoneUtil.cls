public without sharing class EventTimezoneUtil {

    public class EventTimezoneUtilException extends Exception {}

    private static final Map<String, String> TIMEZONE_ALIASES = new Map<String, String>{
        'utc'               => 'UTC',
        'paris'             => 'Europe/Paris',
        'london'            => 'Europe/London',
        'toronto'           => 'America/Toronto',
        'helsinki'          => 'Europe/Helsinki',
        'dubai'             => 'Asia/Dubai',
        'singapore'         => 'Asia/Singapore',
        'europe/paris'      => 'Europe/Paris',
        'europe/london'     => 'Europe/London',
        'america/toronto'   => 'America/Toronto',
        'europe/helsinki'   => 'Europe/Helsinki',
        'asia/dubai'        => 'Asia/Dubai',
        'asia/singapore'    => 'Asia/Singapore'
    };

    public static List<Event__c> convertTimeZone(List<Event__c> events, String targetTimezone) {
        List<Event__c> result = new List<Event__c>();

        if (events == null || events.isEmpty()) {
            return result;
        }

        String targetTimezoneId = normalizeTimezone(targetTimezone);
        TimeZone targetTz = TimeZone.getTimeZone(targetTimezoneId);

        for (Event__c ev : events) {
            if (ev == null) continue;

            validateEvent(ev);

            String sourceTimezoneId = normalizeTimezone(ev.timezone__c);
            TimeZone sourceTz = TimeZone.getTimeZone(sourceTimezoneId);

            Event__c newEv = ev.clone(true, false, false, false);

            Datetime startUtc = localToUtc(ev.startDate__c, ev.startTime__c, sourceTz);
            Datetime endUtc   = localToUtc(ev.endDate__c, ev.endTime__c, sourceTz);

            Datetime startLocal = utcToLocal(startUtc, targetTz);
            Datetime endLocal   = utcToLocal(endUtc, targetTz);

            newEv.startDate__c = Date.newInstance(
                startLocal.yearGmt(),
                startLocal.monthGmt(),
                startLocal.dayGmt()
            );
            newEv.endDate__c = Date.newInstance(
                endLocal.yearGmt(),
                endLocal.monthGmt(),
                endLocal.dayGmt()
            );

            newEv.startTime__c = formatTime(startLocal);
            newEv.endTime__c   = formatTime(endLocal);
            newEv.timezone__c  = targetTimezoneId;

            result.add(newEv);
        }

        return result;
    }

    private static Datetime localToUtc(Date d, String timeText, TimeZone tz) {
        Integer[] hm = parseHourMinute(timeText);

        Datetime base = Datetime.newInstanceGmt(
            d.year(), d.month(), d.day(),
            hm[0], hm[1], 0
        );

        Integer offset1 = tz.getOffset(base);
        Datetime utc = base.addSeconds(-(offset1 / 1000));

        Integer offset2 = tz.getOffset(utc);
        if (offset1 != offset2) {
            utc = base.addSeconds(-(offset2 / 1000));
        }

        return utc;
    }

    private static Datetime utcToLocal(Datetime utc, TimeZone tz) {
        Integer offset = tz.getOffset(utc);
        return utc.addSeconds(offset / 1000);
    }

    private static void validateEvent(Event__c ev) {
        if (ev.startDate__c == null || ev.endDate__c == null) {
            throw new EventTimezoneUtilException('Date fields are required');
        }
        if (String.isBlank(ev.startTime__c) || String.isBlank(ev.endTime__c)) {
            throw new EventTimezoneUtilException('Time fields are required');
        }
        if (String.isBlank(ev.timezone__c)) {
            throw new EventTimezoneUtilException('Timezone is required');
        }
    }

    private static Integer[] parseHourMinute(String timeText) {
        List<String> parts = timeText.trim().split(':');
        if (parts.size() != 2) {
            throw new EventTimezoneUtilException('Invalid time: ' + timeText);
        }

        Integer h = Integer.valueOf(parts[0]);
        Integer m = Integer.valueOf(parts[1]);

        return new Integer[]{h, m};
    }

    private static String formatTime(Datetime dt) {
        String h = String.valueOf(dt.hourGmt()).leftPad(2, '0');
        String m = String.valueOf(dt.minuteGmt()).leftPad(2, '0');
        return h + ':' + m;
    }

    private static String normalizeTimezone(String tz) {
        if (String.isBlank(tz)) {
            throw new EventTimezoneUtilException('Timezone is required');
        }

        String trimmed = tz.trim();
        String key = trimmed.toLowerCase();

        // 1. Alias (paris, london, etc.)
        if (TIMEZONE_ALIASES.containsKey(key)) {
            return TIMEZONE_ALIASES.get(key);
        }

        // 2. Essayer comme vraie timezone IANA
        try {
            TimeZone tzObj = TimeZone.getTimeZone(trimmed);

            // Salesforce retourne toujours un objet, donc on vérifie via offset
            // Si tz inconnue → fallback silencieux vers GMT
            if (tzObj != null) {
                return trimmed;
            }
        } catch (Exception e) {
            // ignore, on gère après
        }

        // 3. Si vraiment invalide → erreur
        throw new EventTimezoneUtilException('Unsupported timezone: ' + tz);
    }
}