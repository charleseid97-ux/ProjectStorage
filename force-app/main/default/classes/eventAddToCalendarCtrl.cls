public with sharing class eventAddToCalendarCtrl {
    @AuraEnabled(cacheable=true)
    public static String getIcsContent(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('recordId is null');
        }

        // Load only the fields needed to build the calendar file.
        List<Event__c> events = [
            SELECT
                Id,
                Name,
                StartDate__c,
                StartTime__c,
                EndDate__c,
                EndTime__c,
                Timezone__c,
                Location__c,
                LocationAddress__c,
                LocationName__c,
                City__c,
                Country__c,
                SpeakersHTML__c
            FROM Event__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (events.isEmpty()) {
            throw new AuraHandledException('Event not found for Id: ' + recordId);
        }

        Event__c ev = events[0];

        Datetime startDt = buildDateTime(ev.StartDate__c, ev.StartTime__c);
        Datetime endDt = buildDateTime(ev.EndDate__c, ev.EndTime__c);

        String summary = ev.Name;
        String location = buildLocation(ev);
        String description = buildDescription(ev);

        return buildIcs(ev.Id, summary, startDt, endDt, location, description);
    }

    // Build the final ICS content consumed by Outlook / calendar apps.
    private static String buildIcs(
        Id eventId,
        String summary,
        Datetime startDt,
        Datetime endDt,
        String location,
        String description
    ) {
        String uid = String.valueOf(eventId) + '@salesforce';
        String dtStamp = toIcsDateTime(System.now());

        String ics =
            'BEGIN:VCALENDAR\r\n' +
            'VERSION:2.0\r\n' +
            'PRODID:-//Salesforce//Event Calendar//EN\r\n' +
            'BEGIN:VEVENT\r\n' +
            'UID:' + uid + '\r\n' +
            'DTSTAMP:' + dtStamp + '\r\n' +
            'SUMMARY:' + escapeIcs(summary) + '\r\n';

        if (startDt != null) {
            ics += 'DTSTART:' + toIcsDateTime(startDt) + '\r\n';
        }
        if (endDt != null) {
            ics += 'DTEND:' + toIcsDateTime(endDt) + '\r\n';
        }
        if (String.isNotBlank(location)) {
            ics += 'LOCATION:' + escapeIcs(location) + '\r\n';
        }
        if (String.isNotBlank(description)) {
            ics += 'DESCRIPTION:' + escapeIcs(description) + '\r\n';
        }

        ics +=
            'END:VEVENT\r\n' +
            'END:VCALENDAR';

        return ics;
    }

    // Convert a Date + text time into a Datetime.
    // If the time is missing or invalid, midnight is used.
    private static Datetime buildDateTime(Date eventDate, String timeText) {
        if (eventDate == null) {
            return null;
        }

        Time parsedTime = parseTimeText(timeText);
        if (parsedTime == null) {
            parsedTime = Time.newInstance(0, 0, 0, 0);
        }

        return Datetime.newInstance(eventDate, parsedTime);
    }

    // Accept values like 09:30, 9:30, 09:30:00 or 9.30.
    private static Time parseTimeText(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        String cleaned = value.trim().replace('.', ':');
        List<String> parts = cleaned.split(':');

        if (parts.isEmpty()) {
            return null;
        }

        try {
            Integer hour = Integer.valueOf(parts[0].trim());
            Integer minute = parts.size() > 1 ? Integer.valueOf(parts[1].trim()) : 0;
            Integer second = parts.size() > 2 ? Integer.valueOf(parts[2].trim()) : 0;

            if (hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 59) {
                return null;
            }

            return Time.newInstance(hour, minute, second, 0);
        } catch (Exception e) {
            return null;
        }
    }

    private static String toIcsDateTime(Datetime dt) {
        return dt == null ? null : dt.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
    }

    // LOCATION field used by the calendar client.
    private static String buildLocation(Event__c ev) {
        List<String> parts = new List<String>();

        addPart(parts, ev.LocationName__c);
        addPart(parts, ev.Location__c);
        addPart(parts, ev.LocationAddress__c);
        addPart(parts, ev.City__c);
        addPart(parts, ev.Country__c);

        return String.join(parts, ', ');
    }

    // DESCRIPTION field visible inside the calendar entry.
    private static String buildDescription(Event__c ev) {
        List<String> lines = new List<String>();

        addLine(lines, 'Event', ev.Name);
        addLine(lines, 'When', buildWhenValue(ev));
        addLine(lines, 'Where', buildWhereValue(ev));

        String speaker = extractFirstSpeaker(ev.SpeakersHTML__c);
        if (String.isNotBlank(speaker)) {
            addLine(lines, 'Speaker', speaker);
        }

        return String.join(lines, '\n');
    }

    private static String buildWhenValue(Event__c ev) {
        String startPart = buildDateTimeLabel(ev.StartDate__c, ev.StartTime__c);
        String endPart = buildDateTimeLabel(ev.EndDate__c, ev.EndTime__c);

        List<String> parts = new List<String>();
        addPart(parts, startPart);
        addPart(parts, endPart);

        String result = String.join(parts, ' - ');

        if (String.isNotBlank(ev.Timezone__c)) {
            result += (String.isNotBlank(result) ? ' ' : '') + ev.Timezone__c.trim();
        }

        return result;
    }

    private static String buildDateTimeLabel(Date eventDate, String eventTime) {
        String result = '';

        if (eventDate != null) {
            result = formatDateFr(eventDate);
        }
        if (String.isNotBlank(eventTime)) {
            result += (String.isNotBlank(result) ? ' ' : '') + eventTime.trim();
        }

        return result;
    }

    private static String buildWhereValue(Event__c ev) {
        List<String> parts = new List<String>();

        addPart(parts, ev.LocationName__c);
        addPart(parts, ev.LocationAddress__c);
        addPart(parts, ev.City__c);
        addPart(parts, ev.Country__c);

        return String.join(parts, ', ');
    }

    // Extract only the first speaker name from the HTML table.
    private static String extractFirstSpeaker(String html) {
        if (String.isBlank(html)) return null;

        Matcher m = Pattern.compile('(?s)<td[^>]*>(.*?)</td>').matcher(html);

        Integer count = 0;
        while (m.find()) {
            count++;
            if (count == 6) { // première cellule de la 2ème ligne
                return stripHtml(m.group(1));
            }
        }

        return null;
    }

    private static String formatDateFr(Date d) {
        if (d == null) {
            return null;
        }

        String day = String.valueOf(d.day()).leftPad(2, '0');
        String month = String.valueOf(d.month()).leftPad(2, '0');
        String year = String.valueOf(d.year());

        return day + '/' + month + '/' + year;
    }

    // Remove basic HTML so the text stays readable in Outlook.
    private static String stripHtml(String input) {
        if (String.isBlank(input)) {
            return null;
        }

        String output = input.replaceAll('<br\\s*/?>', '\n');
        output = output.replaceAll('</p>', '\n');
        output = output.replaceAll('<[^>]+>', '');
        output = output.replaceAll('&nbsp;', ' ');
        output = output.replaceAll('&amp;', '&');
        output = output.replaceAll('&lt;', '<');
        output = output.replaceAll('&gt;', '>');
        output = output.replaceAll('\\n+', '\n');

        return output.trim();
    }

    // Escape reserved ICS characters to keep the file valid.
    private static String escapeIcs(String value) {
        if (String.isBlank(value)) {
            return '';
        }

        return value
            .replace('\\', '\\\\')
            .replace(';', '\\;')
            .replace(',', '\\,')
            .replace('\r\n', '\\n')
            .replace('\n', '\\n');
    }

    private static void addLine(List<String> lines, String label, String value) {
        if (String.isNotBlank(value)) {
            lines.add(label + ': ' + value.trim());
        }
    }

    private static void addPart(List<String> parts, String value) {
        if (String.isNotBlank(value)) {
            parts.add(value.trim());
        }
    }
}