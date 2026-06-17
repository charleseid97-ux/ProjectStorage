public without sharing class OperationLogRecordController {
    public class LogRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String level;
        @AuraEnabled public String sourceObject;
        @AuraEnabled public String sourceRecordId;
        @AuraEnabled public String operation;
        @AuraEnabled public String message;
        @AuraEnabled public String contextJson;
        @AuraEnabled public String correlationId;
        @AuraEnabled public Date expirationDate;
        @AuraEnabled public String apexClass;
        @AuraEnabled public String methodName;
        @AuraEnabled public String exceptionType;
        @AuraEnabled public String stackTrace;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdByName;
    }

    // Retourne les logs du record courant, triés du plus récent au plus ancien.
    @AuraEnabled(cacheable=true)
    public static List<LogRow> getLogs(String recordId, Integer maxRows, String minLevel) {
        if (!Schema.sObjectType.OperationLog__c.isAccessible()) {
            throw new AuraHandledException('Accès insuffisant aux logs.');
        }
        if (String.isBlank(recordId)) {
            return new List<LogRow>();
        }

        Integer safeLimit = normalizeLimit(maxRows);
        Set<String> levels = resolveLevels(minLevel);

        List<OperationLog__c> logs = [
            SELECT Id, Name, Level__c, SourceObject__c, SourceRecordId__c,
                   Operation__c, Message__c, Context__c, CorrelationId__c,
                   ExpirationDate__c, ApexClass__c, MethodName__c,
                   ExceptionType__c, StackTrace__c, CreatedDate, CreatedBy.Name
            FROM OperationLog__c
            WHERE SourceRecordId__c = :recordId
            AND Level__c IN :levels
            ORDER BY CreatedDate DESC, Id DESC
            LIMIT :safeLimit
        ];

        return toRows(logs);
    }

    // Transforme les SObjects en DTO simples pour le composant LWC.
    private static List<LogRow> toRows(List<OperationLog__c> logs) {
        List<LogRow> rows = new List<LogRow>();

        for (OperationLog__c logRecord : logs) {
            LogRow row = new LogRow();
            row.id = logRecord.Id;
            row.name = logRecord.Name;
            row.level = logRecord.Level__c;
            row.sourceObject = logRecord.SourceObject__c;
            row.sourceRecordId = logRecord.SourceRecordId__c;
            row.operation = logRecord.Operation__c;
            row.message = logRecord.Message__c;
            row.contextJson = logRecord.Context__c;
            row.correlationId = logRecord.CorrelationId__c;
            row.expirationDate = logRecord.ExpirationDate__c;
            row.apexClass = logRecord.ApexClass__c;
            row.methodName = logRecord.MethodName__c;
            row.exceptionType = logRecord.ExceptionType__c;
            row.stackTrace = logRecord.StackTrace__c;
            row.createdDate = logRecord.CreatedDate;
            row.createdByName = logRecord.CreatedBy == null ? null : logRecord.CreatedBy.Name;
            rows.add(row);
        }

        return rows;
    }

    // Normalise la limite afin de protéger le composant contre des volumes trop élevés.
    private static Integer normalizeLimit(Integer maxRows) {
        if (maxRows == null || maxRows < 1) {
            return 50;
        }
        if (maxRows > 200) {
            return 200;
        }

        return maxRows;
    }

    // Convertit le niveau minimum demandé en ensemble de niveaux acceptés.
    private static Set<String> resolveLevels(String minLevel) {
        List<String> orderedLevels = new List<String>{ 'DEBUG', 'INFO', 'WARN', 'ERROR' };
        String normalized = String.isBlank(minLevel) ? 'DEBUG' : minLevel.trim().toUpperCase();
        Boolean includeLevel = false;
        Set<String> resolvedLevels = new Set<String>();

        for (String level : orderedLevels) {
            if (level == normalized) {
                includeLevel = true;
            }
            if (includeLevel) {
                resolvedLevels.add(level);
            }
        }

        return resolvedLevels.isEmpty() ? new Set<String>(orderedLevels) : resolvedLevels;
    }
}
