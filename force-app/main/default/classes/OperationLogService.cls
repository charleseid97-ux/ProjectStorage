public without sharing class OperationLogService {
    public enum Level {
        DEBUG,
        INFO,
        WARN,
        ERROR
    }

    private static final Integer DEFAULT_EXPIRATION_DAYS = 100;
    private static final Integer MAX_BUFFER_SIZE = 200;
    private static final Integer TEXT_LONG_LIMIT = 32768;

    @TestVisible
    private static List<OperationLog__c> buffer = new List<OperationLog__c>();

    @TestVisible
    private static String correlationId;

    private static Boolean isFlushing = false;

    public class Entry {
        public Level level;
        public String sourceRecordId;
        public String sourceObjectApiName;
        public String operation;
        public String message;
        public String contextJson;
        public Date expirationDate;
        public String apexClass;
        public String methodName;
        public Exception exceptionValue;
    }

    // Définit un identifiant de corrélation pour regrouper les logs d'une même transaction.
    public static void setCorrelationId(String value) {
        correlationId = trimTo(value, 100);
    }

    // Retourne l'identifiant de corrélation courant ou en crée un pour la transaction.
    public static String getCorrelationId() {
        if (String.isBlank(correlationId)) {
            correlationId = trimTo(UserInfo.getUserId() + '-' + String.valueOf(Datetime.now().getTime()), 100);
        }

        return correlationId;
    }

    // Ajoute un log DEBUG dans le buffer courant.
    public static void debug(Id sourceRecordId, String operation, String message) {
        log(Level.DEBUG, sourceRecordId, operation, message);
    }

    // Ajoute un log INFO dans le buffer courant.
    public static void info(Id sourceRecordId, String operation, String message) {
        log(Level.INFO, sourceRecordId, operation, message);
    }

    // Ajoute un log WARN dans le buffer courant.
    public static void warn(Id sourceRecordId, String operation, String message) {
        log(Level.WARN, sourceRecordId, operation, message);
    }

    // Ajoute un log ERROR dans le buffer courant.
    public static void error(Id sourceRecordId, String operation, String message) {
        log(Level.ERROR, sourceRecordId, operation, message);
    }

    // Ajoute un log ERROR enrichi avec les informations d'une exception Apex.
    public static void error(Id sourceRecordId, String operation, String message, Exception ex) {
        Entry entry = new Entry();
        entry.level = Level.ERROR;
        entry.sourceRecordId = sourceRecordId == null ? null : String.valueOf(sourceRecordId);
        entry.sourceObjectApiName = resolveObjectApiName(sourceRecordId);
        entry.operation = operation;
        entry.message = message;
        entry.exceptionValue = ex;

        log(entry);
    }

    // Ajoute un log simple dans le buffer courant.
    public static void log(Level level, Id sourceRecordId, String operation, String message) {
        Entry entry = new Entry();
        entry.level = level;
        entry.sourceRecordId = sourceRecordId == null ? null : String.valueOf(sourceRecordId);
        entry.sourceObjectApiName = resolveObjectApiName(sourceRecordId);
        entry.operation = operation;
        entry.message = message;

        log(entry);
    }

    // Ajoute un log générique avec tous les champs utiles personnalisables.
    public static void log(String level, String sourceRecordId, String sourceObjectApiName, String operation, String message, String contextJson, Date expirationDate) {
        Entry entry = new Entry();
        entry.level = parseLevel(level);
        entry.sourceRecordId = sourceRecordId;
        entry.sourceObjectApiName = sourceObjectApiName;
        entry.operation = operation;
        entry.message = message;
        entry.contextJson = contextJson;
        entry.expirationDate = expirationDate;

        log(entry);
    }

    // Ajoute un log construit par le développeur dans le buffer courant.
    public static void log(Entry entry) {
        if (entry == null) {
            return;
        }

        buffer.add(buildRecord(entry));

        // Le flush automatique évite de garder un buffer trop grand dans les traitements bulk.
        if (buffer.size() >= MAX_BUFFER_SIZE) {
            flush();
        }
    }

    // Insère les logs du buffer avec un seul DML et sans bloquer le traitement métier.
    public static void flush() {
        if (buffer.isEmpty() || isFlushing) {
            return;
        }

        List<OperationLog__c> recordsToInsert = new List<OperationLog__c>();
        recordsToInsert.addAll(buffer);
        buffer.clear();

        isFlushing = true;
        try {
            safeInsert(recordsToInsert);
        } finally {
            isFlushing = false;
        }
    }

    // Envoie les logs du buffer vers une Queueable pour limiter l'impact dans la transaction courante.
    public static void flushAsync() {
        if (buffer.isEmpty()) {
            return;
        }

        List<OperationLog__c> recordsToInsert = new List<OperationLog__c>();
        recordsToInsert.addAll(buffer);
        buffer.clear();

        try {
            System.enqueueJob(new OperationLogInsertQueueable(recordsToInsert));
        } catch (Exception ex) {
            safeInsert(recordsToInsert);
        }
    }

    // Réinitialise l'état statique pour isoler les tests unitaires.
    @TestVisible
    private static void resetForTest() {
        buffer.clear();
        correlationId = null;
        isFlushing = false;
    }

    // Construit le record OperationLog__c à partir de l'entrée fournie.
    private static OperationLog__c buildRecord(Entry entry) {
        OperationLog__c record = new OperationLog__c();
        record.Level__c = String.valueOf(entry.level == null ? Level.INFO : entry.level);
        record.SourceRecordId__c = trimTo(entry.sourceRecordId, 80);
        record.SourceObject__c = trimTo(entry.sourceObjectApiName, 100);
        record.Operation__c = trimTo(entry.operation, 255);
        record.Message__c = trimTo(entry.message, TEXT_LONG_LIMIT);
        record.Context__c = trimTo(entry.contextJson, TEXT_LONG_LIMIT);
        record.CorrelationId__c = getCorrelationId();
        record.ExpirationDate__c = entry.expirationDate == null ? Date.today().addDays(DEFAULT_EXPIRATION_DAYS) : entry.expirationDate;
        record.ApexClass__c = trimTo(entry.apexClass, 255);
        record.MethodName__c = trimTo(entry.methodName, 255);

        if (entry.exceptionValue != null) {
            record.ExceptionType__c = trimTo(entry.exceptionValue.getTypeName(), 255);
            record.StackTrace__c = trimTo(entry.exceptionValue.getStackTraceString(), TEXT_LONG_LIMIT);

            if (String.isBlank(record.Message__c)) {
                record.Message__c = trimTo(entry.exceptionValue.getMessage(), TEXT_LONG_LIMIT);
            }
        }

        return record;
    }

    // Insère les logs en mode partiel afin qu'un log invalide ne bloque pas les autres.
    private static void safeInsert(List<OperationLog__c> recordsToInsert) {
        if (recordsToInsert == null || recordsToInsert.isEmpty()) {
            return;
        }

        try {
            Database.insert(recordsToInsert, false);
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'OperationLogService failed to insert logs: ' + ex.getMessage());
        }
    }

    // Déduit le nom API de l'objet à partir d'un Id Salesforce.
    private static String resolveObjectApiName(Id sourceRecordId) {
        if (sourceRecordId == null) {
            return null;
        }

        try {
            return sourceRecordId.getSObjectType().getDescribe().getName();
        } catch (Exception ex) {
            return null;
        }
    }

    // Convertit un texte en niveau de log supporté, avec INFO comme valeur par défaut.
    private static Level parseLevel(String value) {
        String normalized = String.isBlank(value) ? 'INFO' : value.trim().toUpperCase();

        if (normalized == 'DEBUG') {
            return Level.DEBUG;
        }
        if (normalized == 'WARN') {
            return Level.WARN;
        }
        if (normalized == 'ERROR') {
            return Level.ERROR;
        }

        return Level.INFO;
    }

    // Tronque les valeurs pour éviter les erreurs de longueur de champ au moment du DML.
    private static String trimTo(String value, Integer maxLength) {
        if (String.isBlank(value) || maxLength == null || maxLength <= 0) {
            return value;
        }

        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }
}
