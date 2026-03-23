public with sharing class sessionSpeakerProductRelatedListCTRL {

    public class SpeakerBlock {
        @AuraEnabled public Id speakerId;
        @AuraEnabled public String speakerName;
        @AuraEnabled public Integer productCount;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public String language;

        @AuraEnabled public List<ProductItem> products = new List<ProductItem>();
    }

    public class ProductItem {
        @AuraEnabled public Id linkId;        // sessionSpeakerProduct__c Id
        @AuraEnabled public Id productId;     // strategy__c
        @AuraEnabled public String productName;
    }

    public class LinkDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public Id speakerContactId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String language;
    }

    @AuraEnabled(cacheable=false)
    public static List<SpeakerBlock> getByEvent(Id eventId) {
        System.debug(LoggingLevel.INFO, 'sessionSpeakerProductRelatedListCTRL.getByEvent - START eventId=' + String.valueOf(eventId));
        if (eventId == null) return new List<SpeakerBlock>();

        List<sessionSpeakerProduct__c> rows = [
            SELECT Id,
                   speakerContact__c,
                   speakerContact__r.Name,
                   strategy__c,
                   strategy__r.Name,
                   Language__c
            FROM sessionSpeakerProduct__c
            WHERE Session__c = :eventId
            ORDER BY speakerContact__r.Name, strategy__r.Name
            LIMIT 5000
        ];

        GroupBuild gb = groupRowsBySpeaker(rows);
        Map<Id, EventSpeakerApprovals__c> approvalsBySpeaker = loadApprovalsBySpeaker(eventId);

        List<SpeakerBlock> result = finalizeSpeakerBlocks(
            gb.grouped,
            gb.speakerOrder,
            approvalsBySpeaker
        );

        System.debug(LoggingLevel.INFO, 'sessionSpeakerProductRelatedListCTRL.getByEvent - END groups=' + result.size());
        return result;
    }

    private class GroupBuild {
        Map<Id, SpeakerBlock> grouped;
        List<Id> speakerOrder;

        GroupBuild() {
            grouped = new Map<Id, SpeakerBlock>();
            speakerOrder = new List<Id>();
        }
    }

    private static GroupBuild groupRowsBySpeaker(List<sessionSpeakerProduct__c> rows) {
        GroupBuild gb = new GroupBuild();

        for (sessionSpeakerProduct__c r : rows) {
            if (r.speakerContact__c == null) continue;

            SpeakerBlock block = gb.grouped.get(r.speakerContact__c);
            if (block == null) {
                block = new SpeakerBlock();
                block.speakerId = r.speakerContact__c;
                block.speakerName = (r.speakerContact__r != null && String.isNotBlank(r.speakerContact__r.Name))
                    ? r.speakerContact__r.Name
                    : '—';
                block.language = r.Language__c;
                gb.grouped.put(r.speakerContact__c, block);
                gb.speakerOrder.add(r.speakerContact__c);
            }

            ProductItem p = toProductItem(r);
            if (p != null) {
                block.products.add(p);
            }
        }

        return gb;
    }

    private static ProductItem toProductItem(sessionSpeakerProduct__c r) {
        if (r.strategy__c == null) return null;

        ProductItem p = new ProductItem();
        p.linkId = r.Id;
        p.productId = r.strategy__c;
        p.productName = (r.strategy__r != null && String.isNotBlank(r.strategy__r.Name))
            ? r.strategy__r.Name
            : '—';
        return p;
    }

    private static List<SpeakerBlock> finalizeSpeakerBlocks(
        Map<Id, SpeakerBlock> grouped,
        List<Id> speakerOrder,
        Map<Id, EventSpeakerApprovals__c> approvalsBySpeaker
    ) {
        List<SpeakerBlock> result = new List<SpeakerBlock>();

        for (Id speakerId : speakerOrder) {
            SpeakerBlock b = grouped.get(speakerId);
            if (b == null) continue;

            b.productCount = b.products.size();

            EventSpeakerApprovals__c esa = approvalsBySpeaker != null
                ? approvalsBySpeaker.get(speakerId)
                : null;

            if (esa != null) {
                b.startTime = formatTime(esa.start__c);
                b.endTime = formatTime(esa.end__c);
            }

            result.add(b);
        }

        return result;
    }

    private static Map<Id, EventSpeakerApprovals__c> loadApprovalsBySpeaker(Id eventId) {
        Map<Id, EventSpeakerApprovals__c> out = new Map<Id, EventSpeakerApprovals__c>();

        for (EventSpeakerApprovals__c esa : [
            SELECT Id, Speaker__c, start__c, end__c
            FROM EventSpeakerApprovals__c
            WHERE Event__c = :eventId
        ]) {
            if (esa.Speaker__c != null && !out.containsKey(esa.Speaker__c)) {
                out.put(esa.Speaker__c, esa);
            }
        }

        return out;
    }

    private static String formatTime(Time t) {
        if (t == null) {
            return null;
        }

        String hh = String.valueOf(t.hour()).leftPad(2, '0');
        String mm = String.valueOf(t.minute()).leftPad(2, '0');
        return hh + ':' + mm;
    }

    /**
     * Returns the existing link records for an Event in the same JSON shape
     * that the repeater produces (list of sessionSpeakerProduct__c-like objects).
     */
    @AuraEnabled(cacheable=true)
    public static String getRepeaterInputByEvent(Id eventId) {
        System.debug(LoggingLevel.INFO, 'sessionSpeakerProductRelatedListCTRL.getRepeaterInputByEvent - START eventId=' + String.valueOf(eventId));
        if (eventId == null) return '[]';

        List<sessionSpeakerProduct__c> rows = [
            SELECT Id, speakerContact__c, speakerContact__r.Name, strategy__c, strategy__r.Name, Language__c
            FROM sessionSpeakerProduct__c
            WHERE Session__c = :eventId
            ORDER BY speakerContact__r.Name, strategy__r.Name
            LIMIT 5000
        ];

        List<Map<String, Object>> out = new List<Map<String, Object>>();
        for (sessionSpeakerProduct__c r : rows) {
            out.add(toRepeaterRowMap(eventId, r));
        }

        String jsonOut = JSON.serialize(out);
        System.debug(LoggingLevel.INFO, 'sessionSpeakerProductRelatedListCTRL.getRepeaterInputByEvent - END rows=' + out.size());
        return jsonOut;
    }

    private static Map<String, Object> toRepeaterRowMap(Id eventId, sessionSpeakerProduct__c r) {
        Map<String, Object> o = new Map<String, Object>();
        o.put('attributes', new Map<String, Object>{ 'type' => 'sessionSpeakerProduct__c' });
        o.put('Id', r.Id);
        o.put('speakerContact__c', r.speakerContact__c);
        o.put('strategy__c', r.strategy__c);
        o.put('Language__c', r.Language__c);
        o.put('Session__c', eventId);
        return o;
    }

    @AuraEnabled
    public static Integer saveFromRepeaterJson(Id eventId, String payloadJson) {
        System.debug(LoggingLevel.INFO, 'sessionSpeakerProductRelatedListCTRL.saveFromRepeaterJson - START eventId=' + String.valueOf(eventId));
        System.debug(LoggingLevel.DEBUG, 'payloadJson=' + payloadJson);

        if (eventId == null) {
            throw new AuraHandledException('Event Id is required.');
        }

        List<Object> raw = parseRepeaterJson(payloadJson);

        Map<String, sessionSpeakerProduct__c> existingByKey = loadExistingByKey(eventId);
        System.debug(LoggingLevel.INFO, 'Existing records for eventId=' + eventId + ' count=' + existingByKey.size());

        IncomingBuild incoming = buildIncoming(raw);
        System.debug(LoggingLevel.INFO, 'Parsed incoming records count=' + incoming.incomingKeys.size());
        System.debug(LoggingLevel.DEBUG, 'Incoming keys=' + incoming.incomingKeys);
        System.debug(LoggingLevel.DEBUG, 'Existing keys=' + existingByKey.keySet());
        System.debug(LoggingLevel.DEBUG, 'Existing =' + existingByKey);
        System.debug(LoggingLevel.DEBUG, 'Incoming =' + incoming.incomingParts);

        List<sessionSpeakerProduct__c> toInsert = buildToInsert(eventId, incoming, existingByKey);
        List<sessionSpeakerProduct__c> toDelete = buildToDelete(incoming.incomingKeys, existingByKey);

        System.debug(LoggingLevel.INFO, 'Insert=' + toInsert.size() + ' Delete=' + toDelete.size());

        if (!toDelete.isEmpty()) delete toDelete;
        if (!toInsert.isEmpty()) insert toInsert;

        sessionSpeakerProductService.recalcApprovals(eventId);

        Integer impacted = toInsert.size() + toDelete.size();
        System.debug(LoggingLevel.INFO, 'sessionSpeakerProductRelatedListCTRL.saveFromRepeaterJson - END impacted=' + impacted);

        return impacted;
    }

    private static List<Object> parseRepeaterJson(String payloadJson) {
        try {
            return (List<Object>) JSON.deserializeUntyped(payloadJson);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid JSON payload: ' + e.getMessage());
        }
    }

    private static Map<String, sessionSpeakerProduct__c> loadExistingByKey(Id eventId) {
        List<sessionSpeakerProduct__c> existing = [
            SELECT Id, speakerContact__c, strategy__c, Language__c, Session__c
            FROM sessionSpeakerProduct__c
            WHERE Session__c = :eventId
            LIMIT 5000
        ];

        Map<String, sessionSpeakerProduct__c> existingByKey = new Map<String, sessionSpeakerProduct__c>();
        for (sessionSpeakerProduct__c r : existing) {
            existingByKey.put(makeKey(r.speakerContact__c, r.strategy__c, r.Language__c), r);
        }
        return existingByKey;
    }

    private class IncomingBuild {
        Set<String> incomingKeys = new Set<String>();
        List<LinkParts> incomingParts = new List<LinkParts>();
    }

    private class LinkParts {
        Id speakerId;
        Id productId;
        String lang;
        Integer rowIndex;
    }

    private static IncomingBuild buildIncoming(List<Object> raw) {
        IncomingBuild incoming = new IncomingBuild();

        Integer rowIndex = 0;
        for (Object o : raw) {
            rowIndex++;
            LinkParts parts = parseRowToParts(o, rowIndex);
            String key = makeKey(parts.speakerId, parts.productId, parts.lang);

            if (incoming.incomingKeys.contains(key)) {
                continue;
            }
            incoming.incomingKeys.add(key);
            incoming.incomingParts.add(parts);
        }

        return incoming;
    }

    private static LinkParts parseRowToParts(Object o, Integer rowIndex) {
        Map<String, Object> m = (Map<String, Object>) o;

        Id speakerId = (m.get('speakerContact__c') != null) ? (Id) String.valueOf(m.get('speakerContact__c')) : null;
        Id productId = (m.get('strategy__c') != null) ? (Id) String.valueOf(m.get('strategy__c')) : null;
        String lang = (m.get('Language__c') != null) ? String.valueOf(m.get('Language__c')) : null;

        if (speakerId == null) {
            throw new AuraHandledException('Missing speaker at row ' + rowIndex + '.');
        }

        LinkParts parts = new LinkParts();
        parts.speakerId = speakerId;
        parts.productId = productId;
        parts.lang = lang;
        parts.rowIndex = rowIndex;
        return parts;
    }

    private static List<sessionSpeakerProduct__c> buildToInsert(
        Id eventId,
        IncomingBuild incoming,
        Map<String, sessionSpeakerProduct__c> existingByKey
    ) {
        List<sessionSpeakerProduct__c> toInsert = new List<sessionSpeakerProduct__c>();

        for (LinkParts parts : incoming.incomingParts) {
            String key = makeKey(parts.speakerId, parts.productId, parts.lang);
            if (existingByKey.containsKey(key)) continue;

            sessionSpeakerProduct__c rec = new sessionSpeakerProduct__c();
            rec.Session__c = eventId;
            rec.speakerContact__c = parts.speakerId;
            rec.strategy__c = parts.productId;
            rec.Language__c = parts.lang;
            toInsert.add(rec);
        }

        return toInsert;
    }

    private static List<sessionSpeakerProduct__c> buildToDelete(
        Set<String> incomingKeys,
        Map<String, sessionSpeakerProduct__c> existingByKey
    ) {
        List<sessionSpeakerProduct__c> toDelete = new List<sessionSpeakerProduct__c>();
        for (String key : existingByKey.keySet()) {
            if (!incomingKeys.contains(key)) {
                toDelete.add(existingByKey.get(key));
            }
        }
        return toDelete;
    }

    private static String makeKey(Id speakerId, Id productId, String lang) {
        return String.valueOf(speakerId) + '|' + String.valueOf(productId) + '|' + String.valueOf(lang);
    }

    @AuraEnabled(cacheable=true)
    public static List<SpeakerBlock> getBySession(Id sessionId) {
        return getByEvent(sessionId);
    }


    @AuraEnabled
    public static void updateSpeakerSlot(Id eventId, Id speakerId, String startTime, String endTime) {
        if (eventId == null) {
            throw new AuraHandledException('Event Id is required.');
        }
        if (speakerId == null) {
            throw new AuraHandledException('Speaker Id is required.');
        }

        List<EventSpeakerApprovals__c> rows = [
            SELECT Id, start__c, end__c
            FROM EventSpeakerApprovals__c
            WHERE Event__c = :eventId
            AND Speaker__c = :speakerId
            LIMIT 1
        ];

        if (rows.isEmpty()) {
            throw new AuraHandledException('No speaker approval record found for this speaker.');
        }

        EventSpeakerApprovals__c esa = rows[0];
        esa.start__c = parseTimeValue(startTime);
        esa.end__c = parseTimeValue(endTime);

        if (esa.start__c != null && esa.end__c != null && esa.end__c <= esa.start__c) {
            throw new AuraHandledException('End time must be later than start time.');
        }

        update esa;
    }

    private static Time parseTimeValue(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        List<String> parts = value.split(':');
        if (parts.size() < 2) {
            throw new AuraHandledException('Invalid time format: ' + value);
        }

        Integer hh = Integer.valueOf(parts[0]);
        Integer mm = Integer.valueOf(parts[1]);
        Integer ss = (parts.size() > 2) ? Integer.valueOf(parts[2]) : 0;

        return Time.newInstance(hh, mm, ss, 0);
    }
}