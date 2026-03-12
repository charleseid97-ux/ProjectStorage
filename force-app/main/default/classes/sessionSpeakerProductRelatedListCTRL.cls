public with sharing class sessionSpeakerProductRelatedListCTRL {

    public class SpeakerBlock {
        @AuraEnabled public Id speakerId;
        @AuraEnabled public String speakerName;
        @AuraEnabled public Integer productCount;
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

    @AuraEnabled
    public static List<SpeakerBlock> getByEvent(Id eventId) {
        System.debug(LoggingLevel.INFO, 'sessionSpeakerProductRelatedListCTRL.getByEvent - START eventId=' + String.valueOf(eventId));
        if (eventId == null) return new List<SpeakerBlock>();

        List<sessionSpeakerProduct__c> rows = [
            SELECT Id,
                   speakerContact__c,
                   speakerContact__r.Name,
                   strategy__c,
                   strategy__r.Name
            FROM sessionSpeakerProduct__c
            WHERE Session__c = :eventId
            ORDER BY speakerContact__r.Name, strategy__r.Name
            LIMIT 5000
        ];

        GroupBuild gb = groupRowsBySpeaker(rows);

        List<SpeakerBlock> result = finalizeSpeakerBlocks(gb.grouped, gb.speakerOrder);

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
                gb.grouped.put(r.speakerContact__c, block);
                gb.speakerOrder.add(r.speakerContact__c);
            }

            ProductItem p = toProductItem(r);
            if (p != null) block.products.add(p);
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

    private static List<SpeakerBlock> finalizeSpeakerBlocks(Map<Id, SpeakerBlock> grouped, List<Id> speakerOrder) {
        List<SpeakerBlock> result = new List<SpeakerBlock>();
        for (Id speakerId : speakerOrder) {
            SpeakerBlock b = grouped.get(speakerId);
            if (b == null) continue;
            b.productCount = b.products.size();
            result.add(b);
        }
        return result;
    }

    /**
     * Returns the existing link records for an Event in the same JSON shape
     * that the repeater produces (list of sessionSpeakerProduct__c-like objects).
     */
    @AuraEnabled
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
        // Keep Id so the parent can keep it if needed (even if current repeater ignores it)
        o.put('Id', r.Id);
        o.put('speakerContact__c', r.speakerContact__c);
        o.put('strategy__c', r.strategy__c);
        o.put('Language__c', r.Language__c);
        o.put('Session__c', eventId);
        return o;
    }

    /**
     * Saves the full set of links for the given Event based on the repeater JSON output.
     * The method compares the new payload to current DB state using a composite key:
     * speakerContact__c + strategy__c + Language__c.
     *
     * Payload is expected to be a JSON array of objects containing:
     * - speakerContact__c
     * - strategy__c
     * - Language__c (optional)
     */
    @AuraEnabled
    public static Integer saveFromRepeaterJson(Id eventId, String payloadJson) {
        System.debug(LoggingLevel.INFO, 'sessionSpeakerProductRelatedListCTRL.saveFromRepeaterJson - START eventId=' + String.valueOf(eventId));
        System.debug(LoggingLevel.DEBUG, 'payloadJson=' + payloadJson);

        if (eventId == null) throw new AuraHandledException('Event Id is required.');

        List<Object> raw = parseRepeaterJson(payloadJson);

        // Current DB state
        Map<String, sessionSpeakerProduct__c> existingByKey = loadExistingByKey(eventId);
        system.debug(LoggingLevel.INFO, 'Existing records for eventId=' + eventId + ' count=' + existingByKey.size());
        IncomingBuild incoming = buildIncoming(raw);
        system.debug(LoggingLevel.INFO, 'Parsed incoming records count=' + incoming.incomingKeys.size());
        system.debug(LoggingLevel.DEBUG, 'Incoming keys=' + incoming.incomingKeys);
        system.debug(LoggingLevel.DEBUG, 'Existing keys=' + existingByKey.keySet());
        system.debug(LoggingLevel.DEBUG, 'Existing =' + existingByKey);
        system.debug(LoggingLevel.DEBUG, 'Incoming =' + incoming.incomingParts);
        List<sessionSpeakerProduct__c> toInsert = buildToInsert(eventId, incoming, existingByKey);
        List<sessionSpeakerProduct__c> toDelete = buildToDelete(incoming.incomingKeys, existingByKey);

        System.debug(LoggingLevel.INFO, 'Insert=' + toInsert.size() + ' Delete=' + toDelete.size());

        if (!toDelete.isEmpty()) delete toDelete;
        if (!toInsert.isEmpty()) insert toInsert;
        // ✅ Recalcul "état final" (indépendant des triggers)
        SessionSpeakerProductService.recalcApprovals(eventId);        Integer impacted = toInsert.size() + toDelete.size();
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
                // Ignore duplicates in the payload
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

        if (speakerId == null ) {
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

    // Delete records that are not present anymore
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

    // Backward-compatible alias
    @AuraEnabled(cacheable=true)
    public static List<SpeakerBlock> getBySession(Id sessionId) {
        return getByEvent(sessionId);
    }
}