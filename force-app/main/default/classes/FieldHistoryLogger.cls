/**
 * @description Configuration-driven utility class for tracking field value changes on SObjects.
 *              Reads Field_History_Config__mdt to determine which fields to track per object.
 *              log() — maintains applicability windows (open/close periods) for tracked fields.
 *              logAllFields() — append-only audit of all non-excluded fields.
 *              logPhaseValidation() — logs newly validated teams on ProjectProductChild__c.
 *              When SendAlert__c is enabled on the config record, sends an email alert after logging,
 *              with changes rendered as an inline HTML table or a CSV attachment depending on MaxTableRows__c.
 * @editor Charles Eid — 2026-04-02
 */
public without sharing class FieldHistoryLogger {

    public static void log(List<SObject> newList, Map<Id, SObject> oldMap, String objectApiName) {
        if (newList == null || newList.isEmpty()) return;
        Field_History_Config__mdt config = getFieldHistoryConfigMdt(objectApiName);
        if (config == null) return;

        Set<Id> recordIds = new Set<Id>();
        for (SObject newObj : newList) {
            recordIds.add(newObj.Id);
        }
        String lookupField = getLookupFieldName(objectApiName);
        String query = 'SELECT Id, FieldAPIName__c, End_Date__c, ' + lookupField +
                       ' FROM Fund_Field_ApplicabilityHistory__c' +
                       ' WHERE Applicability__c = true' +
                       ' AND End_Date__c = NULL' +
                       ' AND ' + lookupField + ' IN :recordIds';
        Map<String, Fund_Field_ApplicabilityHistory__c> activeLogsMap = new Map<String, Fund_Field_ApplicabilityHistory__c>();
        for (Fund_Field_ApplicabilityHistory__c existingLog : Database.query(query)) {
            String key = getRefId(existingLog, objectApiName) + ':' + existingLog.FieldAPIName__c;
            activeLogsMap.put(key, existingLog);
        }

        String source = UserInfo.getUserName().contains('infrastructure.technology@carmignac.com') ? 'PMT' : 'Product Catalog';
        Set<String> trackedFields = new Set<String>(splitLines(config.Tracked_Fields__c));
        Map<String, Schema.SObjectField> fieldMap = newList[0].getSObjectType().getDescribe().fields.getMap();
        List<Fund_Field_ApplicabilityHistory__c> logsToInsert = new List<Fund_Field_ApplicabilityHistory__c>();
        List<Fund_Field_ApplicabilityHistory__c> logsToUpdate = new List<Fund_Field_ApplicabilityHistory__c>();

        for (SObject newObj : newList) {
            Id recordId = newObj.Id;
            SObject oldObj = oldMap != null ? oldMap.get(recordId) : null;
            for (String field : trackedFields) {
                if (!fieldMap.containsKey(field)) continue;
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(field).getDescribe();
                String fieldLabel = fieldDescribe.getLabel();
                Object oldVal = oldObj != null ? oldObj.get(field) : null;
                Object newVal = newObj.get(field);
                Boolean changed = (oldObj == null)? (newVal != null) : (oldVal != newVal && (oldVal == null || !oldVal.equals(newVal)));
                if (changed) {
                    String logKey = recordId + ':' + field;
                    Fund_Field_ApplicabilityHistory__c oldLog = activeLogsMap.get(logKey);
                    if (oldLog != null) {
                        oldLog.End_Date__c = System.Today().addDays(-1);
                        logsToUpdate.add(oldLog);
                    }
                    Fund_Field_ApplicabilityHistory__c newLog = buildLog(objectApiName, recordId, field, fieldLabel, oldVal, newVal, source);
                    newLog.Start_Date__c    = System.Today();
                    newLog.Applicability__c = true;
                    logsToInsert.add(newLog);
                }
            }
        }

        if (!logsToUpdate.isEmpty()) update logsToUpdate;
        if (!logsToInsert.isEmpty()) insert logsToInsert;

        if (config.SendAlert__c && String.isNotBlank(config.AlertRecipients__c) && String.isNotBlank(config.AlertEmailTemplate__c) && !logsToInsert.isEmpty()) {
            sendFieldChangeAlert(config, objectApiName, logsToInsert, fieldMap);
        }
    }

    public static void logAllFields(List<SObject> newList, Map<Id, SObject> oldMap, String objectApiName) {
        if (newList == null || newList.isEmpty()) return;
        Field_History_Config__mdt config = getFieldHistoryConfigMdt(objectApiName);
        if (config == null) return;

        String source = UserInfo.getUserName().contains('infrastructure.technology@carmignac.com') ? 'PMT' : 'Product Catalog';

        Set<String> excludedFields = new Set<String>(splitLines(config.Tracked_Fields__c));
        if (config.ExcludedFields__c != null) excludedFields.addAll(splitLines(config.ExcludedFields__c));
        excludedFields.addAll(new Set<String>{'Id', 'CreatedDate', 'CreatedById', 'LastModifiedDate', 'LastModifiedById', 'SystemModstamp'});

        Set<String> normalizedExclusions = new Set<String>();
        for (String f : excludedFields) {
            if (!String.isBlank(f)) {
                normalizedExclusions.add(f.trim().toLowerCase());
            }
        }

        Map<String, Schema.SObjectField> allFields = newList[0].getSObjectType().getDescribe().fields.getMap();
        Map<String, String> trackedFieldsMap = new Map<String, String>();
        for (String fieldName : allFields.keySet()) {
            if (!normalizedExclusions.contains(fieldName) && !fieldName.endsWith('__r')) {
                trackedFieldsMap.put(fieldName, allFields.get(fieldName).getDescribe().getLabel());
            }
        }

        List<Fund_Field_ApplicabilityHistory__c> logsToInsert = new List<Fund_Field_ApplicabilityHistory__c>();
        for (SObject newObj : newList) {
            Id recordId = newObj.Id;
            SObject oldObj = oldMap.get(recordId);
            for (String field : trackedFieldsMap.keySet()) {
                Object oldVal = oldObj != null ? oldObj.get(field) : null;
                Object newVal = newObj.get(field);
                if (oldVal != newVal && (oldVal == null || !oldVal.equals(newVal))) {
                    Fund_Field_ApplicabilityHistory__c l = buildLog(objectApiName, recordId, field, trackedFieldsMap.get(field), oldVal, newVal, source);
                    l.Date__c = DateTime.now();
                    logsToInsert.add(l);
                }
            }
        }

        if (!logsToInsert.isEmpty()) insert logsToInsert;
    }

    public static void logPhaseValidation(List<ProjectProductChild__c> newList, Map<Id, ProjectProductChild__c> oldMap) {
        List<Fund_Field_ApplicabilityHistory__c> logsToInsert = new List<Fund_Field_ApplicabilityHistory__c>();
        for (ProjectProductChild__c newRecord : newList) {
            ProjectProductChild__c oldRecord = oldMap.get(newRecord.Id);

            Set<String> oldTeams = getSplitValues(oldRecord.TECH_TeamValidation__c);
            Set<String> newTeams = getSplitValues(newRecord.TECH_TeamValidation__c);
            newTeams.removeAll(oldTeams);

            if (!newTeams.isEmpty()) {
                logsToInsert.add(new Fund_Field_ApplicabilityHistory__c(
                    Project_Reference__c = newRecord.ProjectProductParent__c,
                    Field_Name__c        = 'Phase validation - ' + newRecord.Name,
                    FieldAPIName__c      = 'TECH_TeamValidation__c',
                    Comment__c           = 'Validated team: ' + String.join(newTeams, ', '),
                    Date__c              = DateTime.now(),
                    User__c              = UserInfo.getUserId(),
                    Source__c            = 'Product Catalog'
                ));
            }
        }

        if (!logsToInsert.isEmpty()) insert logsToInsert;
    }

    private static Field_History_Config__mdt getFieldHistoryConfigMdt(String objectApiName) {
        List<Field_History_Config__mdt> configs = [SELECT Tracked_Fields__c, ExcludedFields__c, SendAlert__c, AlertRecipients__c, AlertEmailTemplate__c, ContextFields__c, MaxTableRows__c
                                                   FROM Field_History_Config__mdt
                                                   WHERE Object_API_Name__c = :objectApiName
                                                   LIMIT 1];
        if (configs.isEmpty() || String.isBlank(configs[0].Tracked_Fields__c)) return null;
        return configs[0];
    }

    private static Fund_Field_ApplicabilityHistory__c buildLog(String objectApiName, Id recordId, String fieldApiName, String fieldLabel, Object oldVal, Object newVal, String source) {
        Fund_Field_ApplicabilityHistory__c l = new Fund_Field_ApplicabilityHistory__c();
        setLookupField(l, objectApiName, recordId);
        l.Old_Value__c     = String.valueOf(oldVal);
        l.New_Value__c     = String.valueOf(newVal);
        l.Field_Name__c    = fieldLabel;
        l.FieldAPIName__c  = fieldApiName;
        l.Source__c        = source;
        l.User__c          = UserInfo.getUserId();
        return l;
    }

    private static void setLookupField(Fund_Field_ApplicabilityHistory__c l, String objectApiName, Id recordId) {
        l.put(getLookupFieldName(objectApiName), recordId);
    }

    private static Id getRefId(Fund_Field_ApplicabilityHistory__c l, String objectApiName) {
        return (Id) l.get(getLookupFieldName(objectApiName));
    }

    private static String getLookupFieldName(String objectApiName) {
        if (objectApiName == 'Product__c')     return 'Product_Reference__c';
        if (objectApiName == 'Share_Class__c') return 'Share_Class_Reference__c';
        throw new IllegalArgumentException('FieldHistoryLogger: no lookup field registered for object: ' + objectApiName);
    }

    // Sends alert emails per-field-recipient mapping defined as JSON in AlertRecipients__c
    private static void sendFieldChangeAlert(Field_History_Config__mdt config, String objectApiName, List<Fund_Field_ApplicabilityHistory__c> changedLogs, Map<String, Schema.SObjectField> fieldMap) {

        // Parse JSON field → recipients map (keys lowercased for case-insensitive matching)
        Map<String, List<String>> fieldRecipientsMap;
        try {
            Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(config.AlertRecipients__c);
            fieldRecipientsMap = new Map<String, List<String>>();
            for (String key : raw.keySet()) {
                List<String> emails = new List<String>();
                for (Object o : (List<Object>) raw.get(key)) emails.add((String) o);
                fieldRecipientsMap.put(key.toLowerCase(), emails);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'FieldHistoryLogger: invalid AlertRecipients__c JSON — ' + e.getMessage());
            return;
        }
        if (fieldRecipientsMap.isEmpty()) return;

        List<EmailTemplate> templates = [SELECT Subject, HtmlValue FROM EmailTemplate WHERE DeveloperName = :config.AlertEmailTemplate__c LIMIT 1]; // Load the email template by developer name
        if (templates.isEmpty()) return;
        EmailTemplate tmpl = templates[0];

        List<String> wildcardRecipients = fieldRecipientsMap.containsKey('*') ? fieldRecipientsMap.get('*') : new List<String>(); // Wildcard recipients are always added regardless of which field changed

        // Single pass: build recipient → relevant logs map and collect all distinct record IDs
        Map<String, List<Fund_Field_ApplicabilityHistory__c>> recipientLogsMap = new Map<String, List<Fund_Field_ApplicabilityHistory__c>>();
        Set<Id> allDistinctRecords = new Set<Id>();
        for (Fund_Field_ApplicabilityHistory__c l : changedLogs) {
            allDistinctRecords.add(getRefId(l, objectApiName));
            Set<String> targets = new Set<String>(wildcardRecipients);
            if (fieldRecipientsMap.containsKey(l.FieldAPIName__c.toLowerCase())) {
                targets.addAll(fieldRecipientsMap.get(l.FieldAPIName__c.toLowerCase()));
            }
            for (String email : targets) {
                if (!recipientLogsMap.containsKey(email)) recipientLogsMap.put(email, new List<Fund_Field_ApplicabilityHistory__c>());
                recipientLogsMap.get(email).add(l);
            }
        }
        if (recipientLogsMap.isEmpty()) return;

        // Group recipients by log signature — identical subscriptions share one email (setToAddresses)
        Map<String, List<Fund_Field_ApplicabilityHistory__c>> groupLogs = new Map<String, List<Fund_Field_ApplicabilityHistory__c>>();
        Map<String, List<String>> groupRecipients = new Map<String, List<String>>();
        for (String email : recipientLogsMap.keySet()) {
            String sig = buildLogsSignature(recipientLogsMap.get(email));
            if (!groupLogs.containsKey(sig)) {
                groupLogs.put(sig, recipientLogsMap.get(email));
                groupRecipients.put(sig, new List<String>());
            }
            groupRecipients.get(sig).add(email);
        }

        // Build context fields map and fetch their values once, shared across all groups
        Map<String, String> contextFields = new Map<String, String>();
        Map<Id, SObject> contextRecordMap = new Map<Id, SObject>();
        if (String.isNotBlank(config.ContextFields__c)) {
            for (String f : splitLines(config.ContextFields__c)) {
                if (fieldMap.containsKey(f)) {
                    contextFields.put(f, fieldMap.get(f).getDescribe().getLabel());
                }
            }
            if (!contextFields.isEmpty()) {
                String soql = 'SELECT Id, ' + String.join(new List<String>(contextFields.keySet()), ', ') +
                              ' FROM ' + objectApiName + 
                              ' WHERE Id IN :allDistinctRecords';
                for (SObject rec : Database.query(soql)) {
                    contextRecordMap.put(rec.Id, rec);
                }
            }
        }

        Integer maxRows = Test.isRunningTest() ? 5 : (config.MaxTableRows__c != null ? (Integer)config.MaxTableRows__c : 100);

        // Build one email per group, collect all, send in a single Messaging.sendEmail() call
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (String sig : groupLogs.keySet()) {
            List<Fund_Field_ApplicabilityHistory__c> grpLogs = groupLogs.get(sig);
            List<Id> orderedRecordIds = new List<Id>();
            Map<Id, List<Fund_Field_ApplicabilityHistory__c>> logsByRecord = new Map<Id, List<Fund_Field_ApplicabilityHistory__c>>();
            for (Fund_Field_ApplicabilityHistory__c l : grpLogs) {
                Id refId = getRefId(l, objectApiName);
                if (!logsByRecord.containsKey(refId)) {
                    orderedRecordIds.add(refId);
                    logsByRecord.put(refId, new List<Fund_Field_ApplicabilityHistory__c>());
                }
                logsByRecord.get(refId).add(l);
            }
            Boolean useAttachment = maxRows == 0 || grpLogs.size() > maxRows;
            String tableContent;
            Messaging.EmailFileAttachment att;
            if (useAttachment) {
                tableContent = '<p>Please find attached the full list of field changes (' + grpLogs.size() + ' changes across ' + orderedRecordIds.size() + ' record(s)).</p>';
                att = new Messaging.EmailFileAttachment();
                att.setFileName(objectApiName + '_FieldChanges.csv');
                att.setBody(Blob.valueOf(buildCsvContent(grpLogs, objectApiName, contextFields, contextRecordMap)));
            } else {
                tableContent = buildHtmlTable(orderedRecordIds, logsByRecord, objectApiName, contextFields, contextRecordMap);
            }
            String htmlBody = tmpl.HtmlValue
                .replace('{_Record_Number_}', String.valueOf(orderedRecordIds.size()))
                .replace('{_Changes_Table_}', tableContent);
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(groupRecipients.get(sig));
            msg.setSubject(tmpl.Subject);
            msg.setHtmlBody(htmlBody);
            if (useAttachment) msg.setFileAttachments(new Messaging.EmailFileAttachment[]{ att });
            emails.add(msg);
        }
        if (!Test.isRunningTest() && !emails.isEmpty()) Messaging.sendEmail(emails);
    }

    // Builds a deterministic signature for a list of logs based on sorted field API names
    private static String buildLogsSignature(List<Fund_Field_ApplicabilityHistory__c> logs) {
        List<String> fields = new List<String>();
        for (Fund_Field_ApplicabilityHistory__c l : logs) fields.add(l.FieldAPIName__c);
        fields.sort();
        return String.join(fields, '|');
    }

    // Builds a styled HTML table of field changes with clickable record links and context columns
    private static String buildHtmlTable(List<Id> orderedRecordIds, Map<Id, List<Fund_Field_ApplicabilityHistory__c>> logsByRecord, String objectApiName, Map<String, String> contextFields, Map<Id, SObject> contextRecordMap) {
        String elmnt = '{_Element_}';
        String tableTh = '<th style="padding:8px; text-align:left;">'+elmnt+'</th>';
        String tableTd = '<td style="padding:6px;">'+elmnt+'</td>';

        String html = '<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; font-family:Arial,sans-serif; font-size:11pt; width:100%;">';
        html += '<thead><tr style="background-color:#c8102e; color:#ffffff;">'
              + tableTh.replace(elmnt, 'Record Id');
        for (String label : contextFields.values()) {
            html += tableTh.replace(elmnt, htmlEscape(label));
        }
        html += tableTh.replace(elmnt, 'Field')
              + tableTh.replace(elmnt, 'Old Value')
              + tableTh.replace(elmnt, 'New Value')
              + '</tr></thead><tbody>';
        String baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
        Boolean odd = true;
        for (Id refId : orderedRecordIds) {
            List<Fund_Field_ApplicabilityHistory__c> recLogs = logsByRecord.get(refId);
            String rowBg = odd ? '#f9f9f9' : '#ffffff';
            String spanAttr = recLogs.size() > 1 ? ' rowspan="' + recLogs.size() + '"' : '';
            String mergedStyle = 'style="padding:6px; vertical-align:middle; text-align:center; background-color:' + rowBg + ';"';
            String recordLink = '<a href="' + baseUrl + '/' + refId + '" style="color:#c8102e;">' + htmlEscape(String.valueOf(refId)) + '</a>';
            Boolean firstLogInGroup = true;
            for (Fund_Field_ApplicabilityHistory__c l : recLogs) {
                html += '<tr style="background-color:' + rowBg + ';">';
                if (firstLogInGroup) {
                    html += '<td' + spanAttr + ' ' + mergedStyle + '>' + recordLink + '</td>';
                    for (String fieldApiName : contextFields.keySet()) {
                        String ctxVal = '';
                        if (contextRecordMap.containsKey(refId)) {
                            Object fval = contextRecordMap.get(refId).get(fieldApiName);
                            ctxVal = fval != null ? String.valueOf(fval) : '';
                        }
                        html += '<td' + spanAttr + ' ' + mergedStyle + '>' + htmlEscape(ctxVal) + '</td>';
                    }
                    firstLogInGroup = false;
                }
                html += tableTd.replace(elmnt, htmlEscape(l.Field_Name__c))
                      + tableTd.replace(elmnt, htmlEscape(l.Old_Value__c))
                      + tableTd.replace(elmnt, htmlEscape(l.New_Value__c))
                      + '</tr>';
            }
            odd = !odd;
        }
        html += '</tbody></table>';
        return html;
    }

    // Builds a CSV string of field changes with context columns for use as an email attachment
    private static String buildCsvContent(List<Fund_Field_ApplicabilityHistory__c> changedLogs, String objectApiName, Map<String, String> contextFields, Map<Id, SObject> contextRecordMap) {
        String csv = 'Record Id';
        for (String label : contextFields.values()) {
            csv += ',' + csvEscape(label);
        }
        csv += ',Field API Name,Field Label,Old Value,New Value\n';
        for (Fund_Field_ApplicabilityHistory__c l : changedLogs) {
            Id refId = getRefId(l, objectApiName);
            csv += csvEscape(String.valueOf(refId));
            for (String fieldApiName : contextFields.keySet()) {
                String ctxVal = '';
                if (contextRecordMap.containsKey(refId)) {
                    Object fval = contextRecordMap.get(refId).get(fieldApiName);
                    ctxVal = fval != null ? String.valueOf(fval) : '';
                }
                csv += ',' + csvEscape(ctxVal);
            }
            csv += ',' + csvEscape(l.FieldAPIName__c)
                + ',' + csvEscape(l.Field_Name__c)
                + ',' + csvEscape(l.Old_Value__c)
                + ',' + csvEscape(l.New_Value__c) + '\n';
        }
        return csv;
    }

    private static String htmlEscape(String val) {
        if (val == null) return '';
        return val.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;');
    }

    private static String csvEscape(String val) {
        if (val == null) return '';
        val = val.replace('"', '""');
        if (val.contains(',') || val.contains('"') || val.contains('\n')) val = '"' + val + '"';
        return val;
    }

    private static List<String> splitLines(String val) {
        List<String> result = new List<String>();
        if (String.isBlank(val)) return result;
        for (String s : val.split('\n')) {
            if (String.isNotBlank(s)) result.add(s.trim());
        }
        return result;
    }

    private static Set<String> getSplitValues(String semiColonList) {
        Set<String> result = new Set<String>();
        if (String.isNotBlank(semiColonList)) {
            result.addAll(semiColonList.split(';'));
        }
        return result;
    }
}