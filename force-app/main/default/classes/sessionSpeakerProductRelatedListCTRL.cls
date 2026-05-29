public without sharing class sessionSpeakerProductRelatedListCTRL {

    public class SpeakerBlock {
        @AuraEnabled public Id speakerId;
        @AuraEnabled public String speakerName;
        @AuraEnabled public Integer productCount;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public Date recDate;
        @AuraEnabled public String language;
        @AuraEnabled public String speakerLanguage;
        @AuraEnabled public Decimal sessionNumber;

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
        @AuraEnabled public String speakerLanguage;
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
                   Language__c,
                   speakerLanguage__c,
                   startTime__c,
                   endTime__c,
                   Date__c,
                   sessionNumber__c

            FROM sessionSpeakerProduct__c
            WHERE Session__c = :eventId
            ORDER BY sessionNumber__c ASC
            LIMIT 5000
        ];

        GroupBuild gb = groupRowsBySpeaker(rows);
        Map<Id, EventSpeakerApprovals__c> approvalsBySpeaker = loadApprovalsBySpeaker(eventId);

        List<SpeakerBlock> result = finalizeSpeakerBlocks(
            gb.grouped,
            gb.groupOrder,
            approvalsBySpeaker
        );

        System.debug(LoggingLevel.INFO, 'sessionSpeakerProductRelatedListCTRL.getByEvent - END groups=' + result.size());
        return result;
    }

    private class GroupBuild {
        // One display block per speaker + sessionNumber.
        Map<String, SpeakerBlock> grouped;

        // Preserves display order.
        List<String> groupOrder;

        GroupBuild() {
            grouped = new Map<String, SpeakerBlock>();
            groupOrder = new List<String>();
        }
    }

    private static GroupBuild groupRowsBySpeaker(List<sessionSpeakerProduct__c> rows) {
        GroupBuild gb = new GroupBuild();

        for (sessionSpeakerProduct__c r : rows) {
            if (r.speakerContact__c == null) continue;

            // Speaker can appear multiple times with different session blocks.
            String groupKey =
                String.valueOf(r.speakerContact__c)
                + '|'
                + String.valueOf(r.sessionNumber__c);

            SpeakerBlock block = gb.grouped.get(groupKey);
            if (block == null) {
                block = new SpeakerBlock();
                block.speakerId = r.speakerContact__c;
                block.speakerName = (r.speakerContact__r != null && String.isNotBlank(r.speakerContact__r.Name))
                    ? r.speakerContact__r.Name
                    : '—';
                block.language = r.Language__c;
                block.speakerLanguage = r.speakerLanguage__c;
                block.speakerLanguage = r.speakerLanguage__c;
                block.startTime = formatTime(r.startTime__c);
                block.endTime = formatTime(r.endTime__c);
                block.recDate = r.Date__c;
                block.sessionNumber = r.sessionNumber__c;

                gb.grouped.put(groupKey, block);
                gb.groupOrder.add(groupKey);
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
        Map<String, SpeakerBlock> grouped,
        List<String> groupOrder,
        Map<Id, EventSpeakerApprovals__c> approvalsBySpeaker
    ){
        List<SpeakerBlock> result = new List<SpeakerBlock>();

        for (String groupKey : groupOrder) {
            SpeakerBlock b = grouped.get(groupKey);
            if (b == null) continue;

            b.productCount = b.products.size();

            EventSpeakerApprovals__c esa = approvalsBySpeaker != null
                ? approvalsBySpeaker.get(b.speakerId)
                : null;

            

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
    @AuraEnabled(cacheable=false)
    public static String getRepeaterInputByEvent(Id eventId) {
        System.debug(LoggingLevel.INFO, 'sessionSpeakerProductRelatedListCTRL.getRepeaterInputByEvent - START eventId=' + String.valueOf(eventId));
        if (eventId == null) return '[]';

        List<sessionSpeakerProduct__c> rows = [
            SELECT Id,sessionNumber__c, speakerContact__c, speakerContact__r.Name, strategy__c, strategy__r.Name, Language__c,speakerLanguage__c,startTime__c, endTime__c,Date__c
            FROM sessionSpeakerProduct__c
            WHERE Session__c = :eventId
            ORDER BY sessionNumber__c ASC
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
        o.put('speakerLanguage__c', r.speakerLanguage__c);
        o.put('Session__c', eventId);
        o.put('startTime__c', r.startTime__c);
        o.put('endTime__c', r.endTime__c);
        o.put('Date__c', r.Date__c);
        o.put('sessionNumber__c', r.sessionNumber__c);
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

        IncomingBuild incoming = buildIncoming(raw);

        List<sessionSpeakerProduct__c> toInsert = buildToInsert(eventId, incoming);
        List<sessionSpeakerProduct__c> toUpdate = buildToUpdate(incoming);
        List<sessionSpeakerProduct__c> toDelete = buildToDelete(eventId, incoming);

        System.debug(
            LoggingLevel.INFO,
            'Insert=' + toInsert.size() +
            ' Update=' + toUpdate.size() +
            ' Delete=' + toDelete.size()
        );
        if (!toUpdate.isEmpty()) update toUpdate;
        if (!toDelete.isEmpty()) delete toDelete;
        if (!toInsert.isEmpty()) insert toInsert;

        sessionSpeakerProductService.recalcApprovals(eventId);

        Integer impacted = toInsert.size() + toUpdate.size() + toDelete.size();
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

 

    private class IncomingBuild {
        List<LinkParts> incomingParts = new List<LinkParts>();
    }

    private class LinkParts {
        Id id;
        Decimal sessionNumber;
        Id speakerId;
        Id productId;
        String lang;
        String speakerLanguage;
        Integer rowIndex;
        Time startTime;
        Time endTime;
        Date recDate;
    }

    private static IncomingBuild buildIncoming(List<Object> raw) {
        IncomingBuild incoming = new IncomingBuild();

        Integer rowIndex = 0;
        for (Object o : raw) {
            rowIndex++;
            LinkParts parts = parseRowToParts(o, rowIndex);
            incoming.incomingParts.add(parts);
        }

        return incoming;
    }

    private static LinkParts parseRowToParts(Object o, Integer rowIndex) {
        Map<String, Object> m = (Map<String, Object>) o;
        Id id = (m.get('Id') != null) ? (Id) String.valueOf(m.get('Id')) : null;

        Decimal sessionNumber = (m.get('sessionNumber__c') != null)
            ? Decimal.valueOf(String.valueOf(m.get('sessionNumber__c')))
            : null;
        Id speakerId = (m.get('speakerContact__c') != null) ? (Id) String.valueOf(m.get('speakerContact__c')) : null;
        Id productId = (m.get('strategy__c') != null) ? (Id) String.valueOf(m.get('strategy__c')) : null;
        String lang = (m.get('Language__c') != null) ? String.valueOf(m.get('Language__c')) : null;
        String speakerLanguage = (m.get('speakerLanguage__c') != null) ? String.valueOf(m.get('speakerLanguage__c')) : null;
        String startTime = (m.get('startTime__c') != null) ? String.valueOf(m.get('startTime__c')) : null;
        String endTime = (m.get('endTime__c') != null) ? String.valueOf(m.get('endTime__c')) : null;
        String recDate = (m.get('Date__c') != null) ? String.valueOf(m.get('Date__c')) : null;
        if (speakerId == null) {
            throw new AuraHandledException('Missing speaker at row ' + rowIndex + '.');
        }

        LinkParts parts = new LinkParts();
        parts.speakerId = speakerId;
        parts.productId = productId;
        parts.lang = lang;
        parts.speakerLanguage = speakerLanguage;
        parts.rowIndex = rowIndex;
        parts.startTime = parseTimeValue(startTime);
        parts.endTime = parseTimeValue(endTime);
        parts.recDate = (recDate != null) ? Date.valueOf(recDate) : null;
        parts.id = id;
        parts.sessionNumber = sessionNumber;
        return parts;
    }

    private static List<sessionSpeakerProduct__c> buildToInsert(
        Id eventId,
        IncomingBuild incoming
    ){
        List<sessionSpeakerProduct__c> toInsert = new List<sessionSpeakerProduct__c>();

        for (LinkParts parts : incoming.incomingParts) {
            if (parts.id != null) continue;

            sessionSpeakerProduct__c rec = new sessionSpeakerProduct__c();
            rec.Session__c = eventId;
            rec.speakerContact__c = parts.speakerId;
            rec.strategy__c = parts.productId;
            rec.Language__c = parts.lang;
            rec.speakerLanguage__c = parts.speakerLanguage;
            rec.startTime__c = parts.startTime;
            rec.endTime__c = parts.endTime;
            rec.Date__c = parts.recDate;
            rec.sessionNumber__c = parts.sessionNumber;
            toInsert.add(rec);
        }

        return toInsert;
    }

    private static List<sessionSpeakerProduct__c> buildToDelete(Id eventId,IncomingBuild incoming) {
        Set<Id> incomingIds = new Set<Id>();

        for (LinkParts parts : incoming.incomingParts) {
            if (parts.id != null) {
                incomingIds.add(parts.id);
            }
        }

        List<sessionSpeakerProduct__c> toDelete = new List<sessionSpeakerProduct__c>();

        for (sessionSpeakerProduct__c existing : [
            SELECT Id
            FROM sessionSpeakerProduct__c
            WHERE Session__c = :eventId
            LIMIT 5000
        ]) {
            if (!incomingIds.contains(existing.Id)) {
                toDelete.add(existing);
            }
        }

        return toDelete;
    }



    @AuraEnabled(cacheable=false)
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

        if (value.contains('.')) {
            value = value.substringBefore('.');
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

    @AuraEnabled(cacheable=false)
    public static Boolean canUserEditEvent(Id eventId) {
        if (eventId == null) {
            return false;
        }
        System.debug('+++++++++++++++++++UserId:    '+UserInfo.getUserId() );
        System.debug('+++++++++++++++++++eventId:    '+eventId );
        List<UserRecordAccess> accessRows = [
            SELECT HasEditAccess,RecordId
            FROM UserRecordAccess
            WHERE UserId = :UserInfo.getUserId()
            AND RecordId = :eventId
            LIMIT 1
        ];

        return !accessRows.isEmpty() && accessRows[0].HasEditAccess;
    }
    private static List<sessionSpeakerProduct__c> buildToUpdate(IncomingBuild incoming) {
        List<sessionSpeakerProduct__c> toUpdate = new List<sessionSpeakerProduct__c>();

        for (LinkParts parts : incoming.incomingParts) {
            if (parts.id == null) continue;

            // Update existing SSP without recreating it.
            sessionSpeakerProduct__c rec = new sessionSpeakerProduct__c();
            rec.Id = parts.id;
            rec.speakerContact__c = parts.speakerId;
            rec.strategy__c = parts.productId;
            rec.Language__c = parts.lang;
            rec.speakerLanguage__c = parts.speakerLanguage;
            rec.startTime__c = parts.startTime;
            rec.endTime__c = parts.endTime;
            rec.Date__c = parts.recDate;
            rec.sessionNumber__c = parts.sessionNumber;

            toUpdate.add(rec);
        }

        return toUpdate;
    }
}