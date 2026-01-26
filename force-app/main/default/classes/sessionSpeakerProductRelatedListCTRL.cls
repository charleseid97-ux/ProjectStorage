public with sharing class sessionSpeakerProductRelatedListCTRL {

    public class SpeakerBlock {
        @AuraEnabled public Id speakerId;
        @AuraEnabled public String speakerName;
        @AuraEnabled public Integer productCount;
        @AuraEnabled public List<ProductItem> products = new List<ProductItem>();
    }

    public class ProductItem {
        @AuraEnabled public Id linkId;        // sessionSpeakerProduct__c Id
        @AuraEnabled public Id productId;     // Product__c
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
                   Product__c,
                   Product__r.Name
            FROM sessionSpeakerProduct__c
            WHERE Session__c = :eventId
            ORDER BY speakerContact__r.Name, Product__r.Name
            LIMIT 5000
        ];

        Map<Id, SpeakerBlock> grouped = new Map<Id, SpeakerBlock>();
        List<Id> speakerOrder = new List<Id>();

        for (sessionSpeakerProduct__c r : rows) {
            if (r.speakerContact__c == null) continue;

            SpeakerBlock block = grouped.get(r.speakerContact__c);
            if (block == null) {
                block = new SpeakerBlock();
                block.speakerId = r.speakerContact__c;
                block.speakerName = (r.speakerContact__r != null && String.isNotBlank(r.speakerContact__r.Name))
                    ? r.speakerContact__r.Name
                    : '—';
                grouped.put(r.speakerContact__c, block);
                speakerOrder.add(r.speakerContact__c);
            }

            if (r.Product__c != null) {
                ProductItem p = new ProductItem();
                p.linkId = r.Id;
                p.productId = r.Product__c;
                p.productName = (r.Product__r != null && String.isNotBlank(r.Product__r.Name))
                    ? r.Product__r.Name
                    : '—';
                block.products.add(p);
            }
        }

        List<SpeakerBlock> result = new List<SpeakerBlock>();
        for (Id speakerId : speakerOrder) {
            SpeakerBlock b = grouped.get(speakerId);
            if (b == null) continue;
            b.productCount = b.products.size();
            result.add(b);
        }

        System.debug(LoggingLevel.INFO, 'sessionSpeakerProductRelatedListCTRL.getByEvent - END groups=' + result.size());
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
            SELECT Id, speakerContact__c, speakerContact__r.Name, Product__c, Product__r.Name, Language__c
            FROM sessionSpeakerProduct__c
            WHERE Session__c = :eventId
            ORDER BY speakerContact__r.Name, Product__r.Name
            LIMIT 5000
        ];

        List<Map<String, Object>> out = new List<Map<String, Object>>();
        for (sessionSpeakerProduct__c r : rows) {
            Map<String, Object> o = new Map<String, Object>();
            o.put('attributes', new Map<String, Object>{ 'type' => 'sessionSpeakerProduct__c' });
            // Keep Id so the parent can keep it if needed (even if current repeater ignores it)
            o.put('Id', r.Id);
            o.put('speakerContact__c', r.speakerContact__c);
            o.put('Product__c', r.Product__c);
            o.put('Language__c', r.Language__c);
            o.put('Session__c', eventId);
            out.add(o);
        }

        String jsonOut = JSON.serialize(out);
        System.debug(LoggingLevel.INFO, 'sessionSpeakerProductRelatedListCTRL.getRepeaterInputByEvent - END rows=' + out.size());
        return jsonOut;
    }

    /**
     * Saves the full set of links for the given Event based on the repeater JSON output.
     * The method compares the new payload to current DB state using a composite key:
     * speakerContact__c + Product__c + Language__c.
     *
     * Payload is expected to be a JSON array of objects containing:
     * - speakerContact__c
     * - Product__c
     * - Language__c (optional)
     */
    @AuraEnabled
    public static Integer saveFromRepeaterJson(Id eventId, String payloadJson) {
        System.debug(LoggingLevel.INFO, 'sessionSpeakerProductRelatedListCTRL.saveFromRepeaterJson - START eventId=' + String.valueOf(eventId));
        System.debug(LoggingLevel.DEBUG, 'payloadJson=' + payloadJson);

        if (eventId == null) throw new AuraHandledException('Event Id is required.');

        List<Object> raw;
        try {
            raw = (List<Object>) JSON.deserializeUntyped(payloadJson);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid JSON payload: ' + e.getMessage());
        }

        // Current DB state
        List<sessionSpeakerProduct__c> existing = [
            SELECT Id, speakerContact__c, Product__c, Language__c, Session__c
            FROM sessionSpeakerProduct__c
            WHERE Session__c = :eventId
            LIMIT 5000
        ];

        Map<String, sessionSpeakerProduct__c> existingByKey = new Map<String, sessionSpeakerProduct__c>();
        for (sessionSpeakerProduct__c r : existing) {
            existingByKey.put(makeKey(r.speakerContact__c, r.Product__c, r.Language__c), r);
        }

        Set<String> incomingKeys = new Set<String>();
        List<sessionSpeakerProduct__c> toInsert = new List<sessionSpeakerProduct__c>();

        Integer rowIndex = 0;
        for (Object o : raw) {
            rowIndex++;
            Map<String, Object> m = (Map<String, Object>) o;

            Id speakerId = (m.get('speakerContact__c') != null) ? (Id) String.valueOf(m.get('speakerContact__c')) : null;
            Id productId = (m.get('Product__c') != null) ? (Id) String.valueOf(m.get('Product__c')) : null;
            String lang = (m.get('Language__c') != null) ? String.valueOf(m.get('Language__c')) : null;

            if (speakerId == null || productId == null) {
                throw new AuraHandledException('Missing speakerContact__c or Product__c at row ' + rowIndex + '.');
            }

            String key = makeKey(speakerId, productId, lang);
            if (incomingKeys.contains(key)) {
                // Ignore duplicates in the payload
                continue;
            }
            incomingKeys.add(key);

            if (!existingByKey.containsKey(key)) {
                sessionSpeakerProduct__c rec = new sessionSpeakerProduct__c();
                rec.Session__c = eventId;
                rec.speakerContact__c = speakerId;
                rec.Product__c = productId;
                rec.Language__c = lang;
                toInsert.add(rec);
            }
        }

        // Delete records that are not present anymore
        List<sessionSpeakerProduct__c> toDelete = new List<sessionSpeakerProduct__c>();
        for (String key : existingByKey.keySet()) {
            if (!incomingKeys.contains(key)) {
                toDelete.add(existingByKey.get(key));
            }
        }

        System.debug(LoggingLevel.INFO, 'Insert=' + toInsert.size() + ' Delete=' + toDelete.size());

        if (!toDelete.isEmpty()) delete toDelete;
        if (!toInsert.isEmpty()) insert toInsert;

        Integer impacted = toInsert.size() + toDelete.size();
        System.debug(LoggingLevel.INFO, 'sessionSpeakerProductRelatedListCTRL.saveFromRepeaterJson - END impacted=' + impacted);
        return impacted;
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